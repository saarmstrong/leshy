extends Node2D
## Short persistent run: title -> branching map -> events / battles -> ending.
const FONT = preload("res://assets/fonts/NotoSerif-Regular.ttf")
const BACKDROP = preload("res://assets/art/emberwood-table.png")
const BATTLE = preload("res://scenes/attack_preview.tscn")
const CATALOG = preload("res://scripts/card_catalog.gd")
const ITEMS = preload("res://scripts/item_library.gd")
const CARD = preload("res://scripts/ritual_card.gd")
const SAVE_PATH = "user://emberwood-run-v1.json"
const PAPER = Color("d9cfb2")
const AMBER = Color("c68a43")
const NODES = {
	"gift": {"kind": "reward", "name": "A WHISPER", "p": Vector2(195, 650), "next": ["fire", "fight"]},
	"fire": {"kind": "fire", "name": "CAMPFIRE", "p": Vector2(100, 535), "next": ["fight2"]},
	"fight": {"kind": "battle", "name": "THE WATCHER", "p": Vector2(290, 535), "next": ["gift2"]},
	"fight2": {"kind": "battle", "name": "ROOTBOUND", "p": Vector2(100, 420), "next": ["shrine", "fire2", "pack"]},
	"gift2": {"kind": "reward", "name": "LOST CREATURE", "p": Vector2(290, 420), "next": ["shrine", "fire2", "pack"]},
	"pack": {"kind": "pack", "name": "OLD SATCHEL", "p": Vector2(195, 360), "next": ["last"]},
	"shrine": {"kind": "shrine", "name": "HOLLOW SHRINE", "p": Vector2(100, 305), "next": ["last"]},
	"fire2": {"kind": "fire", "name": "LAST EMBERS", "p": Vector2(290, 305), "next": ["last"]},
	"last": {"kind": "battle", "name": "THE THICKET", "p": Vector2(195, 190), "next": []},
}
var state: Dictionary = {}
var screen := "title"
var ambience: Node2D
var quiet := false
var reward_page := 1
var content: Node2D
var locked := false
var picked := -1
var battle: Node2D
var save_error := ""
var save_path := SAVE_PATH

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ambience = preload("res://scripts/haunted_table.gd").new()
	add_child(ambience)
	_load_run()
	_title()

func _clear(next_screen: String) -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Node2D.new()
	add_child(content)
	screen = next_screen
	ambience.visible = screen != "battle"
	ambience.set_process(screen != "battle")
	ambience.reduced = quiet
	locked = false
	picked = -1
	queue_redraw()

func _text(value: String, y: float, size := 16, color: Color = PAPER, x := 24.0, width := 342.0) -> Label:
	var label := Label.new()
	label.position = Vector2(x, y)
	label.size = Vector2(width, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.text = value
	content.add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2, callback: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.position = at
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.text = value
	button.disabled = not enabled
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color("746b58"))
	for mode in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("30291e") if mode == "hover" else Color("181b16")
		box.border_color = Color("514633") if mode == "disabled" else AMBER
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		button.add_theme_stylebox_override(mode, box)
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _card(entry: Dictionary, at: Vector2, factor: float) -> Node2D:
	var card = CARD.new()
	card.configure(CATALOG.find(entry.id), entry)
	card.reduced_motion = quiet
	card.position = at
	card.scale = Vector2(factor, factor)
	content.add_child(card)
	return card

