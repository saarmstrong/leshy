extends SceneTree
func _initialize() -> void:
	call_deferred("checks")
func clear_cards(scene: Node, zone: String) -> void:
	var cards: Array = scene.get(zone)
	for i in range(cards.size()):
		if cards[i] != null:
			cards[i].queue_free()
		cards[i] = null
func checks() -> void:
	for low_motion in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = low_motion
		assert(not scene._check_outcome()) # Empty opening board is legal.
		# A combat wipeout loses despite unplayed cards and a neutral scale.
		scene.board[4] = scene._make_card("squirrel")
		scene.board[4].position = scene._slot(4)
		var foe = scene._make_card("wolf")
		scene.enemies[0] = foe
		foe.position = scene._slot(0, true)
		await scene._strike(foe, 0, true)
		assert(scene.finished and not scene.battle_won and scene.balance == 0)
		assert(scene.hand.size() == 4 and is_instance_valid(scene.modal))
		assert(scene.bones == 1)
		scene._end_round()
		assert(not scene.finished and scene.bones == 0)
		# Killing the last active enemy is not a wipeout while reserve survives.
		clear_cards(scene, "enemies")
		scene.board[0] = scene._make_card("fox")
		scene.board[0].position = scene._slot(0)
		scene.enemies[0] = scene._make_card("squirrel")
		scene.enemies[0].position = scene._slot(0, true)
		await scene._strike(scene.board[0], 0)
		assert(not scene.finished)
		clear_cards(scene, "reserve")
		scene.enemies[0] = scene._make_card("squirrel")
		scene.enemies[0].position = scene._slot(0, true)
		await scene._strike(scene.board[0], 0)
		assert(scene.finished and scene.battle_won and scene.balance == 0)
		var old_reason: String = scene.result_reason
		scene._finish_battle(false, "cannot override settled victory")
		assert(scene.battle_won and scene.result_reason == old_reason)
		scene._end_round()
		# Sacrificing the only creature to replace it must not lose mid-play.
		scene.board[0] = scene._make_card("squirrel")
		scene.board[0].position = scene._slot(0)
		scene.hand.append(scene._make_card("fox"))
		scene._select_card(scene.hand.size() - 1)
		scene._toggle_offering(0, true)
		await scene._place(0)
		assert(not scene.finished and scene.board[0].animal == "FOX")
		# Each phase uses all sayings before reshuffling; no boundary repeat.
		for kind in ["enemy", "player"]:
			var seen := {}
			for i in range(12):
				seen[scene._next_whisper(kind)] = true
			assert(seen.size() == 12)
			var last: String = scene.last_whisper
			assert(scene._next_whisper(kind) != last)
		await scene._transition("enemy")
		assert(is_zero_approx(scene.veil.color.a))
		assert(is_zero_approx(scene.whisper.modulate.a))
		assert(is_zero_approx(scene.whisper_effect.strength))
		scene.queue_free()
		await process_frame
		print("PASS: combat wipeouts, reserves, explicit result, sacrifice safety, varied animated whispers; reduced = ", low_motion)
	quit()
