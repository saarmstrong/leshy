extends SceneTree
## Run: godot --headless --path . --script res://tests/ritual_flow.gd
func _initialize() -> void:
	call_deferred("run_checks")
func wait_idle(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 25000
	while scene.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not scene.busy, "Animation queue did not unlock")
func run_checks() -> void:
	for low_motion in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = low_motion
		assert(scene.hand.size() == 4 and scene.hand[3].animal == "SQUIRREL")
		assert(scene.deck.size() == 9 and scene.squirrels == 9)
		assert(scene.board.count(null) == 8 and not scene.hand_open)
		var fox_index := -1
		for i in range(3):
			if scene.hand[i].animal == "FOX":
				fox_index = i
		assert(fox_index >= 0)
		var first = scene.hand[0]
		scene.hand[0] = scene.hand[fox_index]
		scene.hand[fox_index] = first
		assert(not scene.draw_required)
		await scene._draw_from_deck(true)
		assert(scene.hand.size() == 4) # No extra first-turn draw.
		scene._open_deck()
		assert(is_instance_valid(scene.modal))
		scene._open_library_card("squirrel")
		scene._close_modal()
		scene._hand_control()
		assert(scene.hand_open)
		scene._select_card(3)
		assert(not scene.hand_open)
		scene._choose_lane(0)
		await wait_idle(scene)
		assert(scene.board[0].animal == "SQUIRREL")
		# Paying in blood consumes a placed squirrel, never a card in hand.
		scene._select_card(0)
		scene._choose_lane(3)
		assert(not scene.busy and scene.board[3] == null)
		# Holding a placed creature opens inline actions without committing it.
		scene.press_lane = 0
		scene.press_origin = scene._slot(0)
		scene.press_age = 0
		scene.press_canceled = false
		scene.hold_consumed = false
		scene._process(0.46)
		assert(scene.hold_consumed and is_instance_valid(scene.modal))
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = scene._slot(0)
		scene._input(release)
		assert(scene.offerings.is_empty() and scene.board[0] != null)
		scene._toggle_offering(0, true)
		assert(scene.offerings.size() == 1 and scene.modal == null)
		scene._toggle_offering(0, true)
		assert(scene.offerings.is_empty())
		# A drag cancels a hold rather than marking a creature.
		scene.press_lane = 0
		scene.press_canceled = false
		scene.hold_consumed = false
		var movement := InputEventMouseMotion.new()
		movement.position = scene._slot(0) + Vector2(30, 0)
		scene._input(movement)
		scene._process(0.5)
		assert(scene.press_canceled and scene.modal == null)
		scene._input(release)
		assert(scene.offerings.is_empty())
		scene._open_inspector()
		scene._toggle_offering(0)
		assert(scene.offerings.size() == 1)
		scene._toggle_offering(0)
		assert(scene.offerings.is_empty())
		scene._close_modal()
		scene._choose_lane(0)
		scene._choose_lane(0)
		assert(scene.busy)
		scene._end_round()
		await wait_idle(scene)
		assert(scene.board[0].animal == "FOX" and scene.discard == ["squirrel"])
		var held = scene.reserve[1]
		scene._end_round()
		await wait_idle(scene)
		assert(scene.round_number == 2 and scene.draw_required)
		assert(scene.action.disabled and scene.hand.size() == 2)
		assert(scene.reserve[1] == held and scene.enemies[2].animal == "RAVEN")
		var hand_size: int = scene.hand.size()
		scene._select_card(0)
		assert(scene.selected == null) # Draw must precede playing.
		scene._end_round()
		assert(scene.round_number == 2 and not scene.busy)
		await scene._draw_from_deck(true)
		assert(scene.hand.size() == hand_size + 1 and scene.squirrels == 8)
		assert(not scene.draw_required and not scene.action.disabled)
		await scene._draw_from_deck(false)
		assert(scene.deck.size() == 9) # No second draw from other pile.
		# An exhausted pile cannot consume the turn's draw choice.
		scene.draw_required = true
		scene.squirrels = 0
		await scene._draw_from_deck(true)
		assert(scene.draw_required)
		await scene._draw_from_deck(false)
		assert(scene.deck.size() == 8 and not scene.draw_required)
		# More than four cards are retained and reachable through fan pages.
		for i in range(9):
			scene.hand.append(scene._make_card("squirrel"))
		scene.hand_open = true
		scene._layout_hand(false)
		scene._page_hand(1)
		assert(scene.hand_page == 1 and scene.hand[5].visible)
		scene._page_hand(1)
		assert(scene.hand_page == 2)
		scene._select_card(10)
		scene._choose_lane(3)
		await wait_idle(scene)
		assert(scene.board[3].visible and scene.board[3].animal == "SQUIRREL")
		# Scale uses a five-point lead and restart resets both piles and hand.
		scene.balance = 5
		assert(scene._check_outcome())
		scene._end_round()
		assert(scene.squirrels == 9 and scene.deck.size() == 9)
		assert(not scene.hand_open and not scene.finished and not scene.draw_required)
		# Both player rows accept free squirrels and paid creatures.
		scene.hand.append(scene._make_card("squirrel"))
		scene._select_card(scene.hand.size() - 1)
		scene._choose_lane(4)
		await wait_idle(scene)
		assert(scene.board[4].animal == "SQUIRREL")
		scene._open_inline_offering(4)
		assert(is_instance_valid(scene.modal))
		scene._close_modal()
		scene.hand.append(scene._make_card("fox"))
		scene._select_card(scene.hand.size() - 1)
		scene._choose_lane(4)
		scene._choose_lane(7)
		await wait_idle(scene)
		assert(scene.board[4] == null and scene.board[7].animal == "FOX")
		assert(scene.board[7].position == scene._slot(7))
		await scene._strike(scene.board[7], 7)
		assert(scene.balance == 2) # Back row attacks its corresponding enemy lane.
		var enemy = scene._make_card("wolf")
		scene.enemies[3] = enemy
		enemy.position = scene._slot(3, true)
		await scene._strike(enemy, 3, true)
		assert(scene.board[7].health == 1) # Empty front exposes the back.
		scene.board[3] = scene._make_card("squirrel")
		scene.board[3].position = scene._slot(3)
		await scene._strike(enemy, 3, true)
		assert(scene.board[3] == null and scene.board[7].health == 1)
		# Shuffled opening deals have three species, a one-blood play, and a squirrel.
		var seen := {}
		for attempt in range(40):
			scene._reset()
			var species := {}
			var playable := false
			var signature := ""
			for i in range(3):
				var card = scene.hand[i]
				species[card.animal] = true
				playable = playable or card.cost == 1
				signature += card.animal
			assert(species.size() == 3 and playable)
			assert(scene.hand[3].animal == "SQUIRREL" and scene.deck.size() == 9)
			seen[signature] = true
		assert(seen.size() > 1)
		scene.queue_free()
		await process_frame
		print("PASS: squirrel pile, opening hand, one chosen draw, blood, reserve, unlimited paged fan, reset; reduced = ", low_motion)
	quit()