func _title() -> void:
	_clear("title")
	var motion := CheckButton.new()
	motion.text = "Reduced motion"
	motion.position = Vector2(24, 8)
	motion.size = Vector2(150, 44)
	motion.add_theme_font_size_override("font_size", 10)
	motion.button_pressed = quiet
	motion.toggled.connect(func(enabled: bool) -> void:
		quiet = enabled
		ambience.reduced = enabled
	)
	content.add_child(motion)
	var left := _card({"id": "fox"}, Vector2(127, 306), 1.55)
	left.rotation = -0.14
	var right := _card({"id": "squirrel"}, Vector2(260, 307), 1.55)
	right.rotation = 0.14
	_text("T H E   H O L L O W", 439, 30)
	_text("E M B E R W O O D", 487, 12, AMBER)
	_text("The path is hungry.\nBring something it can take.", 538, 17)
	var can_continue: bool = not state.is_empty() and state.get("status", "") == "active"
	_button("CONTINUE INTO THE WOOD", Vector2(35, 637), Vector2(320, 56), _continue_run, can_continue)
	_button("BEGIN A NEW RUN", Vector2(35, 707), Vector2(320, 56), _new_run)
	_text("A short journey · cards, embers, and offerings", 788, 10, AMBER)
	if not save_error.is_empty():
		_text(save_error, 599, 11, Color("b77660"))

func _new_run() -> void:
	reward_page = 1
	state = {"version": 1, "status": "active", "deck": [], "completed": [], "available": ["gift"], "pending": "", "next_uid": 0, "battles_won": 0, "items": ITEMS.STARTER.duplicate()}
	for id in preload("res://scripts/battle_setup.gd").STARTER:
		_add_card(id)
	_save_run()
	_map()

func _add_card(id: String) -> void:
	state.deck.append({"uid": int(state.next_uid), "id": id, "attack_bonus": 0, "health_bonus": 0})
	state.next_uid = int(state.next_uid) + 1

func _continue_run() -> void:
	if state.is_empty():
		return
	if str(state.get("pending", "")).is_empty():
		_map()
	else:
		_open_node(str(state.pending))

func _map() -> void:
	_clear("map")
	_text("THE ASHEN PATH", 72, 26)
	_text("Choose a connected path. The others close behind you.", 111, 12, AMBER)
	for id in NODES:
		var node: Dictionary = NODES[id]
		var done: bool = state.completed.has(id)
		var available: bool = state.available.has(id)
		var prefix := "• " if done else ""
		var button := _button(prefix + node.name, node.p - Vector2(64, 28), Vector2(128, 56), _choose_node.bind(id), available)
		button.add_theme_font_size_override("font_size", 10)
		if done:
			button.add_theme_color_override("font_disabled_color", AMBER)
	_text("%d creatures bound · %d encounters survived" % [state.deck.size(), int(state.battles_won)], 715, 13)
	_button("YOUR DECK", Vector2(24, 757), Vector2(162, 50), _show_deck)
	_button("SAVE & TITLE", Vector2(200, 757), Vector2(166, 50), _title)
	if not save_error.is_empty():
		_text(save_error, 814, 10, Color("b77660"))

func _choose_node(id: String) -> void:
	if locked or state.get("status", "") != "active" or not state.available.has(id) or state.completed.has(id):
		return
	locked = true
	state.pending = id
	_save_run()
	_open_node(id)

func _open_node(id: String) -> void:
	match NODES[id].kind:
		"reward": _reward()
		"fire": _campfire()
		"shrine": _shrine()
		"battle": _start_battle()
		"pack": _backpack()

func _finish_node() -> void:
	var id := str(state.pending)
	if id.is_empty() or state.completed.has(id):
		return
	state.completed.append(id)
	state.available = NODES[id].next.duplicate()
	state.pending = ""
	if state.available.is_empty():
		state.status = "won"
	_save_run()
	if state.status == "won":
		_ending(true)
	else:
		_map()

func _event_header(title: String, description: String) -> void:
	_text(title, 150, 25)
	_text(description, 205, 15, AMBER)

