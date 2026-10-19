extends SceneTree
## Randomized reachable map paths and interrupted save/resume, using real scenes.
const CONTRACTS = preload("res://tests/support/contracts.gd")
const RUN = preload("res://scripts/run.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
const ITEMS = preload("res://scripts/item_library.gd")
var spec = CONTRACTS.new()
var rng := RandomNumberGenerator.new()
var visited := {}
var saves := 0
var commands := 0
func _initialize() -> void:
	call_deferred("checks")
func checks() -> void:
	var count := 32
	var first_seed := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = maxi(1, int(arg.trim_prefix("--count=")))
		if arg.begins_with("--seed="):
			first_seed = int(arg.trim_prefix("--seed="))
	for seed_value in range(first_seed, first_seed + count):
		if not await run_seed(seed_value):
			quit(1)
			return
	if count >= 32:
		for kind in ["reward", "fire", "shrine", "pack", "battle"]:
			if not spec.require(visited.has(kind), "Random paths missed event family", {"family": kind}):
				quit(1)
				return
	spec.report("randomized-run-flow", {"first_seed": first_seed, "seeds": count, "commands": commands, "save_restores": saves, "event_visits": visited, "status": "passed"})
	print("PASS: ", count, " real-scene randomized runs, ", saves, " interrupted save/restores; ", spec.checks, " contracts")
	quit()
func run_seed(seed_value: int) -> bool:
	rng.seed = seed_value
	spec.context = {"suite": "randomized-run-flow", "seed": seed_value}
	spec.trace = []
	var path := "/tmp/emberwood-random-run-%d.json" % seed_value
	var run = RUN.new()
	run.save_path = path
	root.add_child(run)
	run._new_run()
	spec.initial = run.state.duplicate(true)
	for hop in range(12):
		commands += 1
		var before: String = spec.encode(run.state)
		run._choose_node("not-a-node")
		if not spec.require(spec.encode(run.state) == before, "Unreachable node changed run"):
			return false
		if run.state.status != "active":
			break
		var choices: Array = run.state.available
		var node: String = choices[rng.randi_range(0, choices.size() - 1)]
		var kind: String = run.NODES[node].kind
		visited[kind] = visited.get(kind, 0) + 1
		spec.trace.append({"kind": "choose_node", "node": node})
		run._choose_node(node)
		# Resume the exact pending event before making its decision.
		var pending: String = spec.encode(run.state)
		var restored = RUN.new()
		restored.save_path = path
		root.add_child(restored)
		restored._continue_run()
		saves += 1
		if not spec.require(spec.encode(restored.state) == pending and restored.screen == run.screen, "Pending event changed on resume", {"node": node}):
			return false
		run.queue_free()
		await process_frame
		run = restored
		match kind:
			"reward":
				var pool := ["fox", "bone_stoat", "wolf", "ashen_stag", "ember_fox", "revenant_raven"] if node == "gift" else ["grave_raven", "carrion_hound", "stag", "ossuary_hound", "ashen_stag", "revenant_raven"]
				var id: String = pool[rng.randi_range(0, pool.size() - 1)]
				var size: int = run.state.deck.size()
				spec.trace.append({"kind": "reward", "id": id})
				run._take_reward(id)
				run._take_reward(id)
				if not spec.require(run.state.deck.size() == size + 1, "Reward duplicated or missing"):
					return false
			"fire":
				var index := rng.randi_range(0, run.state.deck.size() - 1)
				var uid: int = run.state.deck[index].uid
				var field := "attack_bonus" if rng.randf() < 0.5 else "health_bonus"
				var original: Array = run.state.deck.duplicate(true)
				spec.trace.append({"kind": "upgrade", "uid": uid, "field": field})
				run._pick_fire(uid)
				run._upgrade(uid, field)
				run._upgrade(uid, field)
				for i in range(original.size()):
					var expected: Dictionary = original[i].duplicate(true)
					if expected.uid == uid:
						expected[field] += 1 if field == "attack_bonus" else 2
					if not spec.require(spec.encode(run.state.deck[i]) == spec.encode(expected), "Campfire changed wrong copy or repeated upgrade"):
						return false
			"shrine":
				var uid: int = run.state.deck[rng.randi_range(0, run.state.deck.size() - 1)].uid
				var size: int = run.state.deck.size()
				spec.trace.append({"kind": "remove", "uid": uid})
				run._confirm_remove(uid)
				run._remove_card(uid)
				run._remove_card(uid)
				if not spec.require(run.state.deck.size() == size - 1 and run._find_entry(uid) == -1, "Shrine removal duplicated or targeted wrong card"):
					return false
			"pack":
				var ids: Array = ITEMS.DEFINITIONS.keys()
				var item: String = ids[rng.randi_range(0, ids.size() - 1)]
				var inventory: Array = run.state.items.duplicate()
				var slot := rng.randi_range(0, 2) if inventory.size() == 3 else inventory.size()
				spec.trace.append({"kind": "take_item", "item": item, "slot": slot})
				if slot == inventory.size():
					inventory.append(item)
				else:
					inventory[slot] = item
				run._take_item(item, slot)
				run._take_item(item, slot)
				if not spec.require(run.state.items == inventory, "Backpack duplicated or changed wrong pocket"):
					return false
			"battle":
				# Combat itself is covered by randomized_battles; here test handoff/save boundaries.
				for index in range(run.battle.items.size()):
					if ITEMS.DEFINITIONS[run.battle.items[index]].target == "none":
						var inventory: Array = run.state.items.duplicate()
						inventory.remove_at(index)
						await run.battle._use_item(index)
						if not spec.require(run.state.items == inventory, "Item consumption not saved by run"):
							return false
						break
				var won: bool = rng.randf() > 0.15 or seed_value % 3 != 0
				spec.trace.append({"kind": "battle_result", "won": won})
				run.battle._finish_battle(won, "Seeded boundary test")
				run.battle._end_round()
		var completed: Array = run.state.completed
		if not spec.require(completed.count(node) == (0 if run.state.status == "lost" else 1), "Node completed more than once"):
			return false
		var uids := {}
		for entry in run.state.deck:
			if not spec.require(not uids.has(entry.uid) and CATALOG.contains(entry.id), "Duplicate run-card UID or invalid definition"):
				return false
			uids[entry.uid] = true
		var stable: String = spec.encode(run.state)
		run._save_run()
		var saved = RUN.new()
		saved.save_path = path
		root.add_child(saved)
		if not spec.require(spec.encode(saved.state) == stable, "Committed run changed on reload"):
			return false
		saved.queue_free()
		var repeated: String = spec.encode(run.state)
		var previous_screen: String = run.screen
		run._choose_node(node)
		if not spec.require(spec.encode(run.state) == repeated and run.screen == previous_screen, "Completed/terminal node could be chosen again"):
			return false
	if not spec.require(run.state.status in ["won", "lost"], "Map path did not end"):
		return false
	run.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	return true
