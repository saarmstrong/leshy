extends Node2D
## Quiet ember ornament around the live transition text; no flashing.
var strength := 0.0
var elapsed := 0.0
var reduced := false
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	if strength <= 0:
		return
	var amber := Color(0.78, 0.51, 0.24, strength * 0.8)
	var span := 143.0 * strength
	for y in [352.0, 477.0]:
		draw_line(Vector2(195 - span, y), Vector2(195 + span, y), amber, 1)
		draw_colored_polygon(PackedVector2Array([Vector2(191, y), Vector2(195, y - 4), Vector2(199, y), Vector2(195, y + 4)]), amber)
	if reduced:
		return
	for i in range(18):
		var phase := fmod(elapsed * 0.16 + i * 0.137, 1.0)
		var side := -1 if i % 2 else 1
		var x := 195 + side * (130 + sin(elapsed * 0.5 + i) * 19)
		var y := 492 - phase * 160
		var alpha := sin(phase * PI) * strength * 0.55
		draw_circle(Vector2(x, y), 0.7 + (i % 3) * 0.3, Color(0.86, 0.5, 0.18, alpha))
