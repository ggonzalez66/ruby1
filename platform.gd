@tool
extends StaticBody2D

# Bloque del escenario: crea su colisión y se dibuja solo según su tamaño y estilo
# (tierra con musgo, losa de piso, plataforma, muro de ladrillo, muro trepable con enredaderas o chapa
# de acero de las fábricas de la run).
# Es @tool para que también se vea en el editor.

enum Style { GROUND, SLAB, PLATFORM, WALL, CLIMB_WALL, METAL, SUN }

@export var size := Vector2(200, 40):
	set(value):
		size = value
		_rebuild()
# Sin los bordes laterales oscuros (tramos de suelo que se empalman, como el del menú principal).
@export var side_borders := true
@export var style := Style.GROUND:
	set(value):
		style = value
		_rebuild()

const MOSS := Color(0.29, 0.47, 0.22)
const MOSS_LIGHT := Color(0.45, 0.66, 0.3)
const VINE := Color(0.24, 0.42, 0.2)
const PALETTES := {
	Style.GROUND: [Color(0.45, 0.28, 0.18), Color(0.22, 0.13, 0.09)],
	Style.SLAB: [Color(0.33, 0.27, 0.24), Color(0.17, 0.13, 0.12)],
	Style.PLATFORM: [Color(0.5, 0.33, 0.2), Color(0.32, 0.2, 0.12)],
	Style.WALL: [Color(0.38, 0.32, 0.29), Color(0.22, 0.18, 0.17)],
	Style.CLIMB_WALL: [Color(0.3, 0.36, 0.27), Color(0.17, 0.21, 0.15)],
	Style.METAL: [Color(0.36, 0.39, 0.42), Color(0.17, 0.19, 0.22)],
	Style.SUN: [Color(1.0, 0.68, 0.26), Color(0.74, 0.3, 0.08)],
}
const SUN_CREST := Color(1.0, 0.96, 0.75)
const SUN_GLYPH := Color(1.0, 0.86, 0.5, 0.55)
const HAZARD_YELLOW := Color(0.95, 0.72, 0.12)
const HAZARD_DARK := Color(0.1, 0.09, 0.08)

var collision: CollisionShape2D

func _ready() -> void:
	collision_layer = 2
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if collision == null:
		collision = CollisionShape2D.new()
		add_child(collision)
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y * 13.0 + size.x)
	var palette: Array = PALETTES[style]
	# Cuerpo con degradado vertical.
	draw_polygon(PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]),
		PackedColorArray([palette[0], palette[0], palette[1], palette[1]]))
	if style == Style.METAL:
		_draw_metal(half, palette)
		return
	if style == Style.SUN:
		_draw_sun(half, palette, rng)
		return
	match style:
		Style.WALL:
			_draw_bricks(half, palette[1].darkened(0.25), rng)
		Style.CLIMB_WALL:
			_draw_bricks(half, palette[1].darkened(0.25), rng)
			_draw_vines(half, rng)
		Style.SLAB:
			_draw_strata(half, palette[1].darkened(0.2), rng)
			draw_rect(Rect2(-half.x, half.y - 6, size.x, 6), palette[1].darkened(0.35))
		Style.GROUND:
			_draw_strata(half, palette[1].darkened(0.15), rng)
	# Bordes laterales oscuros.
	if side_borders:
		draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), palette[1].darkened(0.4), 2.0)
		draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), palette[1].darkened(0.4), 2.0)
	# Musgo y hierba arriba (en los muros solo un remate).
	var moss_depth: float = 4.0 if style in [Style.WALL, Style.CLIMB_WALL] else min(9.0, size.y * 0.45)
	_draw_moss_top(half, moss_depth, rng, style not in [Style.WALL, Style.CLIMB_WALL])

func _draw_sun(half: Vector2, palette: Array, rng: RandomNumberGenerator) -> void:
	# Piedra solar del mundo espiritual: vetas claras, glifos y un borde superior incandescente.
	for index in range(int(size.x * size.y / 9000.0) + 1):
		var y := rng.randf_range(-half.y + 10.0, half.y - 6.0)
		var x := rng.randf_range(-half.x + 6.0, half.x - 40.0)
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(16.0, 40.0), y + rng.randf_range(-3.0, 3.0)), palette[1].lightened(0.25), 2.0)
	for index in range(int(size.x / 160.0)):
		var c := Vector2(-half.x + (index + 0.5) * size.x / int(size.x / 160.0), clampf(0.0, -half.y + 14.0, half.y - 14.0))
		if size.y >= 40.0:
			draw_arc(c, 7.0, 0.0, TAU, 10, SUN_GLYPH, 1.5)
			draw_line(c + Vector2(-11, 0), c + Vector2(11, 0), SUN_GLYPH, 1.0)
	draw_rect(Rect2(-half.x, -half.y, size.x, 4.0), SUN_CREST)
	draw_rect(Rect2(-half.x, -half.y + 4.0, size.x, 3.0), palette[0].lightened(0.3))
	if side_borders:
		draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), palette[1].darkened(0.2), 2.0)
		draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), palette[1].darkened(0.2), 2.0)

