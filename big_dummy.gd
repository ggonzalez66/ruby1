extends Area2D

# Guardián de la torre: dummy gigante con una espada enorme. Avisa cada ataque (el arma se
# pone roja y aparece "!") y luego tajea. Si el rugido de Rengar pilla el tajo en sus frames
# explosivos, el ataque se desvía y el guardián queda aturdido.

@export var max_health := 150
@export var min_x := 1700.0
@export var max_x := 4300.0
@export var walk_speed := 70.0
@export var attack_range := 210.0
@export var engage_distance := 650.0
@export var sword_damage := 25
@export var telegraph_time := 0.75
@export var swing_time := 0.2
@export var recover_time := 0.9
@export var stagger_time := 1.6

const BODY_SIZE := Vector2(70, 150)
const BODY_COLOR := Color(0.45, 0.2, 0.17)
const BODY_HIT_COLOR := Color(1.0, 0.45, 0.4)
const BAND_COLOR := Color(0.25, 0.1, 0.08)
const EYE_COLOR := Color(1.0, 0.85, 0.3)
const BLADE_COLOR := Color(0.78, 0.82, 0.9)
const BLADE_WARNING := Color(1.0, 0.25, 0.2)
const HILT_COLOR := Color(0.85, 0.62, 0.18)
const IDLE_ANGLE := 0.9
# [ángulo de preparación, ángulo final] de cada ataque, con la espada apuntando a +x en 0.
const ATTACKS := [Vector2(-2.6, 0.5), Vector2(-1.75, 1.25)]
const ATTACK_NAMES := ["Barrido", "Tajo vertical"]

enum State { IDLE, WALK, TELEGRAPH, SWING, RECOVER, STAGGER, DEFEATED }

var impact_offset := Vector2(0, -80)
var state := State.IDLE
var state_timer := 0.8
var current_health := 0
var facing := -1
var attack_kind := 0
var swing_hit_done := false
var angle_from := IDLE_ANGLE
var spawn_position := Vector2.ZERO
var flash_timer := 0.0

var visual: Node2D
var body_poly: Polygon2D
var sword_pivot: Node2D
var blade: Polygon2D
var sword_area: Area2D
var warning_label: Label
var health_fill: Polygon2D
var trail: Line2D

func _ready() -> void:
	add_to_group(&"training_dummies")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	spawn_position = position
	current_health = max_health
	_build()
	_update_health_bar()

func _build() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y * 0.5)
	add_child(shape)

	visual = Node2D.new()
	add_child(visual)
	var half := BODY_SIZE.x * 0.5
	visual.add_child(_poly([Vector2(-60, 0), Vector2(60, 0), Vector2(42, 22), Vector2(-42, 22)], BAND_COLOR))
	body_poly = _poly([Vector2(-half, 0), Vector2(half, 0), Vector2(half, -BODY_SIZE.y), Vector2(-half, -BODY_SIZE.y)], BODY_COLOR)
	visual.add_child(body_poly)
	visual.add_child(_poly([Vector2(-half, -118), Vector2(half, -118), Vector2(half, -104), Vector2(-half, -104)], BAND_COLOR))
	visual.add_child(_poly([Vector2(6, -136), Vector2(20, -136), Vector2(20, -128), Vector2(6, -128)], EYE_COLOR))
	visual.add_child(_poly([Vector2(24, -136), Vector2(32, -136), Vector2(32, -128), Vector2(24, -128)], EYE_COLOR))

	# Espada: pivota en el hombro y apunta a +x con rotación 0.
	sword_pivot = Node2D.new()
	sword_pivot.position = Vector2(26, -108)
	sword_pivot.rotation = IDLE_ANGLE
	visual.add_child(sword_pivot)
	sword_pivot.add_child(_poly([Vector2(-6, -16), Vector2(8, -16), Vector2(8, 16), Vector2(-6, 16)], HILT_COLOR))
	blade = _poly([Vector2(8, -11), Vector2(150, -9), Vector2(178, 0), Vector2(150, 9), Vector2(8, 11)], BLADE_COLOR)
	sword_pivot.add_child(blade)

	sword_area = Area2D.new()
	sword_area.collision_layer = 0
	sword_area.collision_mask = 1
	sword_area.monitorable = false
	var sword_shape := CollisionShape2D.new()
	var sword_rect := RectangleShape2D.new()
	sword_rect.size = Vector2(176, 30)
	sword_shape.shape = sword_rect
	sword_shape.position = Vector2(92, 0)
	sword_area.add_child(sword_shape)
	sword_pivot.add_child(sword_area)

	# Estela del tajo: gruesa en la punta reciente y transparente en la cola.
	trail = Line2D.new()
	trail.width = 18.0
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(1.0, 0.35, 0.25, 0.0))
	trail_gradient.set_color(1, Color(1.0, 0.92, 0.85, 0.8))
	trail.gradient = trail_gradient
	var trail_width := Curve.new()
	trail_width.add_point(Vector2(0.0, 0.1))
	trail_width.add_point(Vector2(1.0, 1.0))
	trail.width_curve = trail_width
	trail.top_level = true
	add_child(trail)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 40)
	warning_label.add_theme_color_override("font_color", BLADE_WARNING)
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 8)
	warning_label.position = Vector2(-8, -230)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -180)
	add_child(bar)
	bar.add_child(_poly([Vector2(-92, -7), Vector2(92, -7), Vector2(92, 7), Vector2(-92, 7)], Color(0.08, 0.04, 0.04, 0.9)))
	health_fill = _poly([], Color(0.9, 0.3, 0.22))
	bar.add_child(health_fill)
	var name_label := Label.new()
	name_label.text = "GUARDIÁN DE LA TORRE"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.position = Vector2(-82, -30)
	bar.add_child(name_label)

