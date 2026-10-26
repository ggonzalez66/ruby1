extends Node2D

# Flores y aves del claro. Solo esta capa pequeña redibuja; el bosque permanece estático.
var clock := 0.0
var redraw_left := 0.0

func _ready() -> void:
	z_index = 2

func _process(delta: float) -> void:
	clock += delta
	redraw_left -= delta
	if redraw_left <= 0:
		redraw_left = 0.05
		queue_redraw()

func _draw() -> void:
	for x in [2210.0, 2520.0, 3510.0, 3940.0, 4220.0]:
		var p := Vector2(x, 96 + sin(clock * 0.9 + x) * 1.2)
		_ellipse(p, Vector2(24, 3), Color(0.08, 0.45, 0.35, 0.2))
		_ellipse(p - Vector2(0, 2), Vector2(17, 4), Color("447e51"))
		_ellipse(p + Vector2(16, -1), Vector2(11, 3), Color("709b5a"))
		var center := p - Vector2(0, 6)
		for petal in range(5):
			var angle := petal * TAU / 5.0
			_ellipse(center + Vector2(cos(angle) * 4, sin(angle) * 2), Vector2(4, 2.5), Color("f4debf"))
		draw_circle(center, 2, Color("f3c969"))
	for index in range(7):
		var p := Vector2(1700 + fmod(clock * 32 + index * 390, 2800), -560 + sin(clock * 0.4 + index) * 35 - index * 32)
		var flap := sin(clock * 5 + index) * 4
		draw_polyline(PackedVector2Array([p + Vector2(-9, -3 - flap), p + Vector2(-4, -2), p, p + Vector2(4, -2), p + Vector2(9, -3 - flap)]), Color(0.9, 0.93, 0.72, 0.7), 1.6, true)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := index * TAU / 16.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
