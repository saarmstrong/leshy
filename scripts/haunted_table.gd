extends Node2D
## Header/edge-only living scenery. Does not move controls or obscure card stats.
var reduced := false
var elapsed := 0.0
var reaction := 0.0
var mood := "idle"
var round_number := 1
var tooth_arrival := 1.0
var skull_form := 0
func set_round(value: int) -> void:
	var next := maxi(1, value)
	if next != round_number:
		tooth_arrival = 0.0
	round_number = next
	skull_form = (round_number - 1) % 3
	queue_redraw()
func tooth_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(round_number):
		# Additional rows become ghost jaws once the first eight teeth fill.
		points.append(Vector2(345 + (i % 8) * 4, 139 + (i % 8) * -0.65 + (i / 8) * 6))
	return points
func react(kind: String) -> void:
	mood = kind
	reaction = 1.0
func _process(delta: float) -> void:
	elapsed += delta
	tooth_arrival = minf(1, tooth_arrival + delta * 1.8)
	reaction = maxf(0, reaction - delta * 0.45)
	queue_redraw()
func _glow(point: Vector2, radius: float, color: Color) -> void:
	for ring in range(9, 0, -1):
		var tint := color
		tint.a *= 0.05 * (1.0 - ring / 11.0)
		draw_circle(point, radius * ring / 9.0, tint)
func _draw() -> void:
	var breathing := 0.32 if reduced else 0.45 + sin(elapsed * 0.7) * 0.18
	var heat := 0.0 if reduced else reaction * 0.4
	var eye := Color(0.95, 0.48 if mood != "death" else 0.16, 0.1, breathing + heat)
	# Smooth, irregular glimmer, with a rare candle-bright pinpoint.
	var glimmer := 0.0 if reduced else pow(maxf(0, sin(elapsed * 0.83) * cos(elapsed * 0.27)), 8)
	eye.a = minf(1, eye.a + glimmer * 0.45)
	for point in [Vector2(183, 58), Vector2(203, 58)]:
		_glow(point, 12 + heat * 6, eye)
		draw_circle(point, 2.3, eye)
		draw_line(point + Vector2(0, -1.7), point + Vector2(0, 1.7), Color(1, 0.82, 0.42, breathing), 1)
		if not reduced:
			draw_line(point + Vector2(-4, 0), point + Vector2(4, 0), Color(1, 0.88, 0.6, glimmer * 0.7), 0.7)
	_draw_round_skull()
	for point in [Vector2(48, 34), Vector2(14, 64)]:
		var sway := 0.0 if reduced else sin(elapsed * 2.2 + point.x) * 1.1
		_glow(point, 28, Color(0.95, 0.53, 0.15, 0.5 if reduced else 0.52 + sin(elapsed * 1.9) * 0.1))
		if not reduced:
			draw_colored_polygon(PackedVector2Array([point + Vector2(-2, 2), point + Vector2(sway, -7), point + Vector2(2, 2)]), Color(1, 0.69, 0.26, 0.55))
	if reduced:
		return
	# Candle smoke coils upward, kept in the header.
	for candle in [Vector2(48, 34), Vector2(14, 64)]:
		var previous: Vector2 = candle + Vector2(0, -8)
		for i in range(1, 15):
			var point: Vector2 = candle + Vector2(sin(i * 0.43 + elapsed * 0.7) * i * 0.65, -8 - i * 3)
			draw_line(previous, point, Color(0.48, 0.43, 0.33, 0.12 * (1 - i / 16.0)), 1)
			previous = point
	# Dust and embers drift only along the margins and above the play field.
	for i in range(18):
		var phase := fmod(elapsed * 0.035 + i * 0.137, 1.0)
		var x: float = (5 + i % 3 * 3) if i % 2 else (379 + i % 3 * 3)
		var y := 750 - phase * 650
		draw_circle(Vector2(x + sin(elapsed + i) * 2, y), 0.8, Color(0.9, 0.54, 0.19, sin(phase * PI) * 0.33))
	# A small moth circles the upper candle, with asynchronous wingbeats.
	var moth := Vector2(78 + sin(elapsed * 0.55) * 24, 48 + cos(elapsed * 0.7) * 20)
	var wing := 2 + absf(sin(elapsed * 7.0)) * 3
	draw_colored_polygon(PackedVector2Array([moth, moth + Vector2(-wing, -3), moth + Vector2(-wing, 3)]), Color(0.1, 0.11, 0.08, 0.8))
	draw_colored_polygon(PackedVector2Array([moth, moth + Vector2(wing, -3), moth + Vector2(wing, 3)]), Color(0.1, 0.11, 0.08, 0.8))
	# Every so often, something with too many legs crawls along the edge.
	var crawl := fmod(elapsed + 4.0, 23.0)
	if crawl < 4.0:
		var body := Vector2(6, 300 + crawl * 65)
		draw_line(body, body + Vector2(0, 16), Color(0.025, 0.03, 0.02, 0.9), 3)
		for i in range(5):
			var step := sin(elapsed * 9 + i) * 2
			for side in [-1, 1]:
				draw_line(body + Vector2(0, i * 3), body + Vector2(side * 5, i * 3 + step), Color(0.03, 0.035, 0.02, 0.9), 1)

func _draw_round_skull() -> void:
	# Haunt the existing painted skull rather than covering it with a HUD badge.
	var pulse := 0.7 if reduced else 0.64 + sin(elapsed * 1.1) * 0.18
	var colors := [Color("bd622d"), Color("87a58d"), Color("bc4d39")]
	var tint: Color = colors[skull_form]
	tint.a = pulse
	match skull_form:
		0: # A candle stares from the hollow socket.
			_glow(Vector2(369, 106), 13, tint)
			draw_circle(Vector2(369, 106), 1.6, tint)
		1: # Three watching pinpoints open inside the same socket.
			for point in [Vector2(365, 104), Vector2(373, 103), Vector2(370, 111)]:
				_glow(point, 7, tint)
				draw_circle(point, 1.1, tint)
		2: # A red slit and spidery tears creep down the cheek.
			_glow(Vector2(370, 107), 14, tint)
			draw_line(Vector2(370, 101), Vector2(369, 112), tint, 1.2)
			for i in range(3):
				draw_polyline(PackedVector2Array([Vector2(366 + i * 4, 114), Vector2(364 + i * 4, 120), Vector2(366 + i * 3, 127)]), Color(0.3, 0.07, 0.035, pulse), 1)
	# One luminous fang per round, including round one. Never wrap the count.
	var teeth := tooth_positions()
	for i in range(teeth.size()):
		var point := teeth[i]
		var arrival := 1.0 if reduced or i < teeth.size() - 1 else tooth_arrival
		var bone := Color("dfb77c")
		bone.a = arrival * 0.88
		_glow(point + Vector2(0, 2), 4, Color(tint, arrival * 0.25))
		draw_colored_polygon(PackedVector2Array([point + Vector2(-1.4, -1), point + Vector2(1.4, -1), point + Vector2(0.6, 4.5 * arrival), point + Vector2(-0.6, 5.5 * arrival)]), bone)
