extends Node2D
## Engraved tools with candlelit glints; no external icon dependency.
var item := "pliers"
var reduced := false
var time := 0.0
func _process(delta: float) -> void:
	if not reduced:
		time += delta
	queue_redraw()
func _draw() -> void:
	var ink := Color("d5b077")
	var shade := Color("524330")
	draw_circle(Vector2.ZERO, 23, Color("242219"))
	draw_arc(Vector2.ZERO, 23, 0, TAU, 40, shade, 1)
	match item:
		"squirrel_bottle":
			draw_rect(Rect2(-6, -17, 12, 5), ink, false, 1.5)
			draw_polyline(PackedVector2Array([Vector2(-4, -12), Vector2(-4, -6), Vector2(-11, 0), Vector2(-11, 15), Vector2(11, 15), Vector2(11, 0), Vector2(4, -6), Vector2(4, -12)]), ink, 1.4)
			draw_arc(Vector2(1, 5), 5, -1, 4, 18, ink, 1.5)
			draw_circle(Vector2(-4, 4), 2.5, ink)
		"pliers", "scissors":
			for side in [-1, 1]:
				draw_line(Vector2(side * 9, 15), Vector2(-side * 6, -12), ink, 2)
				if item == "scissors":
					draw_arc(Vector2(side * 8, 12), 4, 0, TAU, 18, ink, 1.5)
				else:
					draw_line(Vector2(-side * 6, -12), Vector2(-side * 2, -9), ink, 2)
			draw_circle(Vector2.ZERO, 2.2, shade)
		"hourglass":
			for y in [-16, 16]:
				draw_line(Vector2(-11, y), Vector2(11, y), ink, 2)
			draw_polyline(PackedVector2Array([Vector2(-8, -14), Vector2(8, 14), Vector2(-8, 14), Vector2(8, -14), Vector2(-8, -14)]), ink, 1.3)
			draw_line(Vector2.ZERO, Vector2(0, 9), ink, 0.8)
		"fan":
			for angle in [-0.9, -0.45, 0.0, 0.45, 0.9]:
				var tip := Vector2(sin(angle) * 19, 9 - cos(angle) * 27)
				draw_line(Vector2(0, 9), tip, ink, 1.3)
				draw_circle(tip, 1.5, ink)
			draw_line(Vector2(0, 9), Vector2(0, 18), ink, 2)
		"fish_hook":
			draw_line(Vector2(5, -18), Vector2(5, 5), ink, 1.6)
			draw_arc(Vector2(-2, 5), 7, 0, PI, 20, ink, 1.6)
			draw_line(Vector2(-9, 5), Vector2(-9, -2), ink, 1.6)
			draw_line(Vector2(-9, -2), Vector2(-5, 1), ink, 1.6)
	if not reduced:
		var glint := pow(maxf(0, sin(time * 1.3)), 8) * 0.7
		draw_line(Vector2(11, -13), Vector2(17, -13), Color(1, 0.79, 0.44, glint), 1)
		draw_line(Vector2(14, -16), Vector2(14, -10), Color(1, 0.79, 0.44, glint), 1)
