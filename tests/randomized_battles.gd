extends SceneTree
const CONTRACTS = preload("res://tests/support/contracts.gd")
const ACTIONS = preload("res://tests/support/sequence_actions.gd")
const SETUP = preload("res://scripts/battle_setup.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
const SIGILS = preload("res://scripts/sigil_library.gd")
const ITEMS = preload("res://scripts/item_library.gd")
var spec = CONTRACTS.new()
var rng := RandomNumberGenerator.new()
var state: Dictionary
var terminal := ""
var serial := 0
var total_actions := 0
var wins := 0
var losses := 0
var serialized_replays := 0
var seed_count := 512
var first_seed := 0
var coverage := {"sigils": {}, "items": {}, "plays": {}, "events": {}, "invalid_actions": 0, "max_rounds": 0}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			seed_count = maxi(1, int(arg.trim_prefix("--count=")))
		if arg.begins_with("--seed="):
			first_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--replay="):
			var ok := replay_file(arg.trim_prefix("--replay="))
			quit(0 if ok else 1)
			return
	for seed_value in range(first_seed, first_seed + seed_count):
		if not run_seed(seed_value):
			quit(1)
			return
	if seed_count >= 128:
		for sigil in SIGILS.DEFINITIONS:
			if not spec.require(coverage.sigils.has(sigil), "Random corpus never triggered a sigil", {"sigil": sigil}):
				quit(1)
				return
		if seed_count >= 512:
			for id in CATALOG.ids():
				if not spec.require(coverage.plays.has(id), "Random corpus never played a creature", {"id": id}):
					quit(1)
					return
		for item in ITEMS.DEFINITIONS:
			if not spec.require(coverage.items.has(item), "Random corpus never used an item", {"item": item}):
				quit(1)
				return
	spec.report("randomized-battles", {"first_seed": first_seed, "seeds": seed_count, "actions": total_actions, "wins": wins, "losses": losses, "serialized_replays": serialized_replays, "coverage": coverage, "status": "passed"})
	print("PASS: ", seed_count, " seeded mixed-deck/item battles; ", total_actions, " actions, exact full-trace replay; ", spec.checks, " contracts")
	quit()
func token() -> String:
	serial += 1
	return "c%d" % serial
func shuffled(values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result
func random_card(id: String, owner := "player") -> Dictionary:
	var card: Dictionary = spec.creature(id, owner, Array(CATALOG.find(id).sigils))
	card.attack += rng.randi_range(0, 2)
	card.max_health += rng.randi_range(0, 3)
	card.health = card.max_health
	var effects: Array = SIGILS.DEFINITIONS.keys() if owner == "player" else ["airborne", "mighty_leap", "waterborne", "stinky", "sharp_quills", "touch_of_death"]
	for i in range(rng.randi_range(0, 2)):
		var sigil: String = effects[rng.randi_range(0, effects.size() - 1)]
		if not card.sigils.has(sigil):
			card.sigils.append(sigil)
	return card
func commit(command: Dictionary) -> bool:
	spec.trace.append(command.duplicate(true))
	total_actions += 1
	var before: String = spec.encode(state)
	var result: Dictionary = ACTIONS.apply(state, command, spec)
	var custom: bool = command.kind in ["draw", "advance", "spawn"]
	if not spec.verify(state, command, result, before, not custom and total_actions % 13 == 0):
		return false
	if not result.error.is_empty():
		coverage.invalid_actions += 1
	for event in result.events:
		coverage.events[event.type] = coverage.events.get(event.type, 0) + 1
		if event.type == "sigil":
			coverage.sigils[event.sigil] = coverage.sigils.get(event.sigil, 0) + 1
		if event.type == "item_used":
			coverage.items[event.item] = coverage.items.get(event.item, 0) + 1
		if event.type == "played":
			var id: String = result.state.cards[event.actor].get("base_id", "generated")
			coverage.plays[id] = coverage.plays.get(id, 0) + 1
		if event.type == "outcome":
			terminal = "win" if event.won else "loss"
	state = result.state
	return true
func random_play() -> Dictionary:
	for actor in shuffled(state.hand):
		var card: Dictionary = state.cards[actor]
		var offerings: Array = []
		if card.cost_type == "bones":
			if state.bones < card.cost:
				continue
		else:
			var blood := 0
			for candidate in shuffled(state.player.filter(func(id): return id != "" and state.cards[id].sacrificable)):
				if blood >= card.cost:
					break
				offerings.append(candidate)
				blood += 3 if state.cards[candidate].sigils.has("worthy_sacrifice") else 1
			if blood < card.cost:
				continue
		for slot in shuffled(range(8)):
			var occupant: String = state.player[slot]
			if occupant == "" or (offerings.has(occupant) and not state.cards[occupant].sigils.has("many_lives")):
				return {"kind": "play", "actor": actor, "slot": slot, "offerings": offerings}
	return {}
func random_item() -> Dictionary:
	if state.items.is_empty():
		return {}
	var index := rng.randi_range(0, state.items.size() - 1)
	var item: String = state.items[index]
	var command := {"kind": "item", "index": index}
	if item in ["scissors", "fish_hook"]:
		var lanes: Array = range(4).filter(func(lane): return state.enemy[lane] != "")
		if lanes.is_empty():
			return {}
		command.target = lanes[rng.randi_range(0, lanes.size() - 1)]
		if item == "fish_hook":
			var slots: Array = range(8).filter(func(slot): return state.player[slot] == "")
			if slots.is_empty():
				return {}
			command.slot = slots[rng.randi_range(0, slots.size() - 1)]
	return command
func run_seed(seed_value: int) -> bool:
	rng.seed = seed_value
	serial = 0
	terminal = ""
	state = spec.empty()
	state.deck = []
	state.squirrels = 9
	var roster: Array = CATALOG.ids().filter(func(id): return id != "squirrel")
	for i in range(rng.randi_range(6, 12)):
		var id: String = "fox" if i == 0 else roster[rng.randi_range(0, roster.size() - 1)]
		var key := "%s#%s" % [id, token()]
		state.cards[key] = random_card(id)
		state.deck.append(key)
	state.deck = shuffled(state.deck)
	state.hand = SETUP.opening(state.deck)
	var squirrel := token()
	state.cards[squirrel] = spec.creature("squirrel")
	state.hand.append(squirrel)
	var item_ids: Array = ITEMS.DEFINITIONS.keys()
	for i in range(rng.randi_range(0, 3)):
		state.items.append(item_ids[rng.randi_range(0, item_ids.size() - 1)])
	var config: Dictionary = SETUP.encounter(seed_value % 3)
	for entry in config.active:
		var key := token()
		state.cards[key] = random_card(entry.id, "enemy")
		state.enemy[entry.lane] = key
	for entry in config.reserve + config.extra:
		var key := token()
		state.cards[key] = random_card(entry.id, "enemy")
		state.reserve[entry.lane] = key
	var budget: int = config.reinforcements
	spec.context = {"suite": "randomized-battles", "seed": seed_value}
	spec.initial = state.duplicate(true)
	spec.trace = []
	if not spec.state_valid(state):
		return false
	for round_index in range(1, 81):
		spec.context.round = round_index
		coverage.max_rounds = maxi(coverage.max_rounds, round_index)
		if round_index > 1:
			if state.deck.is_empty() and state.squirrels == 0:
				if not commit({"kind": "starve"}):
					return false
				if terminal != "":
					break
			else:
				var main: bool = state.squirrels == 0 or (not state.deck.is_empty() and rng.randf() < 0.5)
				var draw := {"kind": "draw", "source": "main" if main else "squirrel", "token": token(), "card": spec.creature("squirrel")}
				var total: int = state.deck.size() + state.squirrels
				if not commit(draw) or not spec.require(state.deck.size() + state.squirrels == total - 1, "Mandatory draw did not consume exactly one pile card"):
					return false
		# Mix bounded legal plays, tools and deliberately invalid attempts.
		for step in range(rng.randi_range(2, 8)):
			var command := random_item() if rng.randf() < 0.4 else random_play()
			if step == 0 and rng.randf() < 0.2 and not state.hand.is_empty():
				command = {"kind": "play", "actor": state.hand[0], "slot": -1, "offerings": []}
			if command.is_empty():
				continue
			if not commit(command):
				return false
			if terminal != "":
				break
		if terminal != "":
			break
		for lane in range(8):
			if state.player[lane] != "" and not commit({"kind": "attack", "actor": state.player[lane], "lane": lane, "enemy": false}):
				return false
			if terminal != "":
				break
		if terminal != "":
			break
		if not state.skip_enemy:
			if not commit({"kind": "advance"}):
				return false
			for lane in range(4):
				if state.enemy[lane] != "" and not commit({"kind": "attack", "actor": state.enemy[lane], "lane": lane, "enemy": true}):
					return false
				if terminal != "":
					break
			if terminal != "":
				break
			if budget > 0:
				for lane in shuffled(range(4)):
					if state.reserve[lane] == "":
						var enemy_ids := ["wolf", "raven", "fox", "stag", "bone_stoat", "grave_raven"]
						var id: String = enemy_ids[rng.randi_range(0, enemy_ids.size() - 1)]
						if not commit({"kind": "spawn", "lane": lane, "token": token(), "card": random_card(id, "enemy")}):
							return false
						budget -= 1
						break
		if not commit({"kind": "cleanup"}):
			return false
	if not spec.require(terminal != "", "Battle exceeded 80 rounds", {"state": state}):
		return false
	wins += int(terminal == "win")
	losses += int(terminal == "loss")
	var replay: Dictionary = spec.initial.duplicate(true)
	for command in spec.trace:
		replay = ACTIONS.apply(replay, command, spec).state
	if not spec.require(spec.encode(replay) == spec.encode(state), "Full action-trace replay diverged"):
		return false
	if seed_value % 31 == 0 or seed_value == first_seed:
		var artifact := {"context": spec.context.duplicate(), "initial": spec.initial, "actions": spec.trace, "final_state": state}
		var saved: Dictionary = JSON.parse_string(JSON.stringify(artifact))
		var restored: Dictionary = saved.initial
		for command in saved.actions:
			restored = ACTIONS.apply(restored, command, spec).state
		serialized_replays += 1
		if not spec.require(spec.encode(restored) == spec.encode(state), "Serialized trace lost information or changed its result"):
			return false
		if seed_value == first_seed:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
			var file := FileAccess.open("res://reports/replay-sample.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(artifact, "\t", true, true) + "\n")
	return true
func replay_file(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("initial") or not data.has("actions") or data.get("context", {}).get("suite", "") != "randomized-battles":
		printerr("Replay needs a failure artifact containing initial state and actions.")
		return false
	spec.context = data.get("context", {"suite": "replay"})
	spec.initial = data.initial
	spec.trace = []
	state = data.initial
	for command in data.actions:
		if not commit(command):
			return false
	if data.has("final_state") and not spec.require(spec.encode(state) == spec.encode(data.final_state), "Saved replay final state differs"):
		return false
	print("REPLAY complete: ", data.actions.size(), " actions; terminal=", terminal)
	return true
