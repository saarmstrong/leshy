extends Node2D
## Small card-back stack drawn inside its thumb-sized draw button.
var remaining := 0
var squirrel_pile := false
var available := false

func _draw() -> void:
	var edge := Color("c68a43") if available else Color("655b48")
	for i in range(3 if remaining > 0 else 1):
		var rect := Rect2(i * 2, i * 2, 18, 27)
		draw_rect(rect, Color("24251d"))
		draw_rect(rect, edge, false, 1)
	if remaining <= 0:
		draw_line(Vector2(4, 5), Vector2(14, 22), edge, 1)
	elif squirrel_pile:
		# An acorn distinguishes the resource pile from the creature deck.
		draw_circle(Vector2(13, 19), 4, edge)
		draw_line(Vector2(8, 15), Vector2(18, 15), edge, 2)
		draw_line(Vector2(13, 15), Vector2(15, 11), edge, 1)
	else:
		draw_line(Vector2(13, 10), Vector2(13, 26), edge, 1)
		for y in [12, 17, 22]:
			draw_line(Vector2(13, y + 3), Vector2(8, y), edge, 1)
			draw_line(Vector2(13, y + 3), Vector2(18, y), edge, 1)
