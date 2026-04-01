extends CharacterBody2D

@export var max_speed := 320.0
@export var ground_acceleration := 2200.0
@export var air_acceleration := 1400.0
@export var ground_friction := 2600.0
@export var air_friction := 900.0
@export var jump_velocity := -560.0
@export var jump_cut_velocity := -220.0
@export var gravity := 1500.0
@export var fall_gravity_multiplier := 1.45
@export var max_fall_speed := 980.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14
@export var attack_duration := 0.16
@export var attack_cooldown := 0.22
@export var attack_move_multiplier := 0.7
@export var dash_speed := 760.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.42
@export var dash_end_speed := 230.0

@onready var pivot: Node2D = $Pivot
@onready var hitbox: Area2D = $Pivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $Pivot/Hitbox/CollisionShape2D
@onready var slash_visual: Polygon2D = $Pivot/SlashVisual
@onready var slash_area_visual: Polygon2D = $Pivot/SlashAreaVisual
@onready var slash_outline: Line2D = $Pivot/SlashOutline
@onready var dash_visual: Polygon2D = $DashVisual

var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 1
var attack_targets_hit: Array[Area2D] = []
var slash_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_area_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var dash_visual_base_color := Color(1.0, 1.0, 1.0, 0.0)

func _ready() -> void:
	floor_snap_length = 10.0
	slash_base_color = slash_visual.color
	slash_area_base_color = slash_area_visual.color
	slash_outline_base_color = slash_outline.default_color
	dash_visual_base_color = dash_visual.color
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_update_facing_visual()
	_set_attack_active(false)
	_set_dash_visual_active(false)

func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_pressed("attack"):
		_start_attack()

	if Input.is_action_just_pressed("dash"):
		_start_dash()

	var move_input: float = Input.get_axis("move_left", "move_right")

	if move_input != 0.0 and attack_timer <= 0.0 and dash_timer <= 0.0:
		facing = 1 if move_input > 0.0 else -1
		_update_facing_visual()

	if is_on_floor():
		coyote_timer = coyote_time

	if dash_timer > 0.0:
		_apply_dash_movement()
	else:
		_apply_gravity(delta)
		_consume_jump_buffer()
		_apply_horizontal_movement(move_input, delta)

	_update_attack_animation()
	_update_dash_visual()
	move_and_slide()
	_refresh_attack_hits()

	if is_on_floor() and jump_buffer_timer > 0.0:
		_consume_jump_buffer()

func _update_timers(delta: float) -> void:
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	if attack_timer > 0.0:
		attack_timer = max(attack_timer - delta, 0.0)
		if attack_timer == 0.0:
			_end_attack()

	if dash_timer > 0.0:
		dash_timer = max(dash_timer - delta, 0.0)
		if dash_timer == 0.0:
			_end_dash()

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return

	var gravity_scale: float = fall_gravity_multiplier if velocity.y > 0.0 else 1.0
	velocity.y = min(velocity.y + gravity * gravity_scale * delta, max_fall_speed)

	if Input.is_action_just_released("jump") and velocity.y < jump_cut_velocity:
		velocity.y = jump_cut_velocity

func _consume_jump_buffer() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if not is_on_floor() and coyote_timer <= 0.0:
		return

	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.y = jump_velocity

func _apply_horizontal_movement(move_input: float, delta: float) -> void:
	var control_multiplier: float = attack_move_multiplier if attack_timer > 0.0 else 1.0
	var target_speed: float = move_input * max_speed * control_multiplier

	if move_input == 0.0:
		var friction: float = ground_friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

func _apply_dash_movement() -> void:
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0

func _start_attack() -> void:
	if attack_timer > 0.0 or attack_cooldown_timer > 0.0 or dash_timer > 0.0:
		return

	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	attack_targets_hit.clear()
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _end_attack() -> void:
	attack_targets_hit.clear()
	_set_attack_active(false)
	hitbox.rotation = 0.0
	slash_visual.rotation = 0.0
	slash_area_visual.rotation = 0.0
	slash_outline.rotation = 0.0
	slash_visual.scale = Vector2.ONE
	slash_area_visual.scale = Vector2.ONE
	slash_outline.scale = Vector2.ONE

