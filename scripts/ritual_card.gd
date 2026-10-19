extends Node2D
class_name RitualCard

var reduced_motion := false
var idle_time := 0.0
var idle_phase := 0.0
var sigil_flashes: Dictionary = {}

func trigger_sigil(id: String) -> void:
	sigil_flashes[id] = 1.0
	queue_redraw()

func _ready() -> void:
	idle_phase = fmod(float(get_instance_id()), 73.0) * 0.37

func _process(delta: float) -> void:
	for id in sigil_flashes:
		sigil_flashes[id] = maxf(0, sigil_flashes[id] - delta * 1.7)
	if not is_visible_in_tree():
		return
	if not reduced_motion:
		idle_time += delta
	queue_redraw()

var animal := "FOX"
var health := 3
var display_health := -1
var power := 2
var font: Font = preload("res://assets/fonts/NotoSerif-Regular.ttf")
var artwork: Texture2D
var card_back := false
var fan_airborne := false
var cost := 0
var cost_type := "blood"
var selected := false
var marked := false
var definition: Resource
var tribe := "none"
var sacrificable := true
var sigils: PackedStringArray = []
var permanent_attack_bonus := 0
var permanent_health_bonus := 0
var temporary_attack_bonus := 0
var temporary_health_bonus := 0

func configure(base: Resource, permanent: Dictionary = {}) -> void:
	definition = base
	animal = base.display_name
	artwork = base.artwork
	cost = base.cost
	cost_type = base.cost_type
	tribe = base.tribe
	sacrificable = base.sacrificable
	sigils = base.sigils.duplicate()
	for sigil in permanent.get("added_sigils", []):
		if not sigils.has(str(sigil)):
			sigils.append(str(sigil))
	permanent_attack_bonus = int(permanent.get("attack_bonus", 0))
	permanent_health_bonus = int(permanent.get("health_bonus", 0))
	temporary_attack_bonus = 0
	temporary_health_bonus = 0
	power = base.attack + permanent_attack_bonus
	health = maximum_health()
	display_health = -1
	queue_redraw()

func maximum_health() -> int:
	return definition.health + permanent_health_bonus + temporary_health_bonus if definition else health

func apply_temporary_bonus(attack_delta: int, health_delta: int) -> void:
	temporary_attack_bonus += attack_delta
	temporary_health_bonus += health_delta
	power += attack_delta
	health += health_delta
	display_health = -1
	queue_redraw()


func _draw() -> void:
	if selected or marked:
		var edge := Color("bd5540") if marked else Color("d6ac65")
		draw_rect(Rect2(-43, -62, 86, 124), edge, false, 2)

	draw_style_box(_box(Color(0, 0, 0, 0.5)), Rect2(-35, -52, 80, 118))
	if artwork:
		draw_texture_rect(artwork, Rect2(-40, -59, 80, 118), false)
	else:
		draw_style_box(_box(Color("27231c")), Rect2(-40, -59, 80, 118))
		draw_rect(Rect2(-36, -55, 72, 110), Color("8a7048"), false)
	if card_back:
		for i in range(6):
			var y := float(i * 8 - 25)
			draw_line(Vector2(0, y + 12), Vector2(-12, y), Color("9c8055"), 1)
			draw_line(Vector2(0, y + 12), Vector2(12, y), Color("9c8055"), 1)
		draw_line(Vector2(0, -30), Vector2(0, 34), Color("9c8055"), 1)
		return
	# Only the engraved portrait breathes; frame, cost and stats stay anchored.
	if artwork and not reduced_motion:
		var portrait := Rect2(-30, -33, 60, 54)
		var source := Rect2(Vector2(10, 26), portrait.size)
		var breath := 1.0 + sin(idle_time * 1.6 + idle_phase) * 0.009
		source.position += source.size * (1.0 - 1.0 / breath) * 0.5
		source.size /= breath
		var factor := Vector2(artwork.get_width() / 80.0, artwork.get_height() / 118.0)
		draw_texture_rect_region(artwork, portrait, Rect2(source.position * factor, source.size * factor))
		# An occasional warm sheen passes over the living ink.
		var shimmer := pow(maxf(0, sin(idle_time * 0.72 + idle_phase)), 12) * 0.13
		for i in range(3):
			var at := Vector2(-18 + i * 16, -8 + sin(idle_time + i + idle_phase) * 12)
			draw_circle(at, 0.7, Color(0.96, 0.66, 0.28, shimmer))
	# Small top-left cost; the name sits alongside it, leaving the art clear.
	var name_size := 8
	while name_size > 6 and font.get_string_size(animal, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > 47:
		name_size -= 1
	draw_string(font, Vector2(-12, -45), animal, HORIZONTAL_ALIGNMENT_CENTER, 47, name_size, Color("302b24"))
	if cost == 0:
		draw_string(font, Vector2(-33, -45), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("514737"))
	elif cost_type == "bones":
		draw_line(Vector2(-33, -51), Vector2(-28, -46), Color("403a2d"), 1.5)
		for point in [Vector2(-34, -52), Vector2(-35, -50), Vector2(-27, -46), Vector2(-29, -44)]:
			draw_circle(point, 1.2, Color("403a2d"))
		draw_string(font, Vector2(-25, -45), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("302b24"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-32, -53), Vector2(-35, -48), Vector2(-34, -45), Vector2(-30, -45), Vector2(-29, -48)]), Color("8e3727"))
		draw_string(font, Vector2(-26, -45), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("702d22"))
	if marked:
		draw_line(Vector2(-22, -23), Vector2(22, 24), Color("903d2c"), 2)
		draw_line(Vector2(22, -23), Vector2(-22, 24), Color("903d2c"), 2)
	var visible_sigils := sigils.duplicate()
	if fan_airborne and not visible_sigils.has("airborne"):
		visible_sigils.append("airborne")
	for i in range(visible_sigils.size()):
		_draw_sigil(visible_sigils[i], Vector2((i - (visible_sigils.size() - 1) / 2.0) * 17, 26))
	# Stats remain live and separate from generated card artwork.
	draw_line(Vector2(-30, 34), Vector2(30, 34), Color("8a7048"), 0.7)
	draw_line(Vector2(-29, 49), Vector2(-20, 39), Color("302b24"), 1.4)
	draw_line(Vector2(-29, 42), Vector2(-23, 48), Color("302b24"), 1.4)
	draw_string(font, Vector2(-17, 51), str(power), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("302b24"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 42), Vector2(13, 39), Vector2(17, 42), Vector2(21, 39), Vector2(24, 42), Vector2(17, 50)]), Color("803c2c"))
	draw_string(font, Vector2(25, 51), str(health if display_health < 0 else display_health), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("803c2c"))

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	return box


