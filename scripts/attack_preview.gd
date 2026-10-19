extends Node2D
## A small ritual sandbox: costs, placement, lane combat, and round transitions.
const PAPER = Color("d9cfb2")
const AMBER = Color("c68a43")
const FONT = preload("res://assets/fonts/NotoSerif-Regular.ttf")
const CARD = preload("res://scripts/ritual_card.gd")
const DATA = {
	"squirrel": ["SQUIRREL", 0, 1, 0],
	"hare": ["HARE", 0, 1, 0],
	"fox": ["FOX", 2, 3, 1],
	"raven": ["RAVEN", 1, 2, 1],
	"stag": ["STAG", 3, 4, 2],
	"wolf": ["WOLF", 2, 4, 2],
}
var board: Array = [null, null, null, null]
var enemies: Array = [null, null, null, null]
var reserve: Array = [null, null, null, null]
var reserve_index := 0
var hand: Array = []
var offerings: Array = []
var selected: Node2D
var busy := false
var finished := false
var round_number := 1
var balance := 0
const STARTING_DECK = ["fox", "stag", "wolf", "raven", "fox", "wolf", "stag", "raven", "fox", "wolf", "raven", "stag"]
var squirrels := 10
var draw_required := false
var hand_open := false
var hand_page := 0
var main_draw: Button
var squirrel_draw: Button
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
	_label("T H E   H O L L O W", Vector2(0, 125), 19)
	counter = _label("", Vector2(0, 155), 10, AMBER)
	status = _label("", Vector2(12, 710), 12)
	status.size = Vector2(366, 33)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button("END ROUND", Vector2(252, 790), Vector2(124, 46), _end_round)
	cancel = _button("HAND", Vector2(132, 790), Vector2(108, 46), _hand_control)
	reduced = CheckButton.new()
	reduced.text = "Reduced motion"
	reduced.position = Vector2(14, 75)
	reduced.size = Vector2(180, 44)
	reduced.add_theme_font_size_override("font_size", 12)
	add_child(reduced)
	veil = ColorRect.new()
	veil.size = Vector2(390, 844)
	veil.color = Color(0.025, 0.018, 0.012, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 50
	add_child(veil)
	whisper = _label("", Vector2(20, 380), 22, PAPER)
	whisper.size.x = 350
	whisper.modulate.a = 0
	whisper.z_index = 51
	for row in [["WAITING IN THE DARK", 168], ["OPPONENT", 305], ["YOUR CREATURES", 440], ["YOUR HAND", 575]]:
		_label(row[0], Vector2(0, row[1]), 8, AMBER)
	deck_button = _button("DECK", Vector2(14, 790), Vector2(108, 46), _open_deck)
	main_draw = _button("MAIN", Vector2(132, 737), Vector2(108, 46), _draw_from_deck.bind(false))
	squirrel_draw = _button("SQUIRREL", Vector2(252, 737), Vector2(124, 46), _draw_from_deck.bind(true))
	previous_hand = _button("‹", Vector2(14, 663), Vector2(44, 44), _page_hand.bind(-1))
	next_hand = _button("›", Vector2(332, 663), Vector2(44, 44), _page_hand.bind(1))
	inspect_button = _button("OFFERINGS", Vector2(14, 737), Vector2(108, 46), _open_inspector)
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
	var data: Array = DATA[id]
	card.set_meta("card_id", id)
	card.animal = data[0]
	card.power = data[1]
	card.health = data[2]
	card.cost = data[3]
	card.artwork = load("res://assets/art/%s.png" % id)
	add_child(card)
	return card

func _slot(lane: int, enemy := false) -> Vector2:
	return Vector2(55.5 + lane * 93, 376 if enemy else 511)

func _reserve_slot(lane: int) -> Vector2:
	return Vector2(55.5 + lane * 93, 241)

func _queue_enemy(lane: int) -> void:
	var sequence := ["raven", "wolf", "fox", "stag"]
	var card = _make_card(sequence[reserve_index % sequence.size()])
	reserve_index += 1
	reserve[lane] = card
	card.position = _reserve_slot(lane)

func _advance_reserve() -> void:
	# A blocked lane holds its exact queued card. Only the active row fights.
	for lane in range(4):
		if reserve[lane] != null and enemies[lane] == null:
			var card = reserve[lane]
			reserve[lane] = null
			enemies[lane] = card
			status.text = "%s steps out of the dark." % card.animal.capitalize()
			await _settle(card, _slot(lane, true))

func _refill_reserve() -> void:
	# Refill after enemy combat so new intentions are visible for a player turn.
	var lane: int = (round_number + 1) % 4
	for offset in range(4):
		var candidate: int = (lane + offset) % 4
		if reserve[candidate] == null:
			_queue_enemy(candidate)
			var card = reserve[candidate]
			card.modulate.a = 0
			await create_tween().tween_property(card, "modulate:a", 1.0, 0.35).finished
			return

func _reset() -> void:
	for card in board + enemies + reserve + hand:
		if is_instance_valid(card):
			card.queue_free()
	board = [null, null, null, null]
	enemies = [null, null, null, null]
	reserve = [null, null, null, null]
	reserve_index = 0
	hand = []
	offerings.clear()
	selected = null
	balance = 0
	round_number = 1
	draw_index = 0
	deck = STARTING_DECK.duplicate()
	discard.clear()
	_close_modal()
	finished = false
	squirrels = 9
	draw_required = false
	hand_open = false
	hand_page = 0
	enemies[1] = _make_card("wolf")
	enemies[1].position = _slot(1, true)
	_queue_enemy(2)
	_queue_enemy(1)
	for i in range(3):
		hand.append(_make_card(deck.pop_front()))
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
		var destination := Vector2(195 + offset * (64 if hand_open else 23), (630 if hand_open else 677) + absf(offset) * 4)
		var angle := offset * (0.075 if hand_open else 0.11)
		var card_scale := Vector2(0.93, 0.93) if hand_open else Vector2(0.4, 0.4)
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
	counter.text = "ROUND %d     •     BALANCE %+d / 5" % [round_number, balance]
	deck_button.text = "DECK LIST"
	main_draw.text = "MAIN · %d" % deck.size()
	squirrel_draw.text = "SQUIRREL · %d" % squirrels
	main_draw.disabled = busy or finished or not draw_required or deck.is_empty()
	squirrel_draw.disabled = busy or finished or not draw_required or squirrels <= 0
	previous_hand.visible = hand_open and hand_page > 0
	next_hand.visible = hand_open and (hand_page + 1) * 5 < hand.size()
	deck_button.disabled = busy
	inspect_button.text = "CARD INFO" if selected else "OFFERINGS"
	inspect_button.disabled = busy
	action.disabled = busy or (draw_required and not finished)
	cancel.disabled = busy
	cancel.text = "CANCEL PLAY" if selected else ("HIDE HAND" if hand_open else "HAND · %d" % hand.size())
	reduced.disabled = busy
	action.text = "NEW RITUAL" if finished else "END ROUND"
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
	if selected.cost == 0:
		status.text = "%s is free. Tap an empty lane." % selected.animal.capitalize()
	else:
		status.text = "%s needs %d offering(s). Tap your creatures." % [selected.animal.capitalize(), selected.cost]
	_refresh()

func _choose_lane(lane: int) -> void:
	if busy or finished or draw_required or selected == null or lane < 0 or lane > 3:
		return
	var card = board[lane]
	if card != null and selected.cost > 0:
		if offerings.has(card):
			# With enough offerings, tapping a marked slot places into it.
			if offerings.size() == selected.cost:
				_place(lane)
				return
			offerings.erase(card)
			card.marked = false
		elif offerings.size() < selected.cost:
			offerings.append(card)
			card.marked = true
		card.queue_redraw()
		status.text = "%d / %d marked. Tap a glowing lane to place." % [offerings.size(), selected.cost]
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
		if not hand_open and Rect2(106, 632, 178, 74).has_point(point):
			_hand_control()
			return
		if hand_open:
			for i in range(hand.size() - 1, -1, -1):
				if hand[i].visible and Rect2(-40, -59, 80, 118).has_point(hand[i].to_local(point)):
					_select_card(i)
					return
		if point.y >= 449 and point.y <= 573:
			if point.x < 14 or point.x > 376:
				return
			press_lane = clampi(int((point.x - 9) / 93), 0, 3)
			press_origin = point
			press_age = 0
			press_canceled = false
			hold_consumed = false

func _place(lane: int) -> void:
	if busy or finished or draw_required or lane < 0 or lane > 3 or selected == null or offerings.size() != selected.cost:
		return
	if board[lane] != null and not offerings.has(board[lane]):
		status.text = "That lane is occupied. Choose an empty or marked slot."
		return
	_close_modal()
	busy = true
	_refresh()
	var entering = selected
	selected = null
	entering.selected = false
	entering.visible = true
	entering.z_index = 12
	for victim in offerings:
		board[board.find(victim)] = null
		await _vanish(victim, true)
	offerings.clear()
	hand.erase(entering)
	board[lane] = entering
	status.text = "The table accepts %s." % entering.animal.capitalize()
	await _settle(entering, _slot(lane))
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

func _vanish(card: Node2D, sacrifice := false, player_owned := false) -> void:
	if sacrifice or player_owned:
		discard.append(card.get_meta("card_id"))
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
	card.queue_free()

func _strike(card: Node2D, lane: int, enemy := false) -> void:
	if card.power == 0:
		return
	var defenders: Array = board if enemy else enemies
	var victim = defenders[lane]
	var home: Vector2 = card.position
	var destination := _slot(lane, not enemy)
	card.z_index = 15
	status.text = "%s strikes." % card.animal.capitalize()
	var tween := create_tween()
	if not reduced.button_pressed:
		tween.set_parallel(true)
		tween.tween_property(card, "position", home + Vector2(0, -17 if enemy else 17), 0.13)
		tween.tween_property(card, "rotation", -0.065, 0.13)
		tween.tween_property(card, "scale", Vector2(1.07, 1.07), 0.13)
		tween.chain().tween_property(card, "position", destination + Vector2(0, -30 if enemy else 30), 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(0.12)
	await tween.finished
	pulse = 1
	var damage := _label("−%d" % card.power, destination + Vector2(8, -85), 24, Color("cf9d68"))
	damage.size.x = 70
	damage.z_index = 30
	var damage_tween := create_tween().set_parallel(true)
	damage_tween.tween_property(damage, "modulate:a", 0.0, 0.65)
	if not reduced.button_pressed:
		damage_tween.tween_property(damage, "position:y", damage.position.y - 20, 0.65)
	damage_tween.chain().tween_callback(damage.queue_free)
	if victim:
		victim.health -= card.power
		victim.queue_redraw()
		if not reduced.button_pressed:
			victim.rotation = 0.08
			create_tween().tween_property(victim, "rotation", 0.0, 0.25)
	else:
		balance += -card.power if enemy else card.power
	_refresh()
	tween = create_tween().set_parallel(true)
	tween.tween_property(card, "position", home, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", 0.0, 0.25)
	tween.tween_property(card, "scale", Vector2.ONE, 0.25)
	await tween.finished
	card.z_index = 1
	if victim and victim.health <= 0:
		defenders[lane] = null
		await _vanish(victim, false, enemy)

func _end_round() -> void:
	if busy or (draw_required and not finished):
		return
	if finished:
		_reset()
		return
	_close_modal()
	_clear_selection()
	busy = true
	_refresh()
	for lane in range(4):
		if board[lane]:
			await _strike(board[lane], lane)
		if _check_outcome():
			return
	await _transition("It has learned your scent.")
	await _advance_reserve()
	for lane in range(4):
		if enemies[lane]:
			await _strike(enemies[lane], lane, true)
		if _check_outcome():
			return
	await _refill_reserve()
	round_number += 1
	await _transition("The candles remember you.")
	draw_required = not deck.is_empty() or squirrels > 0
	status.text = "Choose one draw: main deck or squirrel." if draw_required else "Both piles are empty. The wood is starving."
	hand_open = false
	_layout_hand()
	busy = false
	_refresh()

func _check_outcome() -> bool:
	if abs(balance) < 5:
		return false
	finished = true
	status.text = "It lets you leave. For now." if balance >= 6 else "The wood has claimed you."
	busy = false
	_refresh()
	return true

func _transition(text: String) -> void:
	whisper.text = text
	var tween := create_tween().set_parallel(true)
	tween.tween_property(veil, "color:a", 0.85, 0.45)
	tween.tween_property(whisper, "modulate:a", 1.0, 0.45)
	await tween.finished
	await get_tree().create_timer(0.55).timeout
	tween = create_tween().set_parallel(true)
	tween.tween_property(veil, "color:a", 0.0, 0.55)
	tween.tween_property(whisper, "modulate:a", 0.0, 0.4)
	await tween.finished

func _process(delta: float) -> void:
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
			if row == 2 and selected and offerings.size() == selected.cost and (board[lane] == null or offerings.has(board[lane])):
				draw_rect(rect, AMBER, false, 2)
	for lane in range(4):
		var x := 55.5 + lane * 93
		var blocked: bool = reserve[lane] != null and enemies[lane] != null
		var color := Color("9e5140") if blocked else AMBER.darkened(0.2)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 308), Vector2(x + 3, 308), Vector2(x, 313)]), color)
	draw_line(Vector2(22, 438), Vector2(368, 438), AMBER.darkened(0.6), 1)
	# The shrine watches; slow, low-contrast glow rather than flashing.
	var glow := 0.5 if reduced and reduced.button_pressed else 0.46 + sin(elapsed * 1.2) * 0.12
	for x in [174, 188]:
		draw_circle(Vector2(x, 48), 1.2, Color(0.7, 0.26, 0.09, glow))
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
	hand.append(drawn)
	hand_open = false
	_layout_hand()
	await get_tree().create_timer(0.24).timeout
	busy = false
	status.text = "%s joins your hand. Choose what lives." % drawn.animal.capitalize()
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
	var y := 210.0
	for id in DATA:
		if id in ["squirrel", "hare"]:
			continue
		var count := deck.count(id)
		var data: Array = DATA[id]
		var row := _button("%s ×%d    |    %d attack / %d health    |    cost %d" % [data[0], count, data[1], data[2], data[3]], Vector2(22, y), Vector2(346, 60), _open_library_card.bind(id))
		row.add_theme_font_size_override("font_size", 11)
		row.reparent(modal)
		y += 69
	_modal_label("After the first turn, choose exactly one draw: main deck or squirrel pile. No hand-size limit. Squirrels are free to play and give one blood when sacrificed.", 575, 13, AMBER)
	_modal_label("Discarded: " + (", ".join(discard) if not discard.is_empty() else "none"), 650, 12)

