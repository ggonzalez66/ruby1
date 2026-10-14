@tool
extends StaticBody2D

# Bloque del escenario: crea su colisión y se dibuja solo según su tamaño y estilo
# (tierra con musgo, losa de piso, plataforma, muro de ladrillo o muro trepable con enredaderas).
# Es @tool para que también se vea en el editor.

enum Style { GROUND, SLAB, PLATFORM, WALL, CLIMB_WALL }

@export var size := Vector2(200, 40):
	set(value):
		size = value
		_rebuild()
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
}

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
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), palette[1].darkened(0.4), 2.0)
	draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), palette[1].darkened(0.4), 2.0)
	# Musgo y hierba arriba (en los muros solo un remate).
	var moss_depth: float = 4.0 if style in [Style.WALL, Style.CLIMB_WALL] else min(9.0, size.y * 0.45)
	_draw_moss_top(half, moss_depth, rng, style not in [Style.WALL, Style.CLIMB_WALL])

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
