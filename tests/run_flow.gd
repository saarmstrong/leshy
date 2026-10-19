extends SceneTree
const RUN = preload("res://scripts/run.gd")
const TEST_SAVE = "/tmp/emberwood-run-flow-test.json"
func _initialize() -> void:
	call_deferred("checks")
func checks() -> void:
	var run = RUN.new()
	run.save_path = TEST_SAVE
	root.add_child(run)
	assert(run.screen == "title")
	run._new_run()
	assert(run.screen == "map" and run.state.available == ["gift"])
	run._choose_node("last")
	assert(run.screen == "map") # Cannot skip ahead.
	run._choose_node("gift")
	assert(run.screen == "reward")
	run._take_reward("wolf")
	assert(run.state.deck.size() == 7 and run.state.completed == ["gift"])
	run._take_reward("wolf")
	assert(run.state.deck.size() == 7) # Double tap cannot duplicate reward.
	run._choose_node("fire")
	var uid: int = run.state.deck[0].uid
	run._pick_fire(uid)
	run._upgrade(uid, "attack_bonus")
	assert(run.state.deck[0].attack_bonus == 1 and run.state.deck[1].attack_bonus == 0)
	assert(run.screen == "map" and run.state.available == ["fight2"])
	run._choose_node("fight")
	assert(run.screen == "map") # Other branch is no longer available.
	# A saved run resumes the exact pending event, with permanent upgrades.
	var restored = RUN.new()
	restored.save_path = TEST_SAVE
	root.add_child(restored)
	restored._continue_run()
	assert(restored.screen == "map" and restored.state.deck[0].attack_bonus == 1)
	restored.queue_free()
	run._choose_node("fight2")
	assert(run.screen == "battle")
	assert(run.battle.enemies.count(null) == 4)
	assert(run.battle.reserve[2] != null and run.battle.reserve[1].animal == "BONE STOAT")
	assert(run.battle.reinforcements_left == 1)
	await run.battle._refill_reserve()
	assert(run.battle.reinforcements_left == 0)
	var queued: int = 4 - run.battle.reserve.count(null)
	await run.battle._refill_reserve()
	assert(4 - run.battle.reserve.count(null) == queued)
	var key: String = "fox#%d" % uid
	var upgraded = run.battle._make_card(key)
	var ordinary = run.battle._make_card("fox")
	assert(upgraded.power == 3 and ordinary.power == 2)
	upgraded.queue_free()
	ordinary.queue_free()
	assert(run.battle.run_deck.size() == 7)
	run.battle._finish_battle(true, "The last opposing creature has fallen.")
	assert(run.battle.balance == 0 and run.battle.battle_won)
	run.battle._end_round()
	assert(run.screen == "map" and run.state.battles_won == 1)
	assert(run.state.available == ["shrine", "fire2", "pack"])
	run._choose_node("shrine")
	var removed: int = run.state.deck[1].uid
	run._confirm_remove(removed)
	run._remove_card(removed)
	assert(run.state.deck.size() == 6 and run._find_entry(removed) == -1)
	run._remove_card(removed)
	assert(run.state.deck.size() == 6)
	run._choose_node("last")
	assert(run.screen == "battle")
	run.battle.balance = 5
	run.battle._check_outcome()
	run.battle._end_round()
	assert(run.screen == "ending" and run.state.status == "won")
	# The alternate route and defeat outcome also return a complete flow.
	run._new_run()
	run._choose_node("gift")
	run._take_reward("raven")
	run._choose_node("fight")
	run.battle.balance = -5
	run.battle._check_outcome()
	run.battle._end_round()
	assert(run.screen == "ending" and run.state.status == "lost")
	var defeated_state := JSON.stringify(run.state)
	run._choose_node("fight") # Stale node action must not reopen a defeated run.
	assert(run.screen == "ending" and JSON.stringify(run.state) == defeated_state)
	# Pending events persist; resume does not apply or repeat their reward.
	run._new_run()
	run._choose_node("gift")
	var pending = RUN.new()
	pending.save_path = TEST_SAVE
	root.add_child(pending)
	pending._continue_run()
	assert(pending.screen == "reward" and pending.state.deck.size() == 6)
	pending.queue_free()
	run.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_SAVE)
	print("PASS: title, map branches, event commitment, unique upgrades, battle handoff, win/loss, save/resume")
	quit()
