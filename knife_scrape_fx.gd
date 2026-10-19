extends Node2D

# El cuchillo raspando el suelo al aterrizar el heavy aéreo: un brillo que tapa la punta clavada, un surco
# que se va dibujando en el suelo mientras Viridy se desliza (se queda en el mundo y se apaga al terminar)
# y chispas que saltan hacia atrás, todo del color del rango de estilo. Solo visual.

const FADE_TIME := 0.22
# El surco empieza ya con este tramo por detrás de la punta (el cuchillo entra al caer en diagonal y raja
# el suelo al frenar); luego se alarga con el deslizamiento.
const DRAG_LENGTH := 30.0

var active := false
var glow: Polygon2D
var core: Polygon2D
var trail: Line2D
var trail_core: Line2D
var sparks: CPUParticles2D
var fade_tween: Tween

func _init() -> void:
	top_level = true
	z_index = 2
	visible = false
	trail = _make_trail(4.0)
	trail_core = _make_trail(1.5)
	glow = _ellipse(Vector2(11.0, 6.0))
	core = _ellipse(Vector2(6.0, 3.0))
	sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = 30
	sparks.lifetime = 0.35
	sparks.local_coords = false
	sparks.spread = 35.0
	sparks.gravity = Vector2(0, 520)
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 170.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	add_child(sparks)
	set_color(Color(1.0, 0.72, 0.18))

func set_color(color: Color) -> void:
	var light: Color = color.lerp(Color.WHITE, 0.75)
	trail.default_color = Color(color, 0.9)
	trail_core.default_color = light
	glow.color = Color(color, 0.85)
	core.color = light
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([light, color, Color(color.darkened(0.4), 0.0)])
	sparks.color_ramp = ramp

func begin(tip: Vector2, facing: int, color: Color) -> void:
	set_color(color)
	if fade_tween:
		fade_tween.kill()
	active = true
	visible = true
	modulate.a = 1.0
	glow.visible = true
	core.visible = true
	trail.clear_points()
	trail_core.clear_points()
	var start: Vector2 = tip - Vector2(facing * DRAG_LENGTH, 0.0)
	trail.add_point(start)
	trail_core.add_point(start)
	sparks.direction = Vector2(-facing, -1.2).normalized()
	sparks.emitting = true
	follow(tip)

func follow(tip: Vector2) -> void:
	glow.position = tip
	core.position = tip
	sparks.position = tip
	var flicker: float = randf_range(0.85, 1.2)
	glow.scale = Vector2(flicker, flicker)
	core.scale = Vector2(flicker, 1.0)
	if trail.get_point_count() == 0 or trail.get_point_position(trail.get_point_count() - 1).distance_to(tip) > 2.0:
		trail.add_point(tip)
		trail_core.add_point(tip)

func end() -> void:
	active = false
	sparks.emitting = false
	glow.visible = false
	core.visible = false
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade_tween.tween_callback(func() -> void: visible = false)

func _make_trail(width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	return line

func _ellipse(radius: Vector2) -> Polygon2D:
	var points := PackedVector2Array()
	for index in range(16):
		var angle: float = TAU * index / 16.0
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	var poly := Polygon2D.new()
	poly.polygon = points
	add_child(poly)
	return poly
