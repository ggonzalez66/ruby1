class_name Fx
extends RefCounted

# Efectos visuales breves que se crean en el nivel y se borran solos.

const SILVER: Array[Color] = [Color(0.2, 0.22, 0.3), Color(0.74, 0.79, 0.88), Color(1.0, 1.0, 1.0)]
const GOLD: Array[Color] = [Color(0.32, 0.16, 0.03), Color(1.0, 0.7, 0.14), Color(1.0, 0.97, 0.72)]
# Rugido: dorado brillante (más luminoso que el de los ataques pesados).
const ROAR: Array[Color] = [Color(0.4, 0.22, 0.02), Color(1.0, 0.8, 0.28), Color(1.0, 0.98, 0.82)]
const DUST := Color(0.86, 0.8, 0.66, 0.85)

# Impacto al conectar un golpe: estrella de puntas que se abre y chispas.
static func impact(parent: Node, point: Vector2, palette: Array[Color], size: float = 1.0) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 5
	var tween := burst.create_tween().set_parallel(true)
	var duration := 0.18

	var star := Polygon2D.new()
	var points := PackedVector2Array()
	var spikes := 6
	var rotation := randf() * TAU
	for index in range(spikes * 2):
		var radius: float = (22.0 if index % 2 == 0 else 6.0) * size
		var angle: float = rotation + PI * index / spikes
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	star.polygon = points
	star.color = palette[2]
	burst.add_child(star)
	star.scale = Vector2.ONE * 0.4
	tween.tween_property(star, "scale", Vector2.ONE * 1.25, duration)
	tween.tween_property(star, "modulate:a", 0.0, duration)

	var ring := Line2D.new()
	ring.points = _circle(10.0 * size, 18, true)
	ring.width = 3.0
	ring.default_color = palette[1]
	burst.add_child(ring)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.4, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)

	for index in range(5):
		var angle: float = randf() * TAU
		var direction := Vector2(cos(angle), sin(angle))
		var spark := Line2D.new()
		spark.points = PackedVector2Array([Vector2.ZERO, direction * 9.0 * size])
		spark.width = 2.0
		spark.default_color = palette[2] if index % 2 == 0 else palette[1]
		burst.add_child(spark)
		tween.tween_property(spark, "position", direction * 30.0 * size, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(burst.queue_free)

# Destello grande del deflect: anillo doble y rayos.
static func deflect(parent: Node, point: Vector2) -> void:
	impact(parent, point, ROAR, 2.0)
	impact(parent, point, GOLD, 1.3)
	text(parent, point + Vector2(0, -40), "¡DEFLECT!", Color(1.0, 0.95, 0.7))

# Polvo: bolitas que salen en abanico hacia "direction" y se desvanecen.
static func dust(parent: Node, point: Vector2, direction: Vector2, count: int = 4, size: float = 1.0, spread: float = 0.9) -> void:
	var burst := _spawn(parent, point)
	var tween := burst.create_tween().set_parallel(true)
	var duration := 0.32
	var base_angle := direction.angle()
	for index in range(count):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(2.5, 4.5) * size, 8, false)
		puff.color = DUST
		burst.add_child(puff)
		var angle: float = base_angle + randf_range(-spread, spread)
		var distance: float = randf_range(10.0, 22.0) * size
		var target := Vector2(cos(angle), sin(angle)) * distance + Vector2(0, -4.0 * size)
		tween.tween_property(puff, "position", target, duration).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector2.ONE * 1.6, duration)
		tween.tween_property(puff, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(burst.queue_free)

# Anillo de aire del doble salto.
static func air_ring(parent: Node, point: Vector2) -> void:
	var burst := _spawn(parent, point)
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for index in range(17):
		var angle: float = TAU * index / 16.0
		points.append(Vector2(cos(angle) * 14.0, sin(angle) * 4.0))
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(0.95, 1.0, 0.92, 0.8)
	burst.add_child(ring)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(burst.queue_free)

# Rugido de la pose orgullosa: dos ondas que se abren desde el pecho y polvo a los lados de los pies.
static func roar_wave(parent: Node, point: Vector2, feet: Vector2, color: Color) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 4
	var tween := burst.create_tween().set_parallel(true)
	for index in range(2):
		var ring := Line2D.new()
		ring.points = _circle(18.0, 32, true)
		ring.width = 3.0 - index
		ring.default_color = Color(color, 0.85) if index == 0 else Color(color.lightened(0.5), 0.7)
		burst.add_child(ring)
		var delay: float = index * 0.1
		tween.tween_property(ring, "scale", Vector2(5.5, 3.6), 0.45).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ring, "modulate:a", 0.0, 0.45).set_delay(delay)
	tween.chain().tween_callback(burst.queue_free)
	dust(parent, feet, Vector2.LEFT, 5, 1.5, 0.4)
	dust(parent, feet, Vector2.RIGHT, 5, 1.5, 0.4)

