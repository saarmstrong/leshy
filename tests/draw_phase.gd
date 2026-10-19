extends SceneTree
func _initialize() -> void:
	call_deferred("checks")
func idle(scene: Node) -> void:
	while scene.busy:
		await process_frame
func checks() -> void:
	for side in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.draw_required = true
		scene._refresh()
		var deck_count: int = scene.deck.size()
		var squirrel_count: int = scene.squirrels
		var hand_count: int = scene.hand.size()
		assert(not scene.main_draw.disabled and not scene.squirrel_draw.disabled)
		assert(scene.action.disabled and scene.action.text == "DRAW FIRST")
		scene._select_card(0)
		assert(scene.selected == null)
		scene._end_round()
		assert(scene.round_number == 1 and not scene.busy)
		scene._draw_from_deck(side)
		assert(scene.busy)
		scene._draw_from_deck(not side) # Rapid tap on the other pile is ignored.
		await idle(scene)
		assert(scene.hand.size() == hand_count + 1)
		assert(scene.deck.size() == deck_count - (0 if side else 1))
		assert(scene.squirrels == squirrel_count - (1 if side else 0))
		assert(scene.main_draw.disabled and scene.squirrel_draw.disabled)
		assert(not scene.action.disabled and not scene.draw_required)
		scene._draw_from_deck(side)
		assert(scene.hand.size() == hand_count + 1)
		# An empty pile cannot waive the mandatory draw from the other pile.
		scene.draw_required = true
		if side:
			scene.deck.clear()
		else:
			scene.squirrels = 0
		scene._refresh()
		assert(scene.action.disabled)
		await scene._draw_from_deck(not side)
		assert(scene.draw_required)
		await scene._draw_from_deck(side)
		assert(not scene.draw_required and scene.hand.size() == hand_count + 2)
		scene.queue_free()
		await process_frame
	print("PASS: mandatory choice, both piles, exact one draw, rapid double tap, exhausted-pile fallback")
	quit()