func _reward() -> void:
	_clear("reward")
	_event_header("SOMETHING FOLLOWS", "One creature will walk with you.\nThe others will remember.")
	var pool := ["fox", "bone_stoat", "wolf", "ashen_stag", "ember_fox", "revenant_raven"] if state.pending == "gift" else ["grave_raven", "carrion_hound", "stag", "ossuary_hound", "ashen_stag", "revenant_raven"]
	var choices: Array = pool.slice((reward_page % 2) * 3, (reward_page % 2) * 3 + 3)
	for i in range(choices.size()):
		var x: float = 69 + i * 126
		_card({"id": choices[i]}, Vector2(x, 411), 1.1)
		_button("CHOOSE", Vector2(x - 56, 502), Vector2(112, 52), _take_reward.bind(choices[i]))
		var names: String = preload("res://scripts/sigil_library.gd").names(CATALOG.find(choices[i]).sigils)
		var description := _text(names, 565, 10, AMBER)
		description.position.x = x - 58
		description.size.x = 116
	_button("TURN THE OFFERINGS", Vector2(65, 638), Vector2(260, 48), func():
		reward_page = (reward_page + 1) % 2
		_reward())
	_text("Choose one creature from either set.", 710, 12)

func _take_reward(id: String) -> void:
	if locked or screen != "reward":
		return
	locked = true
	ambience.react("play")
	_add_card(id)
	_finish_node()

