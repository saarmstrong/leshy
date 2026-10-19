extends SceneTree
const BATTLE = preload("res://scenes/attack_preview.tscn")
const RUN = preload("res://scripts/run.gd")
const SAVE = "/tmp/emberwood-items-flow.json"
func _initialize() -> void:
	call_deferred("checks")
func clear_zone(scene: Node, name: String) -> void:
	var zone: Array = scene.get(name)
	for i in range(zone.size()):
		if is_instance_valid(zone[i]):
			zone[i].queue_free()
		zone[i] = null
func give(scene: Node, id: String) -> Node2D:
	var card = scene._make_card(id)
	scene.hand.append(card)
	scene._select_card(scene.hand.size() - 1)
	return card
func idle(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while scene.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not scene.busy)
func checks() -> void:
	for reduced in [false, true]:
		var scene = BATTLE.instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = reduced
		# A reusable three-blood offering funds two consecutive high-cost plays.
		var offering = scene._make_card("ember_fox")
		offering.sigils.append("worthy_sacrifice")
		scene.board[4] = offering
		offering.position = scene._slot(4)
		for destination in [0, 7]:
			give(scene, "ossuary_hound")
			scene._toggle_offering(4, true)
			assert(scene._offered_blood() == 3 and scene._payment_ready(scene.selected))
			scene._place(4) # The reusable card still occupies its own slot.
			assert(not scene.busy and scene.board[4] == offering)
			scene._choose_lane(destination)
			await idle(scene)
			assert(scene.board[destination].animal == "OSSUARY HOUND" and scene.bones == 0)
			assert(scene.board[4] == offering and not offering.marked and offering.sigil_flashes.has("many_lives"))
		# Return-to-hand must preserve the live node, max health and added sigils.
		var returning = scene._make_card("revenant_raven")
		returning.permanent_attack_bonus = 2
		returning.permanent_health_bonus = 2
		returning.power += 2
		returning.health = 1
		returning.sigils.append("bone_king")
		scene.board[5] = returning
		returning.position = scene._slot(5)
		give(scene, "fox")
		scene._toggle_offering(5, true)
		scene._choose_lane(6)
		await idle(scene)
		assert(is_instance_valid(returning) and scene.hand.has(returning) and scene.board[5] == null)
		assert(returning.health == 3 and returning.power == 3 and scene.bones == 4)
		assert(returning.visible and returning.modulate.a == 1 and returning.sigils.has("bone_king"))
		assert(scene.discard.count("revenant_raven") == 1)
		scene._select_card(scene.hand.find(returning))
		scene._choose_lane(5)
		await idle(scene)
		assert(scene.bones == 2 and scene.board[5] == returning)
		give(scene, "fox")
		scene._toggle_offering(5, true)
		scene._choose_lane(5)
		await idle(scene)
		assert(scene.discard.count("revenant_raven") == 2 and scene.bones == 6)
		# Unused/cancelled/invalid items stay in the satchel; mandatory draw is enforced.
		scene.items = ["squirrel_bottle", "fish_hook", "scissors"]
		scene._clear_selection()
		scene._open_items()
		scene._inspect_item(1)
		scene._close_modal()
		assert(scene.items.size() == 3)
		scene.draw_required = true
		await scene._use_item(0)
		assert(scene.items.size() == 3)
		scene.draw_required = false
		var count: int = scene.hand.size()
		await scene._use_item(0)
		assert(scene.hand.size() == count + 1 and scene.hand.back().animal == "SQUIRREL")
		assert(not scene.draw_required and scene.items == ["fish_hook", "scissors"])
		await scene._use_item(0, 3, 3) # No active target.
		assert(scene.items.size() == 2)
		clear_zone(scene, "board")
		clear_zone(scene, "enemies")
		scene.enemies[2] = scene._make_card("bone_stoat")
		scene.enemies[2].health = 1
		scene.enemies[2].position = scene._slot(2, true)
		await scene._use_item(0, 2, 7)
		assert(scene.enemies[2] == null and scene.board[7].animal == "BONE STOAT")
		assert(scene.items == ["scissors"])
		# Hourglass skips the complete enemy phase, and Fan expires after one round.
		scene._reset()
		clear_zone(scene, "board")
		clear_zone(scene, "enemies")
		clear_zone(scene, "reserve")
		scene.reserve[2] = scene._make_card("wolf")
		scene.reserve[2].position = scene._reserve_slot(2)
		scene.items = ["hourglass", "fan"]
		await scene._use_item(0)
		await scene._use_item(0)
		await scene._end_round()
		assert(scene.enemies[2] == null and scene.reserve[2].animal == "WOLF")
		assert(not scene.skip_enemy and not scene.fan_active and scene.balance == 0 and scene.round_number == 2)
		scene.queue_free()
		await process_frame
		print("PASS: live survival animations/replays, blood UI, satchel targeting/cancel/draw, hook and timed effects; reduced=", reduced)
	# Map replacement is committed once; used inventory survives battle save/resume.
	var run = RUN.new()
	run.save_path = SAVE
	root.add_child(run)
	run._new_run()
	assert(run.state.items == ["squirrel_bottle", "pliers", "hourglass"])
	run._choose_node("gift")
	run._take_reward("ashen_stag")
	run._choose_node("fight")
	await run.battle._use_item(0)
	assert(run.state.items == ["pliers", "hourglass"])
	var saved = RUN.new()
	saved.save_path = SAVE
	root.add_child(saved)
	saved._continue_run()
	assert(saved.battle.items == ["pliers", "hourglass"])
	saved.queue_free()
	run.battle._finish_battle(true, "test")
	run.battle._end_round()
	run._choose_node("gift2")
	run._take_reward("ossuary_hound")
	run._choose_node("pack")
	assert(run.screen == "pack")
	run._take_item("fish_hook", 2)
	assert(run.state.items == ["pliers", "hourglass", "fish_hook"] and run.state.completed.has("pack"))
	run._take_item("fan", 0)
	assert(run.state.items[0] == "pliers")
	run.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	print("PASS: sigil rewards, reachable backpack, capacity, once-only choice and used-inventory save/resume")
	quit()