func _set_attack_active(active: bool) -> void:
	hitbox.monitoring = active
	hitbox_shape.disabled = not active
	slash_visual.visible = active
	slash_area_visual.visible = active
	slash_outline.visible = active
	slash_visual.color = slash_base_color if active else Color(slash_base_color.r, slash_base_color.g, slash_base_color.b, 0.0)
	slash_area_visual.color = slash_area_base_color if active else Color(slash_area_base_color.r, slash_area_base_color.g, slash_area_base_color.b, 0.0)
	slash_outline.default_color = slash_outline_base_color if active else Color(slash_outline_base_color.r, slash_outline_base_color.g, slash_outline_base_color.b, 0.0)

func _update_attack_animation() -> void:
	if attack_timer <= 0.0:
		return

	var progress: float = 1.0 - (attack_timer / attack_duration)
	var slash_angle: float = lerp(-0.95, 0.35, progress)
	var slash_scale: float = lerp(0.92, 1.08, sin(progress * PI))
	var alpha: float = lerp(0.9, 0.2, progress)

	hitbox.rotation = slash_angle
	slash_visual.rotation = slash_angle
	slash_area_visual.rotation = slash_angle
	slash_outline.rotation = slash_angle
	slash_visual.scale = Vector2(slash_scale, slash_scale)
	slash_area_visual.scale = Vector2(lerp(0.98, 1.04, progress), lerp(0.92, 1.08, progress))
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(slash_base_color.r, slash_base_color.g, slash_base_color.b, alpha)
	slash_area_visual.color = Color(slash_area_base_color.r, slash_area_base_color.g, slash_area_base_color.b, lerp(0.42, 0.16, progress))
	slash_outline.default_color = Color(slash_outline_base_color.r, slash_outline_base_color.g, slash_outline_base_color.b, lerp(0.95, 0.35, progress))

func _refresh_attack_hits() -> void:
	if attack_timer <= 0.0:
		return

	for area in hitbox.get_overlapping_areas():
		_hit_area(area)

func _hit_area(area: Area2D) -> void:
	if attack_timer <= 0.0:
		return

	if area in attack_targets_hit:
		return

	attack_targets_hit.append(area)

	if area.has_method("take_hit"):
		area.take_hit(global_position, facing)

func _on_hitbox_area_entered(area: Area2D) -> void:
	_hit_area(area)

func _start_dash() -> void:
	if dash_timer > 0.0 or dash_cooldown_timer > 0.0 or attack_timer > 0.0:
		return

	var move_input: float = Input.get_axis("move_left", "move_right")
	dash_direction = facing if move_input == 0.0 else (1 if move_input > 0.0 else -1)
	facing = dash_direction
	_update_facing_visual()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	_set_dash_visual_active(true)
	_update_dash_visual()

func _end_dash() -> void:
	velocity.x = dash_direction * dash_end_speed
	_set_dash_visual_active(false)

func _set_dash_visual_active(active: bool) -> void:
	dash_visual.visible = active
	dash_visual.color = dash_visual_base_color if active else Color(dash_visual_base_color.r, dash_visual_base_color.g, dash_visual_base_color.b, 0.0)

func _update_dash_visual() -> void:
	if dash_timer <= 0.0:
		return

	var progress: float = 1.0 - (dash_timer / dash_duration)
	var alpha: float = lerp(0.42, 0.0, progress)
	var width_scale: float = lerp(1.35, 0.75, progress)

	dash_visual.scale = Vector2(width_scale * facing, 1.0)
	dash_visual.color = Color(dash_visual_base_color.r, dash_visual_base_color.g, dash_visual_base_color.b, alpha)

func _update_facing_visual() -> void:
	pivot.scale.x = facing
	dash_visual.position.x = -10.0 * facing
	dash_visual.scale.x = abs(dash_visual.scale.x) * facing