# Shine de un enemigo: un Cubo de Metatrón de su color que aparece de golpe y se desvanece girando.
static func shine(parent: Node, point: Vector2, color: Color, radius: float = 36.0) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 5
	var cube: Node2D = load("res://metatron_cube.gd").new()
	cube.outer_radius = radius
	cube.line_color = Color(color, 0.95)
	cube.glow_color = Color(color.darkened(0.3), 0.25)
	cube.line_width = 1.5
	burst.add_child(cube)
	cube.modulate = Color(1.4, 1.4, 1.4)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(cube, "rotation", 0.9, 0.35)
	tween.tween_property(cube, "scale", Vector2.ONE * 1.15, 0.35)
	tween.tween_property(cube, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tween.chain().tween_callback(burst.queue_free)
	impact(parent, point, [color.darkened(0.6), color, Color(1.0, 0.97, 0.95)], 1.2)

# Rotura del shine: fragmentos de líneas que salen despedidos girando y se apagan.
static func shatter(parent: Node, point: Vector2, color: Color, radius: float = 46.0) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 6
	var tween := burst.create_tween().set_parallel(true)
	for index in range(16):
		var angle: float = TAU * index / 16.0 + randf_range(-0.2, 0.2)
		var direction := Vector2(cos(angle), sin(angle))
		var shard := Line2D.new()
		var length: float = randf_range(10.0, 22.0)
		shard.points = PackedVector2Array([Vector2(-length * 0.5, 0), Vector2(length * 0.5, 0)])
		shard.width = 2.5
		shard.default_color = color if index % 2 == 0 else color.lightened(0.4)
		shard.position = direction * radius * randf_range(0.3, 1.0)
		shard.rotation = randf() * TAU
		burst.add_child(shard)
		var travel: Vector2 = shard.position + direction * randf_range(40.0, 80.0) + Vector2(0, 30)
		tween.tween_property(shard, "position", travel, 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation", shard.rotation + randf_range(-6.0, 6.0), 0.5)
		tween.tween_property(shard, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tween.chain().tween_callback(burst.queue_free)
	impact(parent, point, [color.darkened(0.6), color, Color(1.0, 0.9, 0.85)], 1.8)

# Nubecilla para cosas que desaparecen (proyectiles contra la pared).
static func puff(parent: Node, point: Vector2, color: Color) -> void:
	var burst := _spawn(parent, point)
	var tween := burst.create_tween().set_parallel(true)
	var dot := Polygon2D.new()
	dot.polygon = _circle(7.0, 12, false)
	dot.color = color
	burst.add_child(dot)
	tween.tween_property(dot, "scale", Vector2.ONE * 2.2, 0.2)
	tween.tween_property(dot, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(burst.queue_free)

# Texto flotante que sube y se desvanece.
static func text(parent: Node, point: Vector2, message: String, color: Color) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 10
	parent.add_child(label)
	label.global_position = point - Vector2(48, 12)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", point.y - 50.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

static func _spawn(parent: Node, point: Vector2) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	node.global_position = point
	return node

static func _circle(radius: float, segments: int, closed: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * index / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if closed:
		points.append(points[0])
	return points
