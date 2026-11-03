@tool
extends Node2D

# Decorado de las fábricas de la run (no colisiona). "outdoor": la fachada de la fábrica con ventanas,
# chimeneas humeantes, un cartel y la reja de entrada; "indoor": el interior (muros de chapa, pilares,
# tuberías, lámparas) tapando todo el fondo; "hall": la sala del guardián, más alta y con una gran
# ventana; "tower": la cima de la Torre de cristal (agujas de rubí a los lados y el resplandor del sol).
# Es @tool para verlo en el editor.

@export_enum("outdoor", "indoor", "hall", "tower") var mode := "outdoor"
# Fachada (outdoor) o interior (indoor/hall) en coordenadas del nivel.
@export var area := Rect2(2600, -1000, 2000, 1000)
@export var fence_from := 900.0
@export var fence_to := 2300.0
@export var fence_height := 260.0
@export var sign_text := "FÁBRICA"

const WALL := Color(0.25, 0.27, 0.3)
const WALL_DARK := Color(0.15, 0.16, 0.19)
const WALL_LIGHT := Color(0.36, 0.38, 0.42)
const WINDOW := Color(0.95, 0.75, 0.35, 0.75)
const WINDOW_DARK := Color(0.08, 0.1, 0.12)
const PIPE := Color(0.42, 0.33, 0.24)
const RUST := Color(0.5, 0.26, 0.14)
const HAZARD := Color(0.95, 0.72, 0.12)
const FENCE := Color(0.55, 0.6, 0.62, 0.75)
const SMOKE := Color(0.55, 0.55, 0.58, 0.35)

var smoke: Array = []

func _ready() -> void:
	z_index = -6
	if Engine.is_editor_hint() or mode != "outdoor":
		return
	for chimney_x in _chimneys():
		var puff := CPUParticles2D.new()
		puff.position = Vector2(chimney_x, area.position.y - 260.0)
		puff.amount = 18
		puff.lifetime = 4.0
		puff.preprocess = 4.0
		puff.direction = Vector2(0.35, -1)
		puff.spread = 18
		puff.gravity = Vector2(14, -6)
		puff.initial_velocity_min = 30
		puff.initial_velocity_max = 55
		puff.scale_amount_min = 10
		puff.scale_amount_max = 22
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(SMOKE, 0.45), Color(SMOKE, 0.0)])
		puff.color_ramp = fade
		add_child(puff)

func _chimneys() -> Array:
	return [area.position.x + area.size.x * 0.22, area.position.x + area.size.x * 0.68]

func _draw() -> void:
	match mode:
		"outdoor":
			_draw_facade()
			_draw_fence()
		"tower":
			_draw_tower_top()
		_:
			_draw_interior(mode == "hall")

# ---------- Afueras

func _draw_facade() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	# Chimeneas detrás del tejado.
	for x in _chimneys():
		draw_rect(Rect2(x - 45, top - 260, 90, 260), WALL_DARK)
		draw_rect(Rect2(x - 55, top - 270, 110, 22), WALL_LIGHT)
		for band in range(3):
			draw_rect(Rect2(x - 45, top - 220 + band * 70, 90, 10), RUST)
	# Cuerpo del edificio con degradado y tejado en dientes de sierra.
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, 0), Vector2(left, 0)]),
		PackedColorArray([WALL_LIGHT, WALL_LIGHT, WALL_DARK, WALL_DARK]))
	var teeth := 6
	var tooth := area.size.x / teeth
	for index in range(teeth):
		var x0 := left + index * tooth
		draw_colored_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x0 + tooth, top), Vector2(x0 + tooth, top - 90)]), WALL)
		draw_line(Vector2(x0 + tooth, top), Vector2(x0 + tooth, top - 90), WALL_DARK, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + tooth * 0.55, top - 8), Vector2(x0 + tooth - 6, top - 8), Vector2(x0 + tooth - 6, top - 74)]), Color(WINDOW, 0.35))
	# Hileras de ventanas (algunas apagadas).
	var rows := int((area.size.y - 320.0) / 150.0)
	for row in range(rows):
		var y := top + 70.0 + row * 150.0
		var x := left + 70.0
		while x < right - 130.0:
			var lit := rng.randf() < 0.6
			draw_rect(Rect2(x, y, 90, 80), WINDOW if lit else WINDOW_DARK)
			draw_rect(Rect2(x, y, 90, 80), WALL_DARK, false, 4.0)
			draw_line(Vector2(x + 45, y), Vector2(x + 45, y + 80), WALL_DARK, 3.0)
			draw_line(Vector2(x, y + 40), Vector2(x + 90, y + 40), WALL_DARK, 3.0)
			x += 160.0
	# Tuberías por la fachada.
	for x in [left + 30.0, right - 50.0]:
		draw_rect(Rect2(x, top + 20, 18, -top - 20), PIPE)
		for y in range(int(top + 60), 0, 180):
			draw_rect(Rect2(x - 4, y, 26, 10), RUST)
	# Zócalo con franjas de peligro.
	var y0 := -60.0
	draw_rect(Rect2(left, y0, area.size.x, 60), WALL_DARK)
	var stripe_x := left
	while stripe_x < right:
		draw_colored_polygon(PackedVector2Array([Vector2(stripe_x, y0), Vector2(stripe_x + 24, y0), Vector2(stripe_x + 44, y0 + 14), Vector2(stripe_x + 20, y0 + 14)]), HAZARD)
		stripe_x += 48.0
	# Cartel.
	var sign_center := Vector2((left + right) * 0.5, top + 36.0)
	draw_rect(Rect2(sign_center.x - 190, sign_center.y - 34, 380, 64), Color(0.12, 0.05, 0.05))
	draw_rect(Rect2(sign_center.x - 190, sign_center.y - 34, 380, 64), Color(0.9, 0.2, 0.15), false, 4.0)
	var font := ThemeDB.fallback_font
	draw_string(font, sign_center + Vector2(-180, 14), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 360, 40, Color(1.0, 0.45, 0.3))

