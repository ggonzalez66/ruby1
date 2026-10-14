extends Area2D

# Dummy perseguidor cuerpo a cuerpo: persigue a Rengar por el suelo (sin tirarse por bordes),
# avisa su zarpazo (parpadeo rojo y "!") y ataca. Se puede parrear con el rugido.
# Le afecta la gravedad: si cae de muy alto, explota.

@export var max_health := 8
@export var speed := 150.0
@export var detect_range := 520.0
# Ataca desde fuera del radio del rugido (46 px) para que se le pueda parrear en vez de golpearlo.
@export var attack_range := 85.0
@export var attack_reach := 104.0
@export var attack_damage := 12
@export var telegraph_time := 0.45
@export var swing_time := 0.12
@export var recover_time := 0.6
@export var stagger_time := 1.0

const BODY_COLOR := Color(0.55, 0.12, 0.14)
const BODY_HIT_COLOR := Color(1.0, 0.5, 0.45)
const WARNING_COLOR := Color(1.0, 0.85, 0.3)
const BAND_COLOR := Color(0.25, 0.05, 0.06)
const BLADE_COLOR := Color(0.85, 0.88, 0.95)
const GRAVITY := 1500.0
const MAX_FALL_SPEED := 900.0
const FALL_DEATH_HEIGHT := 260.0

enum State { IDLE, CHASE, TELEGRAPH, SWING, RECOVER, STAGGER, DEAD }

var impact_offset := Vector2(0, -26)
var state := State.IDLE
var state_timer := 0.0
var current_health := 0
var facing := -1
var fall_velocity := 0.0
var fall_distance := 0.0
var knock_velocity := 0.0
var flash_timer := 0.0
var swing_hit_done := false
var spawn_position := Vector2.ZERO

var visual: Node2D
var body_poly: Polygon2D
var arm: Node2D
var warning_label: Label
var health_fill: Polygon2D
var collision_shape: CollisionShape2D

func _ready() -> void:
	add_to_group(&"training_dummies")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	spawn_position = position
	_build()
	reset_dummy()

func _build() -> void:
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 50)
	collision_shape.shape = rect
	collision_shape.position = Vector2(0, -25)
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	body_poly = _poly([Vector2(-13, 0), Vector2(13, 0), Vector2(11, -50), Vector2(-11, -50)], BODY_COLOR)
	visual.add_child(body_poly)
	visual.add_child(_poly([Vector2(-12, -40), Vector2(12, -40), Vector2(12, -34), Vector2(-12, -34)], BAND_COLOR))
	visual.add_child(_poly([Vector2(3, -46), Vector2(10, -46), Vector2(10, -42), Vector2(3, -42)], WARNING_COLOR))
	# Brazo con cuchilla: pivota en el hombro y apunta hacia delante (+x).
	arm = Node2D.new()
	arm.position = Vector2(8, -32)
	arm.rotation = 0.9
	visual.add_child(arm)
	arm.add_child(_poly([Vector2(0, -3), Vector2(14, -3), Vector2(14, 3), Vector2(0, 3)], BAND_COLOR))
	# Hoja larga: su alcance visual coincide con attack_reach.
	arm.add_child(_poly([Vector2(14, -6), Vector2(80, -3), Vector2(94, 0), Vector2(80, 3), Vector2(14, 6)], BLADE_COLOR))

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -92)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -62)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	position = spawn_position
	current_health = max_health
	state = State.IDLE
	state_timer = 0.0
	fall_velocity = 0.0
	fall_distance = 0.0
	knock_velocity = 0.0
	flash_timer = 0.0
	visible = true
	visual.rotation = 0.0
	arm.rotation = 0.9
	warning_label.visible = false
	set_deferred("monitorable", true)
	collision_shape.set_deferred("disabled", false)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	flash_timer = max(flash_timer - delta, 0.0)
	state_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var grounded := _apply_gravity(delta)
	if state == State.DEAD:
		return

	# Retroceso al recibir golpes.
	if abs(knock_velocity) > 1.0:
		_move_horizontally(knock_velocity * delta, false)
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)

	match state:
		State.IDLE, State.CHASE:
			if player and _can_see(player):
				state = State.CHASE
				_face(player)
				var dx: float = player.global_position.x - global_position.x
				if abs(dx) <= attack_range and grounded:
					_start_telegraph()
				elif grounded:
					_move_horizontally(sign(dx) * speed * delta, true)
			else:
				state = State.IDLE
		State.TELEGRAPH:
			var progress: float = 1.0 - state_timer / telegraph_time
			arm.rotation = lerp(0.9, -1.9, ease(clamp(progress * 1.5, 0.0, 1.0), 0.5))
			if state_timer <= 0.0:
				state = State.SWING
				state_timer = swing_time
				swing_hit_done = false
				warning_label.visible = false
		State.SWING:
			var progress: float = clamp(1.0 - state_timer / swing_time, 0.0, 1.0)
			arm.rotation = lerp(-1.9, 1.3, progress)
			_check_swing_hit(player)
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = recover_time
		State.RECOVER, State.STAGGER:
			arm.rotation = lerp_angle(arm.rotation, 0.9, 6.0 * delta)
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			if state_timer <= 0.0:
				state = State.IDLE

	var blink: bool = state == State.TELEGRAPH and int(state_timer * 20.0) % 2 == 0
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else (WARNING_COLOR if blink else BODY_COLOR)

