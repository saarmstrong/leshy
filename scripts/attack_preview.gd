extends Node2D
signal battle_finished(won: bool)
signal inventory_changed(inventory: Array)
const ITEMS = preload("res://scripts/item_library.gd")
var items: Array = ITEMS.STARTER.duplicate()
var initial_items: Array = ITEMS.STARTER.duplicate()
var skip_enemy := false
var fan_active := false
const RULES = preload("res://scripts/battle_rules.gd")
const SIGILS = preload("res://scripts/sigil_library.gd")
var model_nodes: Dictionary = {}
var event_log: Array = []
var event_sequence := 0
var ambience: Node2D
var preferred_reduced := false
var run_entries: Dictionary = {}
var run_deck: Array = []
var encounter_level := 0
var reinforcements_left := 0

func configure_run(entries: Array, level := 0, inventory: Array = ITEMS.STARTER) -> void:
	encounter_level = level
	initial_items = inventory.duplicate()
	for entry in entries:
		var key := "%s#%s" % [entry.id, str(entry.uid)]
		run_entries[key] = entry.duplicate(true)
		run_deck.append(key)

func _base_id(key: String) -> String:
	return str(run_entries[key].id) if run_entries.has(key) else key

## A small ritual sandbox: costs, placement, lane combat, and round transitions.
const PAPER = Color("d9cfb2")
const AMBER = Color("c68a43")
const FONT = preload("res://assets/fonts/NotoSerif-Regular.ttf")
const CARD = preload("res://scripts/ritual_card.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
var board: Array = [null, null, null, null, null, null, null, null]
var enemies: Array = [null, null, null, null]
var reserve: Array = [null, null, null, null]
var reserve_index := 0
var hand: Array = []
var offerings: Array = []
var selected: Node2D
var busy := false
var finished := false
var battle_won := false
var result_reason := ""
var whisper_effect: Node2D
var whisper_hint: Label
var phrase_bags: Dictionary = {}
var last_whisper := ""
const WHISPERS = {
	"enemy": ["It has learned your scent.", "Something stirs beneath the table.", "The branches lean a little closer.", "It knows which hand is trembling.", "The dark has counted your creatures.", "A second shadow joins the first.", "The roots have found your footprints.", "Do not look behind your chair.", "Its hunger has a patient voice.", "The forest holds its breath.", "You hear claws beneath the floor.", "It remembers what you offered."],
	"player": ["The candles remember you.", "The wax falls like a quiet warning.", "Something has left a place for you.", "Your shadow returns before you do.", "The embers have not forgiven you.", "The next breath is still yours.", "The wood waits for another name.", "The candle bends away from you.", "The dead are listening now.", "A small warmth survives the dark.", "The ink is not quite dry.", "Your cards feel colder than before."],
}

var round_number := 1
var balance := 0
var bones := 0
var starvation := 0
const STARTING_DECK = ["fox", "stag", "wolf", "raven", "fox", "wolf", "stag", "raven", "fox", "bone_stoat", "grave_raven", "carrion_hound", "ashen_stag", "ember_fox", "revenant_raven", "ossuary_hound"]
var squirrels := 10
var draw_required := false
var hand_open := false
var hand_page := 0
var main_draw: Button
var squirrel_draw: Button
var creature_stack: Node2D
var squirrel_stack: Node2D
var previous_hand: Button
var next_hand: Button
var deck: Array = []
var discard: Array = []
var deck_button: Button
var inspect_button: Button
var modal: Control
const HOLD_SECONDS := 0.45
const HOLD_SLOP := 12.0
var press_lane := -1
var press_origin := Vector2.ZERO
var press_age := 0.0
var press_canceled := false
var hold_consumed := false
var draw_index := 0
var ash: Array = []
var elapsed := 0.0
var pulse := 0.0
var status: Label
var counter: Label
var action: Button
var cancel: Button
var reduced: CheckButton
var veil: ColorRect
var whisper: Label
var backdrop = preload("res://assets/art/emberwood-table.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ambience = preload("res://scripts/haunted_table.gd").new()
	add_child(ambience)
	_label("T H E   H O L L O W", Vector2(0, 125), 19)
	counter = _label("", Vector2(0, 155), 10, AMBER)
	status = _label("", Vector2(12, 75), 12)
	status.size = Vector2(366, 33)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button("END ROUND", Vector2(252, 790), Vector2(124, 46), _end_round)
	cancel = _button("HAND", Vector2(132, 790), Vector2(108, 46), _hand_control)
	reduced = CheckButton.new()
	reduced.text = "Reduced motion"
	reduced.button_pressed = preferred_reduced
	reduced.position = Vector2(14, 8)
	reduced.size = Vector2(150, 44)
	reduced.add_theme_font_size_override("font_size", 10)
	add_child(reduced)
	veil = ColorRect.new()
	veil.size = Vector2(390, 844)
	veil.color = Color(0.025, 0.018, 0.012, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 50
	add_child(veil)
	whisper = _label("", Vector2(20, 380), 22, PAPER)
	whisper.size = Vector2(350, 84)
	whisper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	whisper.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	whisper.position.y = 371
	whisper.pivot_offset = Vector2(175, 42)
	whisper.add_theme_color_override("font_shadow_color", Color(0.67, 0.32, 0.08, 0.65))
	whisper.add_theme_constant_override("shadow_offset_y", 2)
	whisper.modulate.a = 0
	whisper.z_index = 53
	whisper_effect = preload("res://scripts/whisper_effect.gd").new()
	whisper_effect.z_index = 52
	add_child(whisper_effect)
	whisper_hint = _label("", Vector2(0, 326), 10, AMBER)
	whisper_hint.z_index = 53
	whisper_hint.modulate.a = 0
	for row in [["WAITING IN THE DARK", 168], ["OPPONENT", 305], ["YOUR FRONT ROW", 440], ["YOUR BACK ROW", 575]]:
		_label(row[0], Vector2(0, row[1]), 8, AMBER)
	deck_button = _button("DECK", Vector2(14, 790), Vector2(108, 46), _open_deck)
	main_draw = _button("MAIN", Vector2(132, 737), Vector2(108, 46), _draw_from_deck.bind(false))
	squirrel_draw = _button("SQUIRREL", Vector2(252, 737), Vector2(124, 46), _draw_from_deck.bind(true))
	creature_stack = _attach_draw_stack(main_draw, false)
	squirrel_stack = _attach_draw_stack(squirrel_draw, true)
	previous_hand = _button("‹", Vector2(14, 663), Vector2(44, 44), _page_hand.bind(-1))
	next_hand = _button("›", Vector2(332, 663), Vector2(44, 44), _page_hand.bind(1))
	inspect_button = _button("OFFERINGS", Vector2(14, 737), Vector2(108, 46), _inspect_or_items)
	_reset()

func _label(text: String, at: Vector2, size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = 390
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", PAPER)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("33281d") if state == "hover" else Color("191914")
		box.border_color = AMBER.darkened(0.6) if state == "disabled" else AMBER
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _make_card(id: String) -> Node2D:
	var card = CARD.new()
	var base := _base_id(id)
	card.configure(CATALOG.find(base), run_entries.get(id, {}))
	card.reduced_motion = reduced.button_pressed if is_instance_valid(reduced) else preferred_reduced
	card.set_meta("card_id", id)
	add_child(card)
	return card

func _slot(lane: int, enemy := false) -> Vector2:
	return Vector2(55.5 + (lane % 4) * 93, 376 if enemy else (646 if lane >= 4 else 511))

func _reserve_slot(lane: int) -> Vector2:
	return Vector2(55.5 + lane * 93, 241)

func _queue_enemy(lane: int) -> void:
	var sequence := preload("res://scripts/battle_setup.gd").ENEMY_SEQUENCE
	var card = _make_card(sequence[reserve_index % sequence.size()])
	reserve_index += 1
	reserve[lane] = card
	card.position = _reserve_slot(lane)
	_record_event({"type": "spawn", "actor": str(card.get_instance_id()), "zone": "reserve", "slot": lane})

func _advance_reserve() -> void:
	# A blocked lane holds its exact queued card. Only the active row fights.
	for lane in range(4):
		if reserve[lane] != null and enemies[lane] == null:
			var card = reserve[lane]
			reserve[lane] = null
			enemies[lane] = card
			status.text = "%s steps out of the dark." % card.animal.capitalize()
			_record_event({"type": "move", "actor": str(card.get_instance_id()), "zone": "enemy", "slot": lane})
			await _settle(card, _slot(lane, true))

func _refill_reserve() -> void:
	if not run_deck.is_empty() and reinforcements_left <= 0:
		return
	# Refill after enemy combat so new intentions are visible for a player turn.
	var lane: int = (round_number + 1) % 4
	for offset in range(4):
		var candidate: int = (lane + offset) % 4
		if reserve[candidate] == null:
			_queue_enemy(candidate)
			if not run_deck.is_empty():
				reinforcements_left -= 1
			var card = reserve[candidate]
			card.modulate.a = 0
			await create_tween().tween_property(card, "modulate:a", 1.0, 0.35).finished
			return

func _reset() -> void:
	for card in board + enemies + reserve + hand:
		if is_instance_valid(card):
			card.queue_free()
	board = [null, null, null, null, null, null, null, null]
	enemies = [null, null, null, null]
	reserve = [null, null, null, null]
	reserve_index = 0
	event_log.clear()
	event_sequence = 0
	hand = []
	offerings.clear()
	selected = null
	balance = 0
	bones = 0
	starvation = 0
	items = initial_items.duplicate()
	skip_enemy = false
	fan_active = false
	round_number = 1
	ambience.set_round(round_number)
	draw_index = 0
	deck = run_deck.duplicate() if not run_deck.is_empty() else STARTING_DECK.duplicate()
	deck.shuffle()
	discard.clear()
	_close_modal()
	finished = false
	battle_won = false
	result_reason = ""
	veil.color.a = 0
	whisper.modulate.a = 0
	whisper_hint.modulate.a = 0
	whisper_effect.strength = 0
	squirrels = 9
	draw_required = false
	hand_open = false
	hand_page = 0
	if run_deck.is_empty():
		enemies[1] = _make_card("wolf")
		enemies[1].position = _slot(1, true)
		_queue_enemy(2)
		_queue_enemy(1)
	else:
		var setup: Dictionary = preload("res://scripts/battle_setup.gd").encounter(encounter_level)
		reinforcements_left = setup.reinforcements
		for entry in setup.active:
			enemies[entry.lane] = _make_card(entry.id)
			enemies[entry.lane].position = _slot(entry.lane, true)
		for entry in setup.reserve + setup.extra:
			reserve[entry.lane] = _make_card(entry.id)
			reserve[entry.lane].position = _reserve_slot(entry.lane)
			_record_event({"type": "spawn", "actor": str(reserve[entry.lane].get_instance_id()), "zone": "reserve", "slot": entry.lane})
		reserve_index = setup.sequence_index
	for id in _opening_deal():
		hand.append(_make_card(id))
	hand.append(_make_card("squirrel"))
	_layout_hand(false)
	status.text = "Open your hand. Play a squirrel to pay in blood."
	_refresh()

func _hand_control() -> void:
	if busy:
		return
	if selected:
		_clear_selection()
	else:
		hand_open = not hand_open
	_layout_hand()
	_refresh()

func _page_hand(direction: int) -> void:
	if busy:
		return
	hand_page = clampi(hand_page + direction, 0, maxi(0, int((hand.size() - 1) / 5.0)))
	_layout_hand()
	_refresh()

func _layout_hand(animated := true) -> void:
	hand_page = clampi(hand_page, 0, maxi(0, int((hand.size() - 1) / 5.0)))
	for i in range(hand.size()):
		var card = hand[i]
		if card.has_meta("layout_tween"):
			var previous: Tween = card.get_meta("layout_tween")
			if previous.is_valid():
				previous.kill()
		var local_index: int = i - hand_page * 5 if hand_open else i
		var count: int = mini(5, hand.size() - hand_page * 5) if hand_open else mini(5, hand.size())
		card.visible = local_index >= 0 and local_index < count
		if not card.visible:
			continue
		var offset: float = local_index - (count - 1) / 2.0
		var destination := Vector2(195 + offset * (64 if hand_open else 23), (642 if hand_open else 719) + absf(offset) * 4)
		var angle := offset * (0.075 if hand_open else 0.11)
		var card_scale := Vector2(0.93, 0.93) if hand_open else Vector2(0.22, 0.22)
		card.z_index = 8 + local_index
		card.selected = card == selected
		card.queue_redraw()
		if animated and not reduced.button_pressed:
			var tween := create_tween().set_parallel(true)
			card.set_meta("layout_tween", tween)
			tween.tween_property(card, "position", destination, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", card_scale, 0.22)
			tween.tween_property(card, "rotation", angle, 0.22)
		else:
			card.position = destination
			card.scale = card_scale
			card.rotation = angle

func _refresh() -> void:
	counter.text = "ROUND %d   ·   BAL %+d/5   ·   BONES %d" % [round_number, balance, bones]
	if selected and selected.cost_type == "blood" and selected.cost > 0:
		counter.text += "   ·   BLOOD %d/%d" % [_offered_blood(), selected.cost]
	deck_button.text = "DECK LIST"
	main_draw.text = "CREATURES\n%d left" % deck.size()
	squirrel_draw.text = "SQUIRRELS\n%d left" % squirrels
	main_draw.disabled = busy or finished or not draw_required or deck.is_empty()
	squirrel_draw.disabled = busy or finished or not draw_required or squirrels <= 0
	creature_stack.remaining = deck.size()
	creature_stack.available = not main_draw.disabled
	creature_stack.queue_redraw()
	squirrel_stack.remaining = squirrels
	squirrel_stack.available = not squirrel_draw.disabled
	squirrel_stack.queue_redraw()
	previous_hand.visible = hand_open and hand_page > 0
	next_hand.visible = hand_open and (hand_page + 1) * 5 < hand.size()
	deck_button.disabled = busy
	inspect_button.text = "CARD INFO" if selected else "SATCHEL · %d" % items.size()
	inspect_button.disabled = busy or finished
	action.disabled = busy or (draw_required and not finished)
	cancel.disabled = busy
	cancel.text = "CANCEL PLAY" if selected else ("HIDE HAND" if hand_open else "HAND · %d" % hand.size())
	reduced.disabled = busy
	action.text = ("RETURN TO MAP" if not run_deck.is_empty() else "NEW RITUAL") if finished else ("DRAW FIRST" if draw_required else "END ROUND")
	queue_redraw()

func _clear_selection() -> void:
	if busy:
		return
	for card in offerings:
		card.marked = false
		card.queue_redraw()
	offerings.clear()
	selected = null
	_layout_hand()
	status.text = "The wood waits. Choose a creature."
	_refresh()

func _select_card(index: int) -> void:
	if busy or finished or draw_required or index < 0 or index >= hand.size():
		return
	_clear_selection()
	selected = hand[index]
	hand_open = false
	_layout_hand()
	if selected.cost_type == "bones":
		status.text = "%s costs %d bones. You have %d." % [selected.animal.capitalize(), selected.cost, bones]
	elif selected.cost == 0:
		status.text = "%s is free. Tap an empty lane." % selected.animal.capitalize()
	else:
		status.text = "%s needs %d blood. Hold a creature to offer." % [selected.animal.capitalize(), selected.cost]
	_refresh()

func _choose_lane(lane: int) -> void:
	if busy or finished or draw_required or selected == null or lane < 0 or lane > 7:
		return
	var card = board[lane]
	if card != null and selected.cost > 0 and selected.cost_type == "blood":
		if not card.sacrificable:
			status.text = "This card cannot be offered."
			return
		if offerings.has(card):
			# With enough offerings, tapping a marked slot places into it.
			if _offered_blood() >= selected.cost:
				_place(lane)
				return
			offerings.erase(card)
			card.marked = false
		elif _offered_blood() < selected.cost:
			offerings.append(card)
			card.marked = true
		card.queue_redraw()
		status.text = _blood_progress()
		_refresh()
		return
	_place(lane)

func _input(event: InputEvent) -> void:
	# Observe releases even when the pointer ends over another Control.
	if press_lane < 0:
		return
	if event is InputEventMouseMotion:
		if event.position.distance_to(press_origin) > HOLD_SLOP:
			press_canceled = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var lane := press_lane
		var tap: bool = not hold_consumed and not press_canceled and event.position.distance_to(press_origin) <= HOLD_SLOP
		press_lane = -1
		if tap and not busy and not finished and not is_instance_valid(modal):
			_choose_lane(lane)

func _unhandled_input(event: InputEvent) -> void:
	# Godot's touch-to-mouse emulation also routes phone taps here.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if busy or finished or is_instance_valid(modal):
			return
		if not hand_open and Rect2(106, 707, 178, 30).has_point(point):
			_hand_control()
			return
		if hand_open:
			for i in range(hand.size() - 1, -1, -1):
				if hand[i].visible and Rect2(-40, -59, 80, 118).has_point(hand[i].to_local(point)):
					_select_card(i)
					return
		if (point.y >= 449 and point.y <= 573) or (point.y >= 584 and point.y <= 706):
			if point.x < 14 or point.x > 376:
				return
			press_lane = clampi(int((point.x - 9) / 93), 0, 3) + (4 if point.y >= 584 else 0)
			press_origin = point
			press_age = 0
			press_canceled = false
			hold_consumed = false

func _place(lane: int) -> void:
	if busy or finished or draw_required or lane < 0 or lane > 7 or selected == null:
		return
	if not _payment_ready(selected):
		status.text = "Need %d bones; you have %d." % [selected.cost, bones] if selected.cost_type == "bones" else _blood_progress()
		return
	if board[lane] != null and (not offerings.has(board[lane]) or board[lane].sigils.has("many_lives")):
		status.text = "That lane is occupied. Choose an empty or marked slot."
		return
	var snapshot := _snapshot()
	var ids: Array = offerings.map(func(creature): return str(creature.get_instance_id()))
	var result: Dictionary = RULES.resolve_play(snapshot, str(selected.get_instance_id()), lane, ids)
	if not result.error.is_empty():
		status.text = result.error
		return
	_close_modal()
	busy = true
	selected = null
	for offering in offerings:
		offering.marked = false
		offering.queue_redraw()
	offerings.clear()
	_apply_resolved(result)
	_refresh()
	await _present_events(result.events)
	_layout_hand()
	busy = false
	_refresh()

func _settle(card: Node2D, destination: Vector2) -> void:
	if card.has_meta("layout_tween"):
		var previous: Tween = card.get_meta("layout_tween")
		if previous.is_valid():
			previous.kill()
	var tween := create_tween().set_parallel(true)
	card.queue_redraw()
	if reduced.button_pressed:
		card.position = destination
		tween.tween_property(card, "scale", Vector2.ONE, 0.15)
	else:
		tween.tween_property(card, "position", destination, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "rotation", -0.045, 0.2)
		tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.18)
		tween.chain().tween_property(card, "scale", Vector2(1.04, 0.94), 0.07)
		tween.chain().tween_property(card, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "rotation", 0.0, 0.17)
	await tween.finished
	card.z_index = 1

func _vanish(card: Node2D, sacrifice := false, returning := false) -> void:
	status.text = "Something under the table is hungry." if sacrifice else "%s returns to the soil." % card.animal.capitalize()
	var origin: Vector2 = card.position
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "modulate", Color(0.22, 0.12, 0.09, 0), 0.4)
	if not reduced.button_pressed:
		tween.tween_property(card, "scale", Vector2(0.08, 1.14), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(card, "position:y", card.position.y + 15, 0.4)
		for i in range(18):
			ash.append({"p": origin + Vector2(randf_range(-30, 30), randf_range(-45, 45)), "v": Vector2(randf_range(-12, 12), randf_range(-65, -20)), "life": randf_range(0.4, 0.9)})
	await tween.finished
	if returning:
		card.visible = false
	else:
		card.queue_free()

func _strike(card: Node2D, lane: int, enemy := false) -> void:
	if finished or not is_instance_valid(card) or card.power <= 0:
		return
	var result: Dictionary = RULES.resolve_attack(_snapshot(), str(card.get_instance_id()), lane, enemy)
	if not result.error.is_empty():
		return
	_apply_resolved(result)
	_refresh()
	await _present_events(result.events)

func _end_round() -> void:
	if busy or (draw_required and not finished):
		return
	if finished:
		if not run_deck.is_empty():
			battle_finished.emit(battle_won)
		else:
			_reset()
		return
	_close_modal()
	_clear_selection()
	busy = true
	_refresh()
	for lane in range(8):
		if board[lane]:
			await _strike(board[lane], lane)
		if _check_outcome():
			return
	await _transition("enemy")
	if skip_enemy:
		_float_text("TIME FOLDS", Vector2(195, 430), AMBER)
		await get_tree().create_timer(0.5).timeout
	else:
		await _advance_reserve()
		for lane in range(4):
			if enemies[lane]:
				await _strike(enemies[lane], lane, true)
			if _check_outcome():
				return
		await _refill_reserve()
	_apply_resolved(RULES.resolve_round_cleanup(_snapshot()))
	round_number += 1
	ambience.set_round(round_number)
	await _transition("player")
	if deck.is_empty() and squirrels == 0:
		await _starve()
		if _check_outcome():
			return
	draw_required = not deck.is_empty() or squirrels > 0
	status.text = "Draw one card: creature pile OR squirrel pile." if draw_required else "Both piles are empty. The wood is starving."
	hand_open = false
	_layout_hand()
	busy = false
	_refresh()

func _starve() -> void:
	var result: Dictionary = RULES.resolve_starvation(_snapshot())
	_apply_resolved(result)
	await _present_events(result.events)

func _check_outcome() -> bool:
	if finished:
		return true
	if abs(balance) < 5:
		return false
	_finish_battle(balance >= 5, "The balance has tipped in your favor." if balance >= 5 else "The balance has tipped against you.")
	return true

func _finish_battle(won: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	battle_won = won
	result_reason = reason
	busy = false
	draw_required = false
	press_lane = -1
	status.text = reason
	_refresh()
	_close_modal()
	modal = Control.new()
	modal.size = Vector2(390, 844)
	modal.z_index = 120
	add_child(modal)
	var shade := ColorRect.new()
	shade.size = modal.size
	shade.color = Color(0.02, 0.026, 0.018, 0.96)
	modal.add_child(shade)
	_modal_label("V I C T O R Y" if won else "D E F E A T", 225, 12, AMBER)
	var heading := _modal_label("THE WOOD YIELDS" if won else "THE WOOD CLAIMS YOU", 272, 27)
	_modal_label(reason, 365, 17, AMBER)
	_modal_label("%d %s · %d bones remain" % [round_number, "round" if round_number == 1 else "rounds", bones], 449, 12)
	_modal_label("You may leave. It will remember." if won else "No footsteps return from this table.", 518, 16)
	var proceed := _button("RETURN TO THE PATH" if not run_deck.is_empty() else "BEGIN ANOTHER RITUAL", Vector2(35, 710), Vector2(320, 56), _end_round)
	proceed.reparent(modal)
	heading.modulate.a = 0
	create_tween().tween_property(heading, "modulate:a", 1.0, 0.6)

func _next_whisper(kind: String) -> String:
	if not phrase_bags.has(kind) or phrase_bags[kind].is_empty():
		phrase_bags[kind] = WHISPERS[kind].duplicate()
		phrase_bags[kind].shuffle()
		if phrase_bags[kind].back() == last_whisper:
			phrase_bags[kind].push_front(phrase_bags[kind].pop_back())
	last_whisper = phrase_bags[kind].pop_back()
	return last_whisper

func _transition(kind: String) -> void:
	ambience.react("turn")
	whisper.text = _next_whisper(kind)
	whisper_hint.text = "I T S   T U R N" if kind == "enemy" else "Y O U R   T U R N"
	whisper_effect.reduced = reduced.button_pressed
	whisper_effect.strength = 0
	whisper.visible_ratio = 1.0 if reduced.button_pressed else 0.0
	whisper.modulate = Color(0.74, 0.48, 0.23, 0)
	whisper.position.y = 371 if reduced.button_pressed else 384
	whisper.scale = Vector2.ONE if reduced.button_pressed else Vector2(1.035, 1.035)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(veil, "color:a", 0.94, 0.35)
	tween.tween_property(whisper_effect, "strength", 1.0, 0.5)
	tween.tween_property(whisper_hint, "modulate:a", 1.0, 0.4)
	tween.tween_property(whisper, "modulate", PAPER, 0.65)
	if not reduced.button_pressed:
		tween.tween_property(whisper, "visible_ratio", 1.0, 0.75)
		tween.tween_property(whisper, "position:y", 371.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(whisper, "scale", Vector2.ONE, 0.9)
	await tween.finished
	await get_tree().create_timer(0.65).timeout
	tween = create_tween().set_parallel(true)
	tween.tween_property(veil, "color:a", 0.0, 0.45)
	tween.tween_property(whisper, "modulate:a", 0.0, 0.3)
	tween.tween_property(whisper_hint, "modulate:a", 0.0, 0.3)
	tween.tween_property(whisper_effect, "strength", 0.0, 0.4)
	await tween.finished

func _process(delta: float) -> void:
	ambience.reduced = reduced.button_pressed
	for card in board + enemies + reserve + hand:
		if is_instance_valid(card):
			card.reduced_motion = reduced.button_pressed
			card.fan_airborne = fan_active and board.has(card)
	if press_lane >= 0 and not press_canceled and not hold_consumed:
		press_age += delta
		if busy or finished or is_instance_valid(modal):
			press_canceled = true
		elif press_age >= HOLD_SECONDS and board[press_lane] != null:
			hold_consumed = true
			_open_inline_offering(press_lane)
	elapsed += delta
	pulse = maxf(0, pulse - delta * 4)
	for mote in ash:
		mote.p += mote.v * delta
		mote.life -= delta
	ash = ash.filter(func(mote): return mote.life > 0)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(backdrop, Rect2(0, 0, 390, 844), false)
	for row in range(4):
		for lane in range(4):
			var center := Vector2(55.5 + lane * 93, [241, 376, 511, 646][row])
			var rect := Rect2(center - Vector2(41.5, 62), Vector2(83, 124))
			var edge := Color("695745") if row == 0 else Color("8a7048")
			draw_rect(rect, edge, false, 1)
			draw_rect(rect.grow(-4), Color("493a2a"), false, 1)
			if row >= 2 and selected and _payment_ready(selected) and (board[(row - 2) * 4 + lane] == null or (offerings.has(board[(row - 2) * 4 + lane]) and not board[(row - 2) * 4 + lane].sigils.has("many_lives"))):
				draw_rect(rect, AMBER, false, 2)
	for lane in range(4):
		var x := 55.5 + lane * 93
		var blocked: bool = reserve[lane] != null and enemies[lane] != null
		var color := Color("9e5140") if blocked else AMBER.darkened(0.2)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 308), Vector2(x + 3, 308), Vector2(x, 313)]), color)
	draw_line(Vector2(22, 438), Vector2(368, 438), AMBER.darkened(0.6), 1)
	for mote in ash:
		draw_circle(mote.p, 1.3, Color(0.55, 0.31, 0.13, minf(mote.life, 1)))
	if pulse > 0:
		draw_line(Vector2(25, 438), Vector2(365, 438), Color(0.65, 0.25, 0.12, pulse), 2)


func _draw_from_deck(side := false) -> void:
	if busy or finished or not draw_required:
		return
	if (side and squirrels <= 0) or (not side and deck.is_empty()):
		return
	busy = true
	draw_required = false
	_refresh()
	var id: String = "squirrel" if side else deck.pop_front()
	if side:
		squirrels -= 1
	var drawn = _make_card(id)
	draw_index += 1
	drawn.position = Vector2(314 if side else 186, 759)
	drawn.scale = Vector2(0.4, 0.4)
	_record_event({"type": "draw", "actor": str(drawn.get_instance_id()), "source": "squirrel" if side else "creature"})
	hand.append(drawn)
	hand_open = false
	_layout_hand()
	await get_tree().create_timer(0.24).timeout
	busy = false
	status.text = "%s drawn. Your one draw is used." % drawn.animal.capitalize()
	_refresh()

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null

func _new_modal(title: String) -> void:
	_close_modal()
	modal = Control.new()
	modal.size = Vector2(390, 844)
	modal.z_index = 100
	add_child(modal)
	var shade := ColorRect.new()
	shade.size = modal.size
	shade.color = Color(0.025, 0.02, 0.015, 0.97)
	modal.add_child(shade)
	_modal_label(title, 92, 22, PAPER)
	var close := _button("BACK TO THE TABLE", Vector2(35, 754), Vector2(320, 48), _close_modal)
	close.reparent(modal)

func _modal_label(text: String, y: float, size := 13, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(25, y)
	label.size = Vector2(340, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	modal.add_child(label)
	return label

func _open_deck() -> void:
	if busy:
		return
	_new_modal("BOUND TO YOUR DECK")
	_modal_label("%d main · %d squirrels · %d in hand · %d discarded" % [deck.size(), squirrels, hand.size(), discard.size()], 135, 11, AMBER)
	_modal_label("Remaining cards · draw order concealed", 174, 12)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22, 210)
	scroll.size = Vector2(346, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for id in CATALOG.ids():
		if id in ["squirrel", "hare"]:
			continue
		var count := deck.filter(func(key): return _base_id(key) == id).size()
		var data: Resource = CATALOG.find(id)
		var row := _button("%s ×%d  |  %d / %d  |  %s" % [data.display_name, count, data.attack, data.health, _cost_text(id)], Vector2.ZERO, Vector2(330, 54), _open_library_card.bind(id))
		row.add_theme_font_size_override("font_size", 11)
		row.custom_minimum_size = Vector2(330, 54)
		row.reparent(rows)
	_modal_label("After the first turn, choose exactly one draw: main deck or squirrel pile. No hand-size limit. Squirrels are free to play and give one blood when sacrificed.", 575, 13, AMBER)
	_modal_label("Discarded: " + (", ".join(discard.map(func(key): return _base_id(key))) if not discard.is_empty() else "none"), 650, 12)

func _open_library_card(id: String) -> void:
	_new_modal(CATALOG.find(id).display_name)
	var preview = _make_card(id)
	preview.reparent(modal)
	preview.position = Vector2(195, 265)
	preview.scale = Vector2(2, 2)
	_modal_label(_role(id), 410, 16)
	_modal_label("Cost: " + _cost_text(id) + ". Bones are earned when your creatures die, including sacrifices. Blood is paid by marking creatures in either row.", 490, 14, AMBER)
	_modal_label(SIGILS.describe(preview.sigils), 578, 12, AMBER)
	var back := _button("BACK TO DECK", Vector2(35, 680), Vector2(320, 48), _open_deck)
	back.reparent(modal)

func _role(id: String) -> String:
	return CATALOG.find(_base_id(id)).role

func _offering_note(lane: int) -> String:
	var card = board[lane]
	var column := lane % 4
	if lane >= 4 and board[column] != null:
		return "%s in front takes enemy hits first." % board[column].animal.capitalize()
	var threat = enemies[column] if enemies[column] else reserve[column]
	if threat:
		return "%s threatens this lane." % threat.animal.capitalize()
	return "No visible threat in this lane."

func _toggle_offering(lane: int, inline := false) -> void:
	if busy or finished or draw_required or lane < 0 or lane > 7 or selected == null or selected.cost == 0 or selected.cost_type != "blood" or board[lane] == null or not board[lane].sacrificable:
		return
	var card = board[lane]
	if offerings.has(card):
		offerings.erase(card)
		card.marked = false
	elif _offered_blood() < selected.cost:
		offerings.append(card)
		card.marked = true
	card.queue_redraw()
	status.text = _blood_progress()
	_refresh()
	if inline:
		_close_modal()
	else:
		_open_inspector()

func _open_inspector() -> void:
	if busy:
		return
	_new_modal("THE DEAD ARE LISTENING" if selected and selected.cost_type == "bones" else "THE WOOD DEMANDS A LIFE")
	if selected:
		var preview = _make_card(selected.get_meta("card_id"))
		preview.reparent(modal)
		preview.position = Vector2(195, 235)
		preview.scale = Vector2(1.5, 1.5)
		_modal_label(_role(selected.get_meta("card_id")), 340, 13)
		_modal_label(("%d / %d bones available" % [bones, selected.cost]) if selected.cost_type == "bones" else ("%d of %d offerings marked" % [_offered_blood(), selected.cost]), 397, 15, AMBER)
	else:
		_modal_label("Select a card in your hand first. Its red dots show the number of creatures it needs.", 165, 17)
		_modal_label("Creatures in either of your rows can be offered. Hand cards, queued enemies, and deck cards are not offerings. Each marked creature provides one offering. Marking is reversible until placement.", 260, 14, AMBER)
	if selected and not selected.sigils.is_empty():
		_modal_label(SIGILS.names(selected.sigils), 429, 11, AMBER)
	if selected and selected.cost_type == "bones":
		_modal_label("Choose an empty glowing slot in either row. No additional sacrifice is needed. Bones are spent only when the creature is placed.", 460, 15, AMBER)
		var place_button := _button("CHOOSE ITS PLACE" if bones >= selected.cost else "MORE BONES NEEDED", Vector2(35, 605), Vector2(320, 48), _close_modal)
		place_button.disabled = bones < selected.cost
		place_button.reparent(modal)
		return
	if selected == null or selected.sigils.is_empty():
		_modal_label("Giving up a blocker can expose its lane.", 430, 12, AMBER)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22, 462)
	scroll.size = Vector2(346, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for lane in range(8):
		var card = board[lane]
		var location := "%s %d" % ["Front" if lane < 4 else "Back", lane % 4 + 1]
		var text := "%s · empty" % location
		if card:
			text = "%s %s · %s · %d attack / %d health\n%s" % ["[MARKED]" if offerings.has(card) else "[OFFER]", card.animal, location, card.power, card.health, _offering_note(lane)]
		var button := _button(text, Vector2.ZERO, Vector2(330, 56), _toggle_offering.bind(lane))
		button.add_theme_font_size_override("font_size", 10)
		button.custom_minimum_size = Vector2(330, 56)
		button.disabled = card == null or not card.sacrificable or selected == null or selected.cost == 0 or selected.cost_type != "blood" or finished or (_offered_blood() >= selected.cost and not offerings.has(card))
		button.reparent(rows)


func _open_inline_offering(lane: int) -> void:
	if busy or finished or lane < 0 or lane > 7 or board[lane] == null:
		return
	_close_modal()
	var card = board[lane]
	modal = Control.new()
	modal.size = Vector2(390, 844)
	modal.z_index = 100
	add_child(modal)
	var outside := ColorRect.new()
	outside.size = modal.size
	outside.color = Color(0, 0, 0, 0.12)
	outside.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_modal()
	)
	modal.add_child(outside)
	var panel := Panel.new()
	panel.position = Vector2(20, 302)
	panel.size = Vector2(350, 151)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color("211d16")
	box.border_color = AMBER
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	modal.add_child(panel)
	_modal_label("%s · %d attack / %d health" % [card.animal, card.power, card.health], 312, 16)
	var note := _offering_note(lane)
	if selected and selected.cost > 0 and selected.cost_type == "blood":
		note += "\n%d / %d blood marked for %s." % [_offered_blood(), selected.cost, selected.animal.capitalize()]
	else:
		note += "\nSelect a blood-cost card in your hand first."
	if not card.sigils.is_empty():
		note += "\n" + SIGILS.names(card.sigils)
	_modal_label(note, 342, 12, AMBER)
	var mark := _button("UNMARK OFFERING" if offerings.has(card) else "OFFER THIS CREATURE", Vector2(34, 399), Vector2(322, 44), _toggle_offering.bind(lane, true))
	mark.disabled = not card.sacrificable or draw_required or selected == null or selected.cost == 0 or selected.cost_type != "blood" or (_offered_blood() >= selected.cost and not offerings.has(card))
	mark.reparent(modal)


func _opening_deal() -> Array:
	var deal: Array = preload("res://scripts/battle_setup.gd").opening(deck)
	deal.shuffle()
	return deal


func _offered_blood() -> int:
	var total := 0
	for card in offerings:
		if is_instance_valid(card):
			total += 3 if card.sigils.has("worthy_sacrifice") else 1
	return total

func _payment_ready(card: Node2D) -> bool:
	if card.cost_type == "bones":
		return bones >= card.cost
	return _offered_blood() >= card.cost and offerings.all(func(creature): return is_instance_valid(creature) and creature.sacrificable and board.has(creature))

func _blood_progress() -> String:
	if selected == null:
		return ""
	return "%d/%d blood ready. Pick a glowing slot." % [_offered_blood(), selected.cost] if _offered_blood() >= selected.cost else "%d/%d blood marked. Mark another creature." % [_offered_blood(), selected.cost]

func _cost_text(id: String) -> String:
	var data: Resource = CATALOG.find(_base_id(id))
	return "%d %s" % [data.cost, data.cost_type]


func _attach_draw_stack(button: Button, side: bool) -> Node2D:
	button.add_theme_font_size_override("font_size", 10)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 29
		box.content_margin_right = 4
		button.add_theme_stylebox_override(state, box)
	var stack := preload("res://scripts/draw_pile.gd").new()
	stack.position = Vector2(5, 7)
	stack.squirrel_pile = side
	button.add_child(stack)
	return stack


func _snapshot() -> Dictionary:
	model_nodes = {}
	var state := {"cards": {}, "player": [], "enemy": [], "reserve": [], "hand": [], "items": items.duplicate(), "skip_enemy": skip_enemy, "fan_active": fan_active, "starvation": starvation, "bones": bones, "balance": balance}
	for pair in [["player", board], ["enemy", enemies], ["reserve", reserve], ["hand", hand]]:
		for card in pair[1]:
			if card == null:
				state[pair[0]].append("")
				continue
			var id := str(card.get_instance_id())
			model_nodes[id] = card
			state[pair[0]].append(id)
			state.cards[id] = {"attack": card.power, "health": card.health, "max_health": card.maximum_health(), "sigils": Array(card.sigils), "sacrificable": card.sacrificable, "cost": card.cost, "cost_type": card.cost_type, "owner": "enemy" if pair[0] in ["enemy", "reserve"] else "player"}
	return state

func _apply_resolved(result: Dictionary) -> void:
	var state: Dictionary = result.state
	items = state.get("items", items).duplicate()
	skip_enemy = state.get("skip_enemy", false)
	fan_active = state.get("fan_active", false)
	starvation = int(state.get("starvation", 0))
	bones = state.bones
	balance = state.balance
	for id in state.cards:
		if not model_nodes.has(id):
			model_nodes[id] = _make_card(state.cards[id].base_id)
			model_nodes[id].position = Vector2(65, 759)
		var card = model_nodes[id]
		card.display_health = card.health
		card.health = state.cards[id].health
	for pair in [["player", board], ["enemy", enemies], ["reserve", reserve], ["hand", hand]]:
		pair[1].clear()
		for id in state[pair[0]]:
			pair[1].append(null if id == "" else model_nodes[id])
	for event in result.events:
		_record_event(event)
		if event.type == "death" and event.player_owned:
			var card = model_nodes[event.actor]
			discard.append(card.get_meta("card_id"))

func _record_event(event: Dictionary) -> void:
	event_sequence += 1
	var logged := event.duplicate(true)
	logged.sequence = event_sequence
	event_log.append(logged)
	if event_log.size() > 256:
		event_log.pop_front()

func _float_text(text: String, at: Vector2, color: Color = PAPER) -> void:
	var label := _label(text, at - Vector2(48, 77), 14, color)
	label.size.x = 96
	label.z_index = 30
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	if not reduced.button_pressed:
		tween.tween_property(label, "position:y", label.position.y - 18, 0.7)
	tween.chain().tween_callback(label.queue_free)

func _present_events(events: Array) -> void:
	var origins := {}
	for id in model_nodes:
		if is_instance_valid(model_nodes[id]):
			origins[id] = model_nodes[id].position
	for event in events:
		match event.type:
			"item_used":
				status.text = ITEMS.DEFINITIONS[event.item].name + " awakens."
				ambience.react("sigil")
				_float_text(ITEMS.DEFINITIONS[event.item].name.to_upper(), Vector2(195, 430), AMBER)
				var tool = preload("res://scripts/item_icon.gd").new()
				tool.item = event.item
				tool.reduced = reduced.button_pressed
				tool.position = Vector2(195, 425)
				tool.scale = Vector2(1.7, 1.7)
				tool.z_index = 40
				add_child(tool)
				var effect := create_tween().set_parallel(true)
				if not reduced.button_pressed:
					effect.tween_property(tool, "rotation", PI if event.item == "hourglass" else 0.22, 0.5).set_trans(Tween.TRANS_CUBIC)
					effect.tween_property(tool, "scale", Vector2(2.1, 2.1), 0.5)
				effect.tween_property(tool, "modulate:a", 0.0, 0.5)
				await effect.finished
				tool.queue_free()
			"created":
				hand_open = false
				_layout_hand()
				await get_tree().create_timer(0.25).timeout
			"stolen":
				await _settle(model_nodes[event.actor], _slot(event.slot))
			"starvation":
				status.text = "Both piles are empty. Starvation takes %d." % event.amount
				_float_text("STARVATION −%d" % event.amount, Vector2(195, 430), AMBER)
				ambience.react("death")
				await get_tree().create_timer(0.35).timeout
			"attack":
				var card = model_nodes[event.actor]
				card.set_meta("attack_home", card.position)
				card.z_index = 15
				status.text = "%s strikes." % card.animal.capitalize()
				var tween := create_tween()
				if reduced.button_pressed:
					tween.tween_interval(0.12)
				else:
					tween.set_parallel(true)
					tween.tween_property(card, "position", card.position + Vector2(0, -17 if event.enemy else 17), 0.13)
					tween.tween_property(card, "rotation", -0.065, 0.13)
					tween.tween_property(card, "scale", Vector2(1.07, 1.07), 0.13)
					tween.chain().tween_property(card, "position", _slot(event.slot, not event.enemy) + Vector2(0, -30 if event.enemy else 30), 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				await tween.finished
			"attack_return":
				var card = model_nodes[event.actor]
				var tween := create_tween().set_parallel(true)
				tween.tween_property(card, "position", card.get_meta("attack_home", card.position), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "rotation", 0.0, 0.25)
				tween.tween_property(card, "scale", Vector2.ONE, 0.25)
				await tween.finished
				card.z_index = 1
			"damage":
				var card = model_nodes[event.target]
				card.display_health = int(event.get("remaining_health", card.health))
				card.queue_redraw()
				_float_text("−%d" % event.amount, card.position, AMBER)
				pulse = 1
				if not reduced.button_pressed:
					card.rotation = 0.08
					create_tween().tween_property(card, "rotation", 0.0, 0.25)
			"direct_damage":
				_float_text("−%d" % event.amount, _slot(event.slot, not event.enemy), AMBER)
				pulse = 1
			"sigil":
				var card = model_nodes[event.actor]
				card.trigger_sigil(event.sigil)
				status.text = SIGILS.DEFINITIONS[event.sigil].name
				_float_text(SIGILS.DEFINITIONS[event.sigil].name, card.position, AMBER)
				ambience.react("sigil")
				await get_tree().create_timer(0.12).timeout
			"attack_blocked":
				var card = model_nodes[event.actor]
				status.text = "%s: Stinky reduces this attack to zero." % card.animal.capitalize()
				_float_text("0 ATK · STINKY", card.position, AMBER)
				await get_tree().create_timer(0.3).timeout
			"death":
				ambience.react("death")
				await _vanish(model_nodes[event.actor], event.cause == "sacrifice", events.any(func(e): return e.type == "returned" and e.actor == event.actor))
			"bones_gained":
				_float_text("+%d BONES" % event.amount, origins.get(event.actor, Vector2(195, 430)))
			"returned":
				var card = model_nodes[event.actor]
				card.visible = true
				card.modulate = Color.WHITE
				card.scale = Vector2.ONE
				card.rotation = 0
				card.display_health = -1
				card.marked = false
				_layout_hand()
				_float_text("IT RETURNS", card.position, AMBER)
				await get_tree().create_timer(0.25).timeout
			"played":
				var card = model_nodes[event.actor]
				card.visible = true
				card.selected = false
				card.marked = false
				card.z_index = 12
				ambience.react("play")
				await _settle(card, _slot(event.slot))
				status.text = "The table accepts %s." % card.animal.capitalize()
			"outcome":
				_finish_battle(event.won, event.reason)
	_refresh()

func _inspect_or_items() -> void:
	if selected:
		_open_inspector()
	else:
		_open_items()

func _open_items() -> void:
	if busy or finished:
		return
	_new_modal("THE HUNGRY SATCHEL")
	_modal_label("Three pockets. Every tool is used only once.\n" + ("Draw your mandatory card before using a tool." if draw_required else "Choose a tool. Nothing is spent until you confirm a valid use."), 145, 13, AMBER)
	for i in range(ITEMS.CAPACITY):
		var y := 265 + i * 144
		if i >= items.size():
			_modal_label("— EMPTY POCKET —", y + 32, 12, AMBER.darkened(0.35))
			continue
		var data: Dictionary = ITEMS.DEFINITIONS[items[i]]
		var button := _button(data.name.to_upper(), Vector2(92, y), Vector2(275, 48), _inspect_item.bind(i))
		button.reparent(modal)
		var icon = preload("res://scripts/item_icon.gd").new()
		icon.item = items[i]
		icon.position = Vector2(54, y + 24)
		icon.reduced = reduced.button_pressed
		modal.add_child(icon)
		_modal_label(data.description, y + 56, 12, AMBER)

func _inspect_item(index: int) -> void:
	if busy or finished or index < 0 or index >= items.size():
		return
	var data: Dictionary = ITEMS.DEFINITIONS[items[index]]
	_new_modal(data.name.to_upper())
	_modal_label(data.description, 170, 16, AMBER)
	if data.target == "none":
		var button := _button("USE " + data.name.to_upper(), Vector2(35, 560), Vector2(320, 56), _use_item.bind(index))
		var waiting: bool = (items[index] == "hourglass" and skip_enemy) or (items[index] == "fan" and fan_active)
		button.disabled = draw_required or waiting
		if waiting:
			_modal_label("That effect is already waiting for this round.", 475, 13, AMBER)
		button.reparent(modal)
	else:
		_modal_label("Choose an active enemy. Reserve cards are out of reach.", 275, 13)
		for lane in range(4):
			var card = enemies[lane]
			var button := _button("LANE %d · %s" % [lane + 1, card.animal if card else "EMPTY"], Vector2(35, 340 + lane * 72), Vector2(320, 56), _choose_item_target.bind(index, lane))
			button.disabled = card == null or draw_required
			button.reparent(modal)

func _choose_item_target(index: int, lane: int) -> void:
	if busy or finished or draw_required or index < 0 or index >= items.size():
		return
	if items[index] != "fish_hook":
		_use_item(index, lane)
		return
	_new_modal("WHERE SHALL IT LAND?")
	_modal_label("The hook waits. Choose an empty place.\nBack to the table cancels without spending the hook.", 160, 14, AMBER)
	for slot in range(8):
		var button := _button("%s %d" % ["FRONT" if slot < 4 else "BACK", slot % 4 + 1], Vector2(24 + (slot % 2) * 177, 320 + (slot / 2) * 82), Vector2(165, 64), _use_item.bind(index, lane, slot))
		button.disabled = board[slot] != null
		button.reparent(modal)

func _use_item(index: int, target := -1, destination := -1) -> void:
	if busy or finished or draw_required:
		return
	var result: Dictionary = RULES.resolve_item(_snapshot(), index, target, destination)
	if not result.error.is_empty():
		status.text = result.error
		if is_instance_valid(modal):
			_modal_label(result.error, 675, 13, AMBER)
		return
	_clear_selection()
	_close_modal()
	busy = true
	_apply_resolved(result)
	inventory_changed.emit(items.duplicate())
	_refresh()
	await _present_events(result.events)
	_layout_hand()
	busy = false
	_refresh()
