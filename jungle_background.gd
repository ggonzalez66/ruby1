extends ParallaxBackground

# Fondo de jungla mística generado por código: cielo verdoso, dos capas de árboles con
# parallax, bruma y luciérnagas. Todo se construye en _ready para poder ajustarlo aquí.

const SKY_TOP := Color(0.04, 0.13, 0.12)
const SKY_BOTTOM := Color(0.2, 0.4, 0.31)
const FAR_TREE_COLOR := Color(0.1, 0.25, 0.2)
const MID_TREE_COLOR := Color(0.055, 0.16, 0.13)
const VINE_COLOR := Color(0.07, 0.2, 0.14)
const MIST_COLOR := Color(0.72, 0.95, 0.82, 0.07)
const FIREFLY_COLOR := Color(0.85, 1.0, 0.55, 0.9)
# Al subir la torre el cielo pasa a un atardecer dorado (por encima de las copas).
const HIGH_SKY_TOP := Color(0.17, 0.1, 0.16)
const HIGH_SKY_BOTTOM := Color(0.86, 0.56, 0.26)
const HIGH_RAY_COLOR := Color(1.0, 0.82, 0.5, 0.06)
# Altura extra (0..1) sumada a la de la cámara: el Gauntlet, de un solo piso, se ve como la cima.
@export var altitude_offset := 0.0
const TOWER_HEIGHT := 5500.0

var sky: Polygon2D
var rays: Array = []
var height_ratio := -1.0

func _ready() -> void:
	layer = -100
	_build_sky()
	_build_tree_layer(Vector2(0.12, 0.04), 2048.0, 430.0, FAR_TREE_COLOR, 14, Vector2(150.0, 300.0), 11, false)
	_build_tree_layer(Vector2(0.3, 0.1), 1600.0, 500.0, MID_TREE_COLOR, 9, Vector2(220.0, 420.0), 23, true)
	_build_mist()

func _build_sky() -> void:
	# Capa fija a la pantalla: degradado vertical y luciérnagas flotando.
	var sky_layer := _new_layer(Vector2.ZERO, Vector2.ZERO)
	sky = Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-2000, -1500), Vector2(4000, -1500), Vector2(4000, 2500), Vector2(-2000, 2500)])
	sky.vertex_colors = PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])
	sky_layer.add_child(sky)

	# Halo de luz mística cayendo entre las copas.
	for index in range(3):
		var ray := Polygon2D.new()
		var x: float = 260.0 + index * 330.0
		ray.polygon = PackedVector2Array([Vector2(x - 30, -100), Vector2(x + 40, -100), Vector2(x + 190, 760), Vector2(x + 40, 760)])
		ray.color = Color(0.78, 1.0, 0.75, 0.035)
		sky_layer.add_child(ray)
		rays.append(ray)

	var fireflies := CPUParticles2D.new()
	fireflies.amount = 36
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.position = Vector2(576, 340)
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(760, 420)
	fireflies.direction = Vector2(0, -1)
	fireflies.spread = 180.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 4.0
	fireflies.initial_velocity_max = 14.0
	fireflies.scale_amount_min = 1.5
	fireflies.scale_amount_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(FIREFLY_COLOR, 0.0))
	fade.set_color(1, Color(FIREFLY_COLOR, 0.0))
	fade.add_point(0.3, FIREFLY_COLOR)
	fade.add_point(0.7, FIREFLY_COLOR)
	fireflies.color_ramp = fade
	sky_layer.add_child(fireflies)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var ratio: float = clamp(-camera.get_screen_center_position().y / TOWER_HEIGHT + altitude_offset, 0.0, 1.0)
	if abs(ratio - height_ratio) < 0.002:
		return
	height_ratio = ratio
	var eased: float = smoothstep(0.0, 1.0, ratio)
	var top := SKY_TOP.lerp(HIGH_SKY_TOP, eased)
	var bottom := SKY_BOTTOM.lerp(HIGH_SKY_BOTTOM, eased)
	sky.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	for ray in rays:
		ray.color = Color(0.78, 1.0, 0.75, 0.035).lerp(HIGH_RAY_COLOR, eased)

func _build_tree_layer(motion: Vector2, width: float, base_y: float, color: Color, count: int, height_range: Vector2, seed_value: int, with_vines: bool) -> void:
	var tree_layer := _new_layer(motion, Vector2(width, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Suelo de la capa, para que no se vea el cielo por debajo de los árboles.
	var floor_poly := Polygon2D.new()
	floor_poly.color = color
	floor_poly.polygon = PackedVector2Array([Vector2(0, base_y), Vector2(width, base_y), Vector2(width, base_y + 2000), Vector2(0, base_y + 2000)])
	tree_layer.add_child(floor_poly)

	for index in range(count):
		var x: float = (index + rng.randf_range(0.15, 0.85)) * width / count
		var height: float = rng.randf_range(height_range.x, height_range.y)
		var trunk_width: float = rng.randf_range(14.0, 26.0)
		var top_y: float = base_y - height
		var trunk := Polygon2D.new()
		trunk.color = color
		trunk.polygon = PackedVector2Array([
			Vector2(x - trunk_width * 0.5, base_y), Vector2(x - trunk_width * 0.35, top_y),
			Vector2(x + trunk_width * 0.35, top_y), Vector2(x + trunk_width * 0.5, base_y)])
		tree_layer.add_child(trunk)

		# Copa: varios círculos solapados.
		for blob in range(rng.randi_range(3, 5)):
			var radius: float = rng.randf_range(45.0, 85.0)
			var center := Vector2(x + rng.randf_range(-60.0, 60.0), top_y + rng.randf_range(-30.0, 25.0))
			tree_layer.add_child(_circle(center, radius, color))

		if with_vines:
			for vine in range(rng.randi_range(1, 3)):
				var vine_x: float = x + rng.randf_range(-70.0, 70.0)
				var line := Line2D.new()
				line.width = 3.0
				line.default_color = VINE_COLOR
				var length: float = rng.randf_range(80.0, 200.0)
				for step in range(7):
					var t: float = step / 6.0
					line.add_point(Vector2(vine_x + sin(t * PI * 2.0) * 6.0, top_y + 20.0 + length * t))
				tree_layer.add_child(line)

func _build_mist() -> void:
	var mist_layer := _new_layer(Vector2(0.5, 0.2), Vector2(1800.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for index in range(6):
		var band := Polygon2D.new()
		var x: float = index * 300.0 + rng.randf_range(0.0, 120.0)
		var y: float = rng.randf_range(380.0, 520.0)
		var w: float = rng.randf_range(380.0, 620.0)
		band.polygon = _ellipse_points(Vector2(x, y), Vector2(w * 0.5, rng.randf_range(18.0, 34.0)))
		band.color = MIST_COLOR
		mist_layer.add_child(band)

func _new_layer(motion: Vector2, mirroring: Vector2) -> ParallaxLayer:
	var parallax_layer := ParallaxLayer.new()
	parallax_layer.motion_scale = motion
	parallax_layer.motion_mirroring = mirroring
	add_child(parallax_layer)
	return parallax_layer

func _circle(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = _ellipse_points(center, Vector2(radius, radius))
	return poly

func _ellipse_points(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(20):
		var angle: float = TAU * index / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