func _draw_fence() -> void:
	# Reja de alambre entre postes, como la del boceto, con alambre de púas arriba.
	var top := -fence_height
	draw_rect(Rect2(fence_from, top, fence_to - fence_from, fence_height), Color(FENCE, 0.12))
	# Malla en cuadrícula, como en el boceto.
	var x := fence_from
	while x <= fence_to:
		draw_line(Vector2(x, top), Vector2(x, 0), Color(FENCE, 0.45), 1.5)
		x += 34.0
	var y := top
	while y < 0.0:
		draw_line(Vector2(fence_from, y), Vector2(fence_to, y), Color(FENCE, 0.45), 1.5)
		y += 34.0
	x = fence_from
	while x <= fence_to + 1.0:
		draw_rect(Rect2(x - 5, top - 30, 10, fence_height + 30), Color(0.32, 0.35, 0.38))
		x += 280.0
	draw_line(Vector2(fence_from, top), Vector2(fence_to, top), Color(0.4, 0.43, 0.46), 4.0)
	var wire := PackedVector2Array()
	x = fence_from
	var up := true
	while x <= fence_to:
		wire.append(Vector2(x, top - 20 + (6.0 if up else -6.0)))
		up = not up
		x += 14.0
	draw_polyline(wire, Color(0.6, 0.62, 0.64), 2.0)

# ---------- Cima de la Torre

func _draw_tower_top() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	var bottom := area.end.y
	# Cielo del atardecer sobre las nubes: la Torre está por encima de la jungla.
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([Color(0.2, 0.1, 0.22), Color(0.2, 0.1, 0.22), Color(0.95, 0.6, 0.3), Color(0.95, 0.6, 0.3)]))
	# Resplandor del sol arriba, en el centro.
	var sun := Vector2((left + right) * 0.5, top + 160.0)
	for ring in range(6):
		draw_circle(sun, 560.0 - ring * 85.0, Color(1.0, 0.82, 0.4, 0.06 + ring * 0.02))
	draw_circle(sun, 90.0, Color(1.0, 0.95, 0.75, 0.8))
	# Mar de nubes bajo la cima.
	for index in range(18):
		var cloud := Vector2(left + index * area.size.x / 17.0 + rng.randf_range(-60, 60), rng.randf_range(-260, -60))
		draw_circle(cloud, rng.randf_range(90, 170), Color(1.0, 0.85, 0.75, 0.22))
	# Agujas de cristal de rubí en los bordes y fragmentos flotando al fondo.
	for side in [0, 1]:
		for index in range(4):
			var base_x: float = (left + 200.0 + index * 140.0) if side == 0 else (right - 200.0 - index * 140.0)
			var height: float = 1400.0 - index * 260.0 + rng.randf_range(-80, 80)
			var half: float = 90.0 - index * 12.0
			var spire := PackedVector2Array([Vector2(base_x - half, 0), Vector2(base_x - half * 0.8, -height * 0.8),
				Vector2(base_x, -height), Vector2(base_x + half * 0.8, -height * 0.8), Vector2(base_x + half, 0)])
			draw_colored_polygon(spire, Color(0.62, 0.06, 0.16).darkened(index * 0.12))
			draw_colored_polygon(PackedVector2Array([Vector2(base_x - half * 0.8, -height * 0.8), Vector2(base_x, -height), Vector2(base_x, 0), Vector2(base_x - half, 0)]),
				Color(0.85, 0.2, 0.3, 0.55).darkened(index * 0.12))
			draw_line(Vector2(base_x, -height), Vector2(base_x, 0), Color(1.0, 0.6, 0.65, 0.6), 3.0)
	for index in range(14):
		var at := Vector2(rng.randf_range(left + 600, right - 600), rng.randf_range(top + 300, -300))
		var size := rng.randf_range(14, 34)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size * 1.6), at + Vector2(size * 0.6, 0), at + Vector2(0, size * 1.2), at + Vector2(-size * 0.6, 0)]),
			Color(0.95, 0.25, 0.35, 0.7))