func _draw_metal(half: Vector2, palette: Array) -> void:
	# Planchas remachadas con juntas y, arriba, una franja de peligro amarilla y negra.
	var seam: Color = palette[1].darkened(0.3)
	var plate := 96.0
	var x := -half.x + plate
	while x < half.x - 8.0:
		draw_line(Vector2(x, -half.y + 8.0), Vector2(x, half.y), seam, 2.0)
		x += plate
	var y := -half.y + 8.0 + 48.0
	while y < half.y - 6.0:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), seam, 1.5)
		y += 48.0
	x = -half.x + 10.0
	while x < half.x - 4.0:
		for rivet_y in [-half.y + 16.0, half.y - 8.0]:
			if rivet_y > -half.y + 10.0 and rivet_y < half.y:
				draw_circle(Vector2(x, rivet_y), 2.2, palette[0].lightened(0.25))
		x += 32.0
	var stripe := minf(8.0, size.y * 0.4)
	draw_rect(Rect2(-half.x, -half.y, size.x, stripe), HAZARD_YELLOW)
	x = -half.x
	while x < half.x:
		var a := maxf(x, -half.x)
		var b := minf(x + 9.0, half.x)
		draw_colored_polygon(PackedVector2Array([Vector2(a, -half.y + stripe), Vector2(minf(a + stripe, half.x), -half.y), Vector2(minf(b + stripe, half.x), -half.y), Vector2(b, -half.y + stripe)]), HAZARD_DARK)
		x += 18.0
	draw_line(Vector2(-half.x, -half.y + stripe), Vector2(half.x, -half.y + stripe), palette[1].darkened(0.4), 1.5)
	if side_borders:
		draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), palette[1].darkened(0.4), 2.0)
		draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), palette[1].darkened(0.4), 2.0)

func _draw_moss_top(half: Vector2, depth: float, rng: RandomNumberGenerator, with_grass: bool) -> void:
	var points := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y)])
	var x := half.x
	while x > -half.x:
		points.append(Vector2(x, -half.y + depth * rng.randf_range(0.6, 1.3)))
		x -= rng.randf_range(10.0, 22.0)
	points.append(Vector2(-half.x, -half.y + depth))
	draw_colored_polygon(points, MOSS)
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), MOSS_LIGHT, 2.0)
	if not with_grass:
		return
	x = -half.x + rng.randf_range(4.0, 14.0)
	while x < half.x - 4.0:
		var height: float = rng.randf_range(3.0, 8.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, -half.y + 1), Vector2(x, -half.y - height), Vector2(x + 2.5, -half.y + 1)]), MOSS_LIGHT)
		x += rng.randf_range(9.0, 26.0)

func _draw_bricks(half: Vector2, color: Color, rng: RandomNumberGenerator) -> void:
	var row := 0
	var y := -half.y + 18.0
	while y < half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), color, 1.0)
		var x := -half.x + (11.0 if row % 2 == 0 else 0.0)
		while x < half.x:
			draw_line(Vector2(x, y - 18.0), Vector2(x, y), color, 1.0)
			x += 22.0
		y += 18.0
		row += 1

func _draw_strata(half: Vector2, color: Color, rng: RandomNumberGenerator) -> void:
	# Vetas y piedrecitas para que la tierra no se vea plana.
	var count: int = int(size.x * size.y / 2600.0)
	for index in range(min(count, 60)):
		var point := Vector2(rng.randf_range(-half.x + 6, half.x - 6), rng.randf_range(-half.y + 14, half.y - 4))
		if point.y > half.y - 4:
			continue
		draw_line(point, point + Vector2(rng.randf_range(6, 18), rng.randf_range(-1.5, 1.5)), color, 2.0)

func _draw_vines(half: Vector2, rng: RandomNumberGenerator) -> void:
	# Enredaderas colgando: indican que la pared sirve para wallride / running walljump.
	var x := -half.x + 6.0
	while x < half.x - 4.0:
		var length: float = rng.randf_range(size.y * 0.35, size.y * 0.95)
		var previous := Vector2(x, -half.y)
		var y := -half.y
		while y < -half.y + length:
			y += 12.0
			var point := Vector2(x + sin(y * 0.08) * 3.0, y)
			draw_line(previous, point, VINE, 2.0)
			if rng.randf() < 0.3:
				draw_circle(point, 2.5, MOSS_LIGHT)
			previous = point
		x += rng.randf_range(10.0, 18.0)
