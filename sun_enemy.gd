extends Area2D

# El sol: enemigo invencible. Recibe golpes (parpadea y su barra baja un momento),
# pero la vida se regenera al instante. Tocarlo hace daño al jugador.

@export var contact_damage := 15
@export var bob_amplitude := 10.0
@export var bob_period := 3.2
@export var ray_spin_speed := 0.6
@export var health_bar_width := 80.0
@export var health_regen_delay := 0.25
@export var health_regen_speed := 1.6

const CORE_COLOR := Color(1.0, 0.78, 0.25)
const CORE_INNER_COLOR := Color(1.0, 0.93, 0.6)
const RAY_COLOR := Color(1.0, 0.6, 0.16)
const GLOW_COLOR := Color(1.0, 0.82, 0.35, 0.18)
const FACE_COLOR := Color(0.42, 0.13, 0.04)
const HIT_FLASH_COLOR := Color(1.6, 1.6, 1.6)

var anchor_position := Vector2.ZERO
var impact_offset := Vector2.ZERO
var time := 0.0
var flash_timer := 0.0
var wobble := 0.0
var shown_health := 1.0
var regen_timer := 0.0

var visual: Node2D
var rays: Polygon2D
var glow: Polygon2D
var health_fill: Polygon2D

func _ready() -> void:
	anchor_position = position
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	monitorable = true
	add_to_group(&"sun")
	_build_visuals()

func _build_visuals() -> void:
	visual = Node2D.new()
	add_child(visual)
	glow = _ellipse(Vector2.ZERO, 108.0, GLOW_COLOR, 28)
	visual.add_child(glow)

	rays = Polygon2D.new()
	var ray_points := PackedVector2Array()
	for index in range(24):
		var radius: float = 94.0 if index % 2 == 0 else 66.0
		var angle: float = TAU * index / 24.0
		ray_points.append(Vector2(cos(angle), sin(angle)) * radius)
	rays.polygon = ray_points
	rays.color = RAY_COLOR
	visual.add_child(rays)

	visual.add_child(_ellipse(Vector2.ZERO, 62.0, CORE_COLOR, 28))
	visual.add_child(_ellipse(Vector2(-10, -12), 42.0, CORE_INNER_COLOR, 24))

	# Cara enfadada.
	visual.add_child(_poly([Vector2(-34, -16), Vector2(-10, -6), Vector2(-12, 2), Vector2(-32, -4)], FACE_COLOR))
	visual.add_child(_poly([Vector2(34, -16), Vector2(10, -6), Vector2(12, 2), Vector2(32, -4)], FACE_COLOR))
	visual.add_child(_poly([Vector2(-22, 26), Vector2(0, 16), Vector2(22, 26), Vector2(14, 32), Vector2(0, 26), Vector2(-14, 32)], FACE_COLOR))

	# Barra de vida "infinita" con el símbolo ∞.
	var bar := Node2D.new()
	bar.position = Vector2(0, -122)
	add_child(bar)
	var half: float = health_bar_width * 0.5
	bar.add_child(_poly([Vector2(-half - 2, -6), Vector2(half + 2, -6), Vector2(half + 2, 6), Vector2(-half - 2, 6)], Color(0.1, 0.08, 0.08, 0.85)))
	health_fill = _poly([], Color(1.0, 0.72, 0.18))
	bar.add_child(health_fill)
	var label := Label.new()
	label.text = "∞"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.02))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(half + 6, -17)
	bar.add_child(label)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	time += delta
	flash_timer = max(flash_timer - delta, 0.0)
	wobble = move_toward(wobble, 0.0, 6.0 * delta)
	position = anchor_position + Vector2(0.0, sin(time / bob_period * TAU) * bob_amplitude)
	rays.rotation += ray_spin_speed * delta
	var pulse: float = 1.0 + 0.06 * sin(time * 3.0)
	glow.scale = Vector2.ONE * pulse
	visual.scale = Vector2.ONE * (1.0 + wobble * 0.12)
	visual.modulate = HIT_FLASH_COLOR if flash_timer > 0.0 else Color.WHITE

	# Vida infinita: tras un golpe la barra vuelve a llenarse sola.
	if regen_timer > 0.0:
		regen_timer = max(regen_timer - delta, 0.0)
	elif shown_health < 1.0:
		shown_health = min(shown_health + health_regen_speed * delta, 1.0)
	_update_health_bar()

	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, self)

func take_hit(_source_position: Vector2, _direction: int = 1, damage: int = 1) -> void:
	Stats.add("sun_hits_dealt")
	flash_timer = 0.1
	wobble = 1.0
	shown_health = max(shown_health - 0.12 * max(damage, 1), 0.05)
	regen_timer = health_regen_delay

func _update_health_bar() -> void:
	var half: float = health_bar_width * 0.5
	var right: float = -half + health_bar_width * shown_health
	health_fill.polygon = PackedVector2Array([Vector2(-half, -4), Vector2(right, -4), Vector2(right, 4), Vector2(-half, 4)])

func _ellipse(center: Vector2, radius: float, color: Color, segments: int) -> Polygon2D:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * index / segments
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return _poly(points, color)

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