func _can_see(player: Node2D) -> bool:
	var offset := player.global_position - global_position
	return abs(offset.x) < detect_range and abs(offset.y) < 140.0 and player.current_health > 0

func _face(player: Node2D) -> void:
	facing = 1 if player.global_position.x >= global_position.x else -1
	visual.scale.x = facing

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	state_timer = telegraph_time
	warning_label.visible = true

func _check_swing_hit(player: Node2D) -> void:
	if swing_hit_done or player == null:
		return
	var dx: float = (player.global_position.x - global_position.x) * facing
	var dy: float = player.global_position.y - global_position.y
	if dx > -10.0 and dx < attack_reach and abs(dy) < 44.0:
		swing_hit_done = true
		player.take_damage(attack_damage, global_position + Vector2(0, -26), self)

func _apply_gravity(delta: float) -> bool:
	var reach: float = max(fall_velocity * delta, 0.0) + 2.0
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, reach), 2)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if fall_distance > FALL_DEATH_HEIGHT:
			_explode()
			return true
		global_position.y = hit.position.y
		fall_velocity = 0.0
		fall_distance = 0.0
		return true
	fall_velocity = min(fall_velocity + GRAVITY * delta, MAX_FALL_SPEED)
	global_position.y += fall_velocity * delta
	fall_distance += fall_velocity * delta
	if fall_distance > 3000.0:
		_die()
	return false

func _move_horizontally(amount: float, stop_at_ledges: bool) -> void:
	if amount == 0.0:
		return
	var direction: float = sign(amount)
	var space := get_world_2d().direct_space_state
	# Pared delante: no avanza.
	var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -20), global_position + Vector2(direction * 16.0 + amount, -20), 2))
	if not wall.is_empty():
		return
	# Sin suelo delante: al perseguir no se tira (el retroceso sí puede tirarlo).
	if stop_at_ledges:
		var ahead := global_position + Vector2(direction * 16.0 + amount, 0)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead + Vector2(0, -4), ahead + Vector2(0, 30), 2))
		if floor_hit.is_empty():
			return
	global_position.x += amount

func take_hit(_source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if state == State.DEAD:
		return
	current_health = max(current_health - max(damage, 1), 0)
	flash_timer = 0.1
	knock_velocity = direction * 200.0
	_update_health_bar()
	# Golpearlo mientras avisa interrumpe su ataque.
	if state == State.TELEGRAPH:
		state = State.STAGGER
		state_timer = 0.3
		warning_label.visible = false
	if current_health == 0:
		_die()

func on_deflected(_by: Node) -> void:
	if state != State.SWING:
		return
	swing_hit_done = true
	state = State.STAGGER
	state_timer = stagger_time
	visual.rotation = -0.2 * facing
	Fx.deflect(get_parent(), global_position + Vector2(facing * 24.0, -30))

func pull_towards(point: Vector2, strength: float) -> void:
	# El recall del cuchillo lo arrastra hacia Rengar (puede sacarlo de una plataforma).
	knock_velocity = sign(point.x - global_position.x) * strength * 5.0

func _explode() -> void:
	Ferocity.add("void_kill", 40.0, "AL VACÍO", Ferocity.BONUS_COLOR)
	var center := global_position + impact_offset
	Fx.impact(get_parent(), center, Fx.GOLD, 2.4)
	Fx.puff(get_parent(), center, Color(1.0, 0.6, 0.2, 0.9))
	Fx.text(get_parent(), center + Vector2(0, -30), "¡BOOM!", Color(1.0, 0.75, 0.4))
	current_health = 0
	_die()

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	Stats.add("dummies_killed")
	visible = false
	warning_label.visible = false
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)

func _update_health_bar() -> void:
	var ratio: float = float(current_health) / float(max(max_health, 1))
	var right: float = -16.0 + 32.0 * ratio
	health_fill.polygon = PackedVector2Array([Vector2(-16, -3), Vector2(right, -3), Vector2(right, 3), Vector2(-16, 3)])
	health_fill.visible = current_health > 0

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