func _open_library_card(id: String) -> void:
	_new_modal(DATA[id][0])
	var preview = _make_card(id)
	preview.reparent(modal)
	preview.position = Vector2(195, 265)
	preview.scale = Vector2(2, 2)
	_modal_label(_role(id), 410, 16)
	_modal_label("Sacrifice cost: %d creature(s). Each creature on your active row provides one offering. Cards in hand or deck cannot be sacrificed." % DATA[id][3], 490, 14, AMBER)
	var back := _button("BACK TO DECK", Vector2(35, 680), Vector2(320, 48), _open_deck)
	back.reparent(modal)

func _role(id: String) -> String:
	match id:
		"squirrel": return "Free to play. 0 attack, 1 health. Sacrifice it on the table for one blood."
		"hare": return "Free to play. No attack; a small blocker and a cheap offering."
		"fox": return "A steady attacker. Giving it up removes 2 attack from its lane."
		"raven": return "A light attacker. Fights the creature directly across its lane."
		"stag": return "A heavy hitter with 4 health. Costs two lives to summon."
		_: return "A sturdy predator. Two offerings buy 2 attack and 4 health."

func _offering_note(lane: int) -> String:
	var card = board[lane]
	var threat = enemies[lane] if enemies[lane] else reserve[lane]
	if threat:
		return "%s threatens this lane." % threat.animal.capitalize()
	return "No visible threat in this lane."