# ---------- Interior

func _draw_interior(hall: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 733 if hall else 5150
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	var bottom := area.end.y
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([WALL_DARK.darkened(0.3), WALL_DARK.darkened(0.3), WALL_DARK, WALL_DARK]))
	# Paneles de chapa.
	var x := left
	while x < right:
		draw_line(Vector2(x, top), Vector2(x, bottom), WALL_DARK.darkened(0.35), 3.0)
		x += 120.0
	var y := top
	while y < bottom:
		draw_line(Vector2(left, y), Vector2(right, y), WALL_DARK.darkened(0.25), 2.0)
		y += 90.0
	if hall:
		# Ventanal del fondo: se ve el cielo y la luz entra en haces.
		var window := Rect2(left + area.size.x * 0.25, top + 120.0, area.size.x * 0.5, area.size.y * 0.45)
		draw_rect(window, Color(0.45, 0.62, 0.6))
		var bars := 8
		for index in range(1, bars):
			var bx := window.position.x + window.size.x * index / bars
			draw_line(Vector2(bx, window.position.y), Vector2(bx, window.end.y), WALL_DARK, 6.0)
		draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y), WALL_DARK, 6.0)
		draw_rect(window, WALL_DARK, false, 10.0)
		for index in range(4):
			var bx := window.position.x + window.size.x * (0.15 + index * 0.22)
			draw_colored_polygon(PackedVector2Array([Vector2(bx, window.end.y), Vector2(bx + 70, window.end.y), Vector2(bx + 260, bottom), Vector2(bx + 120, bottom)]), Color(1.0, 0.92, 0.7, 0.05))
	# Pilares con remaches.
	x = left + 300.0
	while x < right - 100.0:
		draw_rect(Rect2(x - 26, top, 52, bottom - top), WALL.darkened(0.15))
		draw_rect(Rect2(x - 26, top, 8, bottom - top), WALL_LIGHT.darkened(0.2))
		var rivet := top + 30.0
		while rivet < bottom:
			draw_circle(Vector2(x, rivet), 3.0, WALL_LIGHT)
			rivet += 60.0
		x += 700.0
	# Tuberías horizontales y verticales.
	for index in range(3):
		var pipe_y := top + 80.0 + index * (bottom - top - 160.0) / 2.0 + rng.randf_range(-30, 30)
		draw_rect(Rect2(left, pipe_y, area.size.x, 16), PIPE.darkened(0.25))
		var joint := left + rng.randf_range(80, 200)
		while joint < right:
			draw_rect(Rect2(joint, pipe_y - 4, 14, 24), RUST.darkened(0.2))
			joint += rng.randf_range(220, 420)
	# Lámparas colgantes con su cono de luz.
	x = left + 250.0
	while x < right:
		for lamp_y in _lamp_rows(top, bottom, hall):
			draw_line(Vector2(x, lamp_y - 60), Vector2(x, lamp_y), Color(0.1, 0.1, 0.12), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 22, lamp_y + 10), Vector2(x - 12, lamp_y), Vector2(x + 12, lamp_y), Vector2(x + 22, lamp_y + 10)]), Color(0.2, 0.22, 0.24))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 20, lamp_y + 10), Vector2(x + 20, lamp_y + 10), Vector2(x + 150, lamp_y + 330), Vector2(x - 150, lamp_y + 330)]), Color(1.0, 0.85, 0.5, 0.05))
			draw_circle(Vector2(x, lamp_y + 10), 6.0, Color(1.0, 0.9, 0.6))
		x += 560.0

func _lamp_rows(top: float, bottom: float, hall: bool) -> Array:
	if hall:
		return [top + 90.0]
	# Una fila de lámparas bajo cada techo (pisos de 440 px).
	var rows := []
	var y := bottom - 440.0 + 70.0
	while y > top:
		rows.append(y)
		y -= 440.0
	return rows