func _deck_rows(callback: Callable, y: float, height: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, y)
	scroll.size = Vector2(342, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for entry in state.deck:
		var data: Resource = CATALOG.find(entry.id)
		var value := "%s    %d attack / %d health    ·    %d %s" % [data.display_name, data.attack + int(entry.attack_bonus), data.health + int(entry.health_bonus), data.cost, data.cost_type]
		var button := _button(value, Vector2.ZERO, Vector2(326, 54), callback.bind(int(entry.uid)))
		button.add_theme_font_size_override("font_size", 12)
		button.reparent(rows)

func _find_entry(uid: int) -> int:
	for i in range(state.deck.size()):
		if int(state.deck[i].uid) == uid:
			return i
	return -1

func _campfire() -> void:
	_clear("fire")
	_event_header("A LITTLE WARMTH", "Choose one creature.\nOne safe warming, then leave.")
	_deck_rows(_pick_fire, 310, 330)
	_button("LEAVE THE FIRE", Vector2(35, 740), Vector2(320, 54), _finish_node)

func _pick_fire(uid: int) -> void:
	if screen != "fire" or locked:
		return
	picked = uid
	_clear_fire_choice(uid)

func _clear_fire_choice(uid: int) -> void:
	_clear("fire_choice")
	picked = uid
	var index := _find_entry(uid)
	if index < 0:
		_campfire()
		return
	_event_header("FEED THE EMBERS", "The warmth will stay with this creature.")
	_card(state.deck[index], Vector2(195, 400), 1.7)
	_button("+1 ATTACK", Vector2(24, 572), Vector2(162, 56), _upgrade.bind(uid, "attack_bonus"))
	_button("+2 HEALTH", Vector2(200, 572), Vector2(166, 56), _upgrade.bind(uid, "health_bonus"))
	_button("CHOOSE ANOTHER", Vector2(35, 740), Vector2(320, 54), _campfire)

func _upgrade(uid: int, stat: String) -> void:
	if screen != "fire_choice" or locked or stat not in ["attack_bonus", "health_bonus"]:
		return
	var index := _find_entry(uid)
	if index < 0:
		return
	locked = true
	state.deck[index][stat] = int(state.deck[index][stat]) + (1 if stat == "attack_bonus" else 2)
	_finish_node()

func _shrine() -> void:
	_clear("shrine")
	_event_header("THE HOLLOW SHRINE", "Leave one creature behind, forever.\nA thinner deck. A quieter walk.")
	_deck_rows(_confirm_remove, 310, 330)
	_button("LEAVE NOTHING", Vector2(35, 740), Vector2(320, 54), _finish_node)

func _confirm_remove(uid: int) -> void:
	if state.deck.size() <= 3:
		return
	_clear("shrine_choice")
	var index := _find_entry(uid)
	if index < 0:
		_shrine()
		return
	_event_header("IT WILL NOT RETURN", "Remove this exact creature from your run deck?")
	_card(state.deck[index], Vector2(195, 400), 1.7)
	_button("MAKE THE OFFERING", Vector2(35, 594), Vector2(320, 56), _remove_card.bind(uid))
	_button("KEEP IT", Vector2(35, 740), Vector2(320, 54), _shrine)

func _remove_card(uid: int) -> void:
	if locked or screen != "shrine_choice" or state.deck.size() <= 3:
		return
	var index := _find_entry(uid)
	if index < 0:
		return
	locked = true
	ambience.react("death")
	state.deck.remove_at(index)
	_finish_node()

func _show_deck() -> void:
	_clear("deck")
	_event_header("BOUND TO YOUR DECK", "Each creature is its own card.\nEmbers stay with the one you chose.")
	_deck_rows(_inspect_entry, 298, 410)
	_button("BACK TO THE PATH", Vector2(35, 750), Vector2(320, 54), _map)

func _inspect_entry(uid: int) -> void:
	var index := _find_entry(uid)
	if index < 0:
		return
	_clear("card")
	var card := _card(state.deck[index], Vector2(195, 398), 2.4)
	_text(preload("res://scripts/sigil_library.gd").describe(card.sigils), 600, 13, AMBER)
	_button("BACK TO YOUR DECK", Vector2(35, 750), Vector2(320, 54), _show_deck)

func _start_battle() -> void:
	_clear("battle")
	battle = BATTLE.instantiate()
	battle.preferred_reduced = quiet
	battle.configure_run(state.deck, int(state.battles_won) + (1 if state.pending == "last" else 0), state.get("items", ITEMS.STARTER))
	battle.inventory_changed.connect(func(inventory: Array):
		state.items = inventory.duplicate()
		_save_run())
	battle.battle_finished.connect(_battle_result)
	content.add_child(battle)

func _battle_result(won: bool) -> void:
	if screen != "battle" or locked:
		return
	locked = true
	quiet = battle.reduced.button_pressed
	if won:
		state.battles_won = int(state.battles_won) + 1
		_finish_node()
	else:
		state.status = "lost"
		_save_run()
		_ending(false)

func _ending(won: bool) -> void:
	_clear("ending")
	_text("THE WOOD RELEASES YOU" if won else "THE WOOD KEEPS YOU", 327, 26)
	_text("You crossed the thicket.\nThe forest is not finished with you." if won else "The path closes around your footprints.\nAnother walk. Another offering.", 416, 17, AMBER)
	_text("%d encounters survived" % int(state.battles_won), 535, 13)
	_button("RETURN TO TITLE", Vector2(35, 700), Vector2(320, 56), _title)

func _save_run() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
		save_error = ""
	else:
		save_error = "Could not save this run. Keep the game open."

func _load_run() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not loaded is Dictionary or int(loaded.get("version", 0)) != 1:
		save_error = "The old path could not be read. Begin a new run."
		return
	if not loaded.get("deck") is Array or not loaded.get("available") is Array or not loaded.get("completed") is Array:
		return
	for entry in loaded.deck:
		if not entry is Dictionary or not CATALOG.contains(entry.get("id", "")) or not entry.has("uid"):
			return
	for id in loaded.available + loaded.completed:
		if not NODES.has(id):
			return
	if not str(loaded.get("pending", "")).is_empty() and not NODES.has(loaded.pending):
		return
	var inventory = loaded.get("items", ITEMS.STARTER.duplicate())
	if not inventory is Array or inventory.size() > ITEMS.CAPACITY:
		return
	for item in inventory:
		if not ITEMS.DEFINITIONS.has(item):
			return
	loaded.items = inventory.duplicate()
	state = loaded

func _draw() -> void:
	draw_texture_rect(BACKDROP, Rect2(0, 0, 390, 844), false)
	if screen != "battle":
		draw_rect(Rect2(0, 135, 390, 709), Color(0.035, 0.042, 0.029, 0.48))
	if screen == "map":
		draw_rect(Rect2(24, 64, 342, 76), Color(0.035, 0.042, 0.029, 0.88))
		for id in NODES:
			var node: Dictionary = NODES[id]
			for next_id in node.next:
				var target: Vector2 = NODES[next_id].p
				var chosen: bool = state.completed.has(id) and (state.completed.has(next_id) or state.available.has(next_id))
				draw_line(node.p, target, AMBER if chosen else Color("534a36"), 2)
			# Small bare branches between the paths.
		for side in [18, 372]:
			for y in range(220, 700, 65):
				draw_line(Vector2(side, y + 28), Vector2(side + (12 if side == 18 else -12), y), Color("6b5939"), 1)

func _backpack() -> void:
	_clear("pack")
	_event_header("THE ABANDONED SATCHEL", "Take one tool for the path ahead.\nThree pockets are all the wood allows.")
	var inventory: Array = state.get("items", ITEMS.STARTER.duplicate())
	if inventory.size() < ITEMS.CAPACITY:
		_pack_choose_slot(inventory.size())
		return
	_text("Your pockets are full. Choose a tool to replace.", 310, 13, AMBER)
	for i in range(inventory.size()):
		_button("REPLACE " + ITEMS.DEFINITIONS[inventory[i]].name.to_upper(), Vector2(35, 370 + i * 80), Vector2(320, 60), _pack_choose_slot.bind(i))
	_button("LEAVE IT CLOSED", Vector2(35, 750), Vector2(320, 54), _finish_node)

func _pack_choose_slot(slot: int) -> void:
	_clear("pack")
	_event_header("CHOOSE YOUR TOOL", "One tool. One committed choice.\nInspect it before breaking the seal.")
	var ids: Array = ITEMS.DEFINITIONS.keys()
	for i in range(ids.size()):
		var item: String = ids[i]
		var at := Vector2(24 + (i % 2) * 177, 308 + (i / 2) * 118)
		var button := _button(ITEMS.DEFINITIONS[item].name.to_upper(), at, Vector2(165, 100), _pack_inspect.bind(item, slot))
		button.add_theme_font_size_override("font_size", 10)
		var icon = preload("res://scripts/item_icon.gd").new()
		icon.item = item
		icon.reduced = quiet
		icon.position = at + Vector2(82, 32)
		content.add_child(icon)
		button.add_theme_constant_override("outline_size", 0)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		style.content_margin_top = 55
		button.add_theme_stylebox_override("normal", style)
	_button("LEAVE IT CLOSED", Vector2(35, 750), Vector2(320, 54), _finish_node)

func _pack_inspect(item: String, slot: int) -> void:
	_clear("pack")
	_event_header(ITEMS.DEFINITIONS[item].name.to_upper(), ITEMS.DEFINITIONS[item].description)
	var icon = preload("res://scripts/item_icon.gd").new()
	icon.item = item
	icon.reduced = quiet
	icon.position = Vector2(195, 400)
	icon.scale = Vector2(2, 2)
	content.add_child(icon)
	_button("TAKE THIS TOOL", Vector2(35, 620), Vector2(320, 56), _take_item.bind(item, slot))
	_button("OTHER TOOLS", Vector2(35, 694), Vector2(320, 48), _pack_choose_slot.bind(slot))

func _take_item(item: String, slot: int) -> void:
	if locked or screen != "pack" or state.pending != "pack" or not ITEMS.DEFINITIONS.has(item):
		return
	var inventory: Array = state.get("items", ITEMS.STARTER.duplicate()).duplicate()
	if slot < 0 or slot > inventory.size() or slot >= ITEMS.CAPACITY:
		return
	locked = true
	if slot == inventory.size():
		inventory.append(item)
	else:
		inventory[slot] = item
	state.items = inventory
	_finish_node()
