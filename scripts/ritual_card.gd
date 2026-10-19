extends Node2D
class_name RitualCard

var animal := "FOX"
var health := 3
var power := 2
var font: Font = preload("res://assets/fonts/NotoSerif-Regular.ttf")
var artwork: Texture2D
var card_back := false
var cost := 0
var selected := false
var marked := false

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
	draw_string(font, Vector2(-35, -45), animal, HORIZONTAL_ALIGNMENT_CENTER, 70, 9, Color("302b24"))
	for i in range(cost):
		draw_circle(Vector2(-5 + i * 8, -32), 2.2, Color("803c2c"))
	if marked:
		draw_line(Vector2(-22, -23), Vector2(22, 24), Color("903d2c"), 2)
		draw_line(Vector2(22, -23), Vector2(-22, 24), Color("903d2c"), 2)
	# Stats remain live and separate from generated card artwork.
	draw_line(Vector2(-30, 34), Vector2(30, 34), Color("8a7048"), 0.7)
	draw_line(Vector2(-29, 49), Vector2(-20, 39), Color("302b24"), 1.4)
	draw_line(Vector2(-29, 42), Vector2(-23, 48), Color("302b24"), 1.4)
	draw_string(font, Vector2(-17, 51), str(power), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("302b24"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 42), Vector2(13, 39), Vector2(17, 42), Vector2(21, 39), Vector2(24, 42), Vector2(17, 50)]), Color("803c2c"))
	draw_string(font, Vector2(25, 51), str(health), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("803c2c"))

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	return box