func _draw_sigil(id: String, at: Vector2) -> void:
	var flash: float = sigil_flashes.get(id, 0.0)
	var time := 0.0 if reduced_motion else idle_time + idle_phase
	var pulse := 0.0 if reduced_motion else (sin(time * 1.7) + 1.0) * 0.12
	draw_circle(at, 8.8, Color(0.82, 0.43, 0.14, pulse + flash * 0.35))
	draw_circle(at, 7, Color("e5d7b6").lerp(Color("f4c77c"), flash * 0.6))
	if not reduced_motion:
		draw_arc(at, 8.5 + flash * 3, time * 0.8, time * 0.8 + 1.1, 12, Color(0.88, 0.62, 0.28, 0.28 + flash * 0.6), 0.8)
	draw_arc(at, 7, 0, TAU, 20, Color("504330"), 0.8)
	var ink := Color("302b24")
	match id:
		"worthy_sacrifice":
			for x in [-3, 0, 3]:
				var tip := at + Vector2(x, -4)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-1.4, 5), tip + Vector2(1.4, 5)]), Color("873b29"))
		"many_lives":
			draw_arc(at, 4.5, 0.4 + sin(time) * 0.1, TAU - 0.4, 24, ink, 1.2)
			draw_line(at + Vector2(3, -4), at + Vector2(5, -5), ink, 1.2)
			draw_circle(at, 1.4, ink)
		"unkillable":
			for side in [-1, 1]:
				draw_arc(at + Vector2(side * 2.5, 0), 2.9, 0, TAU, 18, ink, 1.1)
		"bone_king":
			draw_polyline(PackedVector2Array([at + Vector2(-5, -3), at + Vector2(-3, 1), at + Vector2(0, -4), at + Vector2(3, 1), at + Vector2(5, -3), at + Vector2(4, 4), at + Vector2(-4, 4), at + Vector2(-5, -3)]), ink, 1.2)
		"airborne":
			draw_line(at + Vector2(-5, -3), at + Vector2(0, 4), ink, 1.4)
			draw_line(at + Vector2(5, -3), at + Vector2(0, 4), ink, 1.4)
			draw_line(at + Vector2(-5, -3), at + Vector2(-1, -1), ink, 1)
			draw_line(at + Vector2(5, -3), at + Vector2(1, -1), ink, 1)
		"mighty_leap":
			draw_polyline(PackedVector2Array([at + Vector2(-4, -4), at + Vector2(4, -4), at + Vector2(4, 1), at + Vector2(0, 5), at + Vector2(-4, 1), at + Vector2(-4, -4)]), ink, 1.3)
		"waterborne":
			for y in [-2, 2]:
				draw_polyline(PackedVector2Array([at + Vector2(-5, y), at + Vector2(-2, y - 1), at + Vector2(2, y + 1), at + Vector2(5, y)]), ink, 1.2)
		"stinky":
			for x in [-3, 2]:
				draw_polyline(PackedVector2Array([at + Vector2(x, 5), at + Vector2(x - 1, 1), at + Vector2(x + 1, -2), at + Vector2(x, -5)]), ink, 1.2)
		"sharp_quills":
			for x in [-4, 0, 4]:
				draw_line(at + Vector2(x, 4), at + Vector2(x, -4), ink, 1.3)
				draw_line(at + Vector2(x, -4), at + Vector2(x - 2, -1), ink, 1)
		"touch_of_death":
			draw_circle(at + Vector2(0, -1), 4, ink)
			draw_circle(at + Vector2(-1.5, -1), 1, Color("e5d7b6"))
			draw_circle(at + Vector2(1.5, -1), 1, Color("e5d7b6"))
			draw_rect(Rect2(at + Vector2(-2, 2), Vector2(4, 3)), ink)