func _toggle_offering(lane: int, inline := false) -> void:
	if busy or finished or draw_required or lane < 0 or lane > 3 or selected == null or selected.cost == 0 or board[lane] == null:
		return
	var card = board[lane]
	if offerings.has(card):
		offerings.erase(card)
		card.marked = false
	elif offerings.size() < selected.cost:
		offerings.append(card)
		card.marked = true
	card.queue_redraw()
	status.text = "%d / %d marked. Choose a glowing lane to commit." % [offerings.size(), selected.cost]
	_refresh()
	if inline:
		_close_modal()
	else:
		_open_inspector()

func _open_inspector() -> void:
	if busy:
		return
	_new_modal("THE WOOD DEMANDS A LIFE")
	if selected:
		var preview = _make_card(selected.get_meta("card_id"))
		preview.reparent(modal)
		preview.position = Vector2(195, 235)
		preview.scale = Vector2(1.5, 1.5)
		_modal_label(_role(selected.get_meta("card_id")), 340, 13)
		_modal_label("%d of %d offerings marked" % [offerings.size(), selected.cost], 397, 15, AMBER)
	else:
		_modal_label("Select a card in your hand first. Its red dots show the number of creatures it needs.", 165, 17)
		_modal_label("Only creatures on your active row can be offered. Hand cards, queued enemies, and deck cards are not offerings. Each marked creature provides one offering. Marking is reversible until placement.", 260, 14, AMBER)
	_modal_label("Giving up a blocker can expose its lane.", 430, 12, AMBER)
	for lane in range(4):
		var card = board[lane]
		var text := "Lane %d · empty" % (lane + 1)
		if card:
			text = "%s %s · %d attack / %d health\n%s" % ["[MARKED]" if offerings.has(card) else "[OFFER]", card.animal, card.power, card.health, _offering_note(lane)]
		var button := _button(text, Vector2(22, 462 + lane * 64), Vector2(346, 56), _toggle_offering.bind(lane))
		button.add_theme_font_size_override("font_size", 11)
		button.disabled = card == null or selected == null or selected.cost == 0 or finished or (offerings.size() >= selected.cost and not offerings.has(card))
		button.reparent(modal)


func _open_inline_offering(lane: int) -> void:
	if busy or finished or lane < 0 or lane > 3 or board[lane] == null:
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
	if selected and selected.cost > 0:
		note += "\n%d / %d blood marked for %s." % [offerings.size(), selected.cost, selected.animal.capitalize()]
	else:
		note += "\nSelect a blood-cost card in your hand first."
	_modal_label(note, 342, 12, AMBER)
	var mark := _button("UNMARK OFFERING" if offerings.has(card) else "OFFER THIS CREATURE", Vector2(34, 399), Vector2(322, 44), _toggle_offering.bind(lane, true))
	mark.disabled = draw_required or selected == null or selected.cost == 0 or (offerings.size() >= selected.cost and not offerings.has(card))
	mark.reparent(modal)