func _physics_process(delta: float) -> void:
	flash_timer = max(flash_timer - delta, 0.0)
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else BODY_COLOR
	if state == State.DEFEATED:
		return

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	state_timer -= delta
	match state:
		State.IDLE:
			_face(player)
			if state_timer <= 0.0 and _player_engaged(player):
				if abs(player.global_position.x - global_position.x) > attack_range:
					state = State.WALK
				else:
					_start_telegraph()
		State.WALK:
			_face(player)
			if not _player_engaged(player):
				state = State.IDLE
			elif abs(player.global_position.x - global_position.x) <= attack_range:
				_start_telegraph()
			else:
				position.x = clamp(position.x + facing * walk_speed * delta, min_x, max_x)
		State.TELEGRAPH:
			var progress: float = 1.0 - state_timer / telegraph_time
			sword_pivot.rotation = lerp(angle_from, ATTACKS[attack_kind].x, ease(clamp(progress * 1.4, 0.0, 1.0), 0.5))
			# El arma parpadea en rojo cada vez más rápido.
			var blink: float = 0.5 + 0.5 * sin(progress * progress * 40.0)
			blade.color = BLADE_COLOR.lerp(BLADE_WARNING, blink)
			if state_timer <= 0.0:
				_start_swing()
		State.SWING:
			var progress: float = clamp(1.0 - state_timer / swing_time, 0.0, 1.0)
			sword_pivot.rotation = lerp(ATTACKS[attack_kind].x, ATTACKS[attack_kind].y, ease(progress, 0.4))
			_update_trail()
			_check_sword_hit()
			if state_timer <= 0.0 and state == State.SWING:
				_enter_recover()
		State.RECOVER, State.STAGGER:
			sword_pivot.rotation = lerp_angle(sword_pivot.rotation, IDLE_ANGLE, 3.0 * delta)
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			trail.modulate.a = max(trail.modulate.a - 3.0 * delta, 0.0)
			if state_timer <= 0.0:
				state = State.IDLE
				state_timer = 0.5
				blade.color = BLADE_COLOR

func _player_engaged(player: Node2D) -> bool:
	if player == null:
		return false
	var offset := player.global_position - global_position
	return abs(offset.x) < engage_distance and abs(offset.y) < 260.0

func _face(player: Node2D) -> void:
	if player == null:
		return
	facing = 1 if player.global_position.x >= global_position.x else -1
	visual.scale.x = facing
	warning_label.position.x = -8.0

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	state_timer = telegraph_time
	attack_kind = (attack_kind + 1) % ATTACKS.size()
	angle_from = sword_pivot.rotation
	warning_label.visible = true

func _start_swing() -> void:
	state = State.SWING
	state_timer = swing_time
	swing_hit_done = false
	warning_label.visible = false
	blade.color = BLADE_COLOR.lerp(BLADE_WARNING, 0.35)
	trail.clear_points()
	trail.modulate.a = 1.0

func _enter_recover() -> void:
	state = State.RECOVER
	state_timer = recover_time
	blade.color = BLADE_COLOR

func _update_trail() -> void:
	var tip := sword_pivot.to_global(Vector2(176, 0))
	trail.add_point(tip)
	if trail.get_point_count() > 12:
		trail.remove_point(0)

func _check_sword_hit() -> void:
	if swing_hit_done:
		return
	for body in sword_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			swing_hit_done = true
			body.take_damage(sword_damage, global_position + Vector2(0, -60), self)
			return

func on_deflected(_by: Node) -> void:
	# El rugido desvió el tajo: la espada sale despedida hacia atrás y queda aturdido.
	if state != State.SWING:
		return
	swing_hit_done = true
	state = State.STAGGER
	state_timer = stagger_time
	warning_label.visible = false
	blade.color = BLADE_COLOR
	sword_pivot.rotation = -2.9
	visual.rotation = -0.12 * facing
	flash_timer = 0.15
	Fx.deflect(get_parent(), sword_pivot.to_global(Vector2(120, 0)))
	Fx.text(get_parent(), global_position + Vector2(0, -210), "¡ATURDIDO!", Color(1.0, 0.85, 0.5))

func take_hit(_source_position: Vector2, _direction: int = 1, damage: int = 1) -> void:
	if state == State.DEFEATED:
		return
	current_health = max(current_health - max(damage, 1), 0)
	flash_timer = 0.08
	_update_health_bar()
	if current_health == 0:
		_defeat()

func _defeat() -> void:
	state = State.DEFEATED
	warning_label.visible = false
	trail.clear_points()
	set_deferred("monitorable", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation", 1.4 * -facing, 0.6)
	tween.tween_property(visual, "modulate:a", 0.25, 0.8)
	Fx.text(get_parent(), global_position + Vector2(0, -220), "¡VICTORIA!", Color(1.0, 0.92, 0.5))

func reset_dummy() -> void:
	position = spawn_position
	current_health = max_health
	state = State.IDLE
	state_timer = 0.8
	attack_kind = 0
	visual.rotation = 0.0
	visual.modulate.a = 1.0
	sword_pivot.rotation = IDLE_ANGLE
	blade.color = BLADE_COLOR
	warning_label.visible = false
	trail.clear_points()
	set_deferred("monitorable", true)
	_update_health_bar()

func _update_health_bar() -> void:
	var ratio: float = float(current_health) / float(max(max_health, 1))
	var right: float = -90.0 + 180.0 * ratio
	health_fill.polygon = PackedVector2Array([Vector2(-90, -5), Vector2(right, -5), Vector2(right, 5), Vector2(-90, 5)])

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
