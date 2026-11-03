extends ParallaxBackground

# Fondo del mundo espiritual dentro del sol: todo del color del sol. Cielo de fuego que se aclara al
# subir, el corazón del sol latiendo al fondo (PixelFX sunburst), rayos que giran despacio, anillos de
# plasma y brasas que suben.

const LOW_TOP := Color(1.0, 0.5, 0.1)
const LOW_BOTTOM := Color(0.85, 0.22, 0.05)
const HIGH_TOP := Color(1.0, 0.93, 0.7)
const HIGH_BOTTOM := Color(1.0, 0.62, 0.2)
const RAY := Color(1.0, 0.95, 0.7, 0.07)
const RING := Color(1.0, 0.9, 0.55, 0.16)
const EMBER := Color(1.0, 0.9, 0.5, 0.9)
@export var world_height := 4200.0

var sky: Polygon2D
var rays: Node2D
var height_ratio := -1.0

func _ready() -> void:
	layer = -100
	var sky_layer := _new_layer(Vector2.ZERO)
	sky = Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-2000, -1500), Vector2(4000, -1500), Vector2(4000, 2500), Vector2(-2000, 2500)])
	sky.vertex_colors = PackedColorArray([LOW_TOP, LOW_TOP, LOW_BOTTOM, LOW_BOTTOM])
	sky_layer.add_child(sky)
	# Rayos que giran desde el centro de la pantalla.
	rays = Node2D.new()
	rays.position = Vector2(576, 260)
	sky_layer.add_child(rays)
	for index in range(12):
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2(0, -8), Vector2(1400, -110), Vector2(1400, 110), Vector2(0, 8)])
		ray.color = RAY
		ray.rotation = TAU * index / 12.0
		rays.add_child(ray)
	# Anillos de plasma con parallax lento.
	var ring_layer := _new_layer(Vector2(0.05, 0.03))
	for index in range(4):
		var ring := Line2D.new()
		var points := PackedVector2Array()
		var radius := 160.0 + index * 120.0
		for segment in range(65):
			points.append(Vector2.from_angle(TAU * segment / 64.0) * radius)
		ring.points = points
		ring.width = 6.0 - index
		ring.default_color = RING
		ring.position = Vector2(576, 300)
		ring_layer.add_child(ring)
	# El corazón del sol al fondo.
	var heart_layer := _new_layer(Vector2(0.02, 0.01))
	heart_layer.position = Vector2(576, 300)
	var heart := Node2D.new()
	heart_layer.add_child(heart)
	_start_heart.call_deferred(heart)
	# Brasas que suben.
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.position = Vector2(576, 700)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(760, 60)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 50.0
	embers.initial_velocity_max = 140.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(EMBER, 0.0))
	fade.set_color(1, Color(EMBER, 0.0))
	fade.add_point(0.2, EMBER)
	fade.add_point(0.8, Color(1.0, 0.6, 0.2, 0.6))
	embers.color_ramp = fade
	sky_layer.add_child(embers)

func _start_heart(heart: Node2D) -> void:
	PixelFx.play(heart, "sunburst", Vector2.ZERO, 2.6, [], {"follow": heart, "loop": true, "z": -1, "modulate": Color(1, 1, 1, 0.55)})

func _process(delta: float) -> void:
	rays.rotation += delta * 0.05
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var ratio: float = clampf(-camera.get_screen_center_position().y / world_height, 0.0, 1.0)
	if absf(ratio - height_ratio) < 0.002:
		return
	height_ratio = ratio
	var top := LOW_TOP.lerp(HIGH_TOP, ratio)
	var bottom := LOW_BOTTOM.lerp(HIGH_BOTTOM, ratio)
	sky.vertex_colors = PackedColorArray([top, top, bottom, bottom])

func _new_layer(motion: Vector2) -> ParallaxLayer:
	var parallax := ParallaxLayer.new()
	parallax.motion_scale = motion
	add_child(parallax)
	return parallax
