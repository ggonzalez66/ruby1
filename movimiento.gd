extends CharacterBody2D

const ATTACK_NONE := 0
const ATTACK_SLASH := 1
const ATTACK_GROUND_CHARGED := 2
const ATTACK_AIR_CHARGED := 3
const ATTACK_SPIN := 4

const DAMAGE_SLASH := 1
const DAMAGE_GROUND_CHARGED := 3
const DAMAGE_AIR_CHARGED := 2
const DAMAGE_SPIN := 2

@export var max_speed := 320.0
@export var ground_acceleration := 2200.0
@export var air_acceleration := 1400.0
@export var ground_friction := 2600.0
@export var air_friction := 900.0
@export var jump_velocity := -560.0
@export var jump_cut_velocity := -220.0
@export var max_air_jumps := 1
@export var gravity := 1500.0
@export var fall_gravity_multiplier := 1.45
@export var max_fall_speed := 980.0
@export var wall_slide_speed := 120.0
@export var wall_jump_horizontal_speed := 440.0
@export var wall_jump_vertical_speed := -560.0
@export var wall_jump_control_lock_time := 0.07
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14
@export var attack_duration := 0.16
@export var attack_cooldown := 0.22
@export var attack_move_multiplier := 0.7
@export var attack_charge_time := 0.55
@export var charged_attack_cooldown := 0.5
@export var charged_ground_duration := 0.22
@export var charged_ground_lunge_speed := 980.0
@export var charged_ground_end_speed := 260.0
@export var charged_ground_jump_cancel_velocity := -540.0
@export var charged_air_forward_speed := 760.0
@export var charged_air_forward_drift := 520.0
@export var charged_air_drag := 1600.0
@export var charged_air_gravity_multiplier := 1.18
@export var charged_air_bounce_back_speed := 220.0
@export var charged_air_bounce_up_speed := -180.0
@export var spin_attack_duration := 0.34
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
@onready var charge_visual: Polygon2D = $ChargeVisual
@onready var charge_outline: Line2D = $ChargeOutline
@onready var dash_visual: Polygon2D = $DashVisual

var facing := 1
var air_jumps_remaining := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var charge_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 1
var wall_jump_lock_timer := 0.0
var wall_contact_direction := 0
var attack_mode := ATTACK_NONE
var is_charging_attack := false
var attack_targets_hit: Array[Area2D] = []

var slash_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_area_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var charge_base_color := Color(1.0, 1.0, 1.0, 0.0)
var charge_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var dash_visual_base_color := Color(1.0, 1.0, 1.0, 0.0)

var hitbox_base_position := Vector2.ZERO
var slash_visual_base_position := Vector2.ZERO
var slash_area_base_position := Vector2.ZERO
var slash_outline_base_position := Vector2.ZERO
var spawn_position := Vector2.ZERO

func _ready() -> void:
	floor_snap_length = 10.0
	air_jumps_remaining = max_air_jumps
	slash_base_color = slash_visual.color
	slash_area_base_color = slash_area_visual.color
	slash_outline_base_color = slash_outline.default_color
	charge_base_color = charge_visual.color
	charge_outline_base_color = charge_outline.default_color
	dash_visual_base_color = dash_visual.color
	hitbox_base_position = hitbox_shape.position
	slash_visual_base_position = slash_visual.position
	slash_area_base_position = slash_area_visual.position
	slash_outline_base_position = slash_outline.position
	spawn_position = global_position
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_update_facing_visual()
	_set_attack_active(false)
	_set_charge_visual_active(false)
	_set_dash_visual_active(false)

func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()
	_update_wall_state()
	var was_wall_sliding: bool = _is_wall_sliding()
	_update_timers(delta)

	if was_on_floor:
		coyote_timer = coyote_time
		air_jumps_remaining = max_air_jumps

	if Input.is_action_just_pressed("jump"):
		if attack_mode == ATTACK_GROUND_CHARGED:
			_start_spin_attack()
		else:
			jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_pressed("attack"):
		_begin_attack_charge()

	if Input.is_action_just_pressed("respawn"):
		_respawn_player()
		return

	if is_charging_attack:
		_update_attack_charge(delta)
		if Input.is_action_just_released("attack"):
			_release_attack_charge(was_on_floor, was_wall_sliding)

	if Input.is_action_just_pressed("dash"):
		_start_dash()

	var move_input: float = Input.get_axis("move_left", "move_right")

	if move_input != 0.0 and not _locks_facing():
		facing = 1 if move_input > 0.0 else -1
		_update_facing_visual()

	if dash_timer > 0.0:
		_apply_dash_movement()
	elif attack_mode == ATTACK_GROUND_CHARGED:
		_apply_ground_charged_movement()
	elif attack_mode == ATTACK_AIR_CHARGED:
		_apply_air_charged_movement(delta)
	elif attack_mode == ATTACK_SPIN:
		_apply_spin_attack_movement(delta)
	else:
		_apply_gravity(delta)
		_consume_jump_buffer()
		_apply_horizontal_movement(move_input, delta)

	_update_attack_animation()
	_update_charge_visual()
	_update_dash_visual()
	move_and_slide()
	_update_wall_state()
	_refresh_attack_hits()

	if attack_mode == ATTACK_AIR_CHARGED and is_on_floor():
		_end_attack()
	elif attack_mode == ATTACK_AIR_CHARGED and is_on_wall():
		_bounce_out_of_air_charged_attack()

	if is_on_floor():
		air_jumps_remaining = max_air_jumps
		if jump_buffer_timer > 0.0:
			_consume_jump_buffer()

func _update_timers(delta: float) -> void:
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)

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
	if attack_mode == ATTACK_AIR_CHARGED:
		gravity_scale = charged_air_gravity_multiplier

	var target_fall_speed: float = max_fall_speed
	if _is_wall_sliding():
		target_fall_speed = wall_slide_speed

	velocity.y = min(velocity.y + gravity * gravity_scale * delta, target_fall_speed)

	if Input.is_action_just_released("jump") and velocity.y < jump_cut_velocity and attack_mode != ATTACK_AIR_CHARGED:
		velocity.y = jump_cut_velocity

func _consume_jump_buffer() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if dash_timer > 0.0 or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_AIR_CHARGED or attack_mode == ATTACK_SPIN:
		return

	var can_ground_jump: bool = is_on_floor() or coyote_timer > 0.0
	if can_ground_jump:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		wall_contact_direction = 0
		velocity.y = jump_velocity
		return

	if _can_wall_jump():
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		air_jumps_remaining = max_air_jumps
		velocity.x = wall_contact_direction * wall_jump_horizontal_speed
		velocity.y = wall_jump_vertical_speed
		facing = wall_contact_direction
		wall_jump_lock_timer = wall_jump_control_lock_time
		_update_facing_visual()
		return

	if air_jumps_remaining <= 0:
		return

	jump_buffer_timer = 0.0
	air_jumps_remaining -= 1
	velocity.y = jump_velocity

func _apply_horizontal_movement(move_input: float, delta: float) -> void:
	if wall_jump_lock_timer > 0.0 and not is_on_floor():
		return

	var control_multiplier: float = 1.0
	if attack_mode == ATTACK_SLASH:
		control_multiplier = attack_move_multiplier

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

func _apply_ground_charged_movement() -> void:
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0

func _apply_air_charged_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, facing * charged_air_forward_drift, charged_air_drag * delta)
	_apply_gravity(delta)

func _apply_spin_attack_movement(delta: float) -> void:
	_apply_gravity(delta)

func _begin_attack_charge() -> void:
	if is_charging_attack or dash_timer > 0.0 or (attack_cooldown_timer > 0.0 and not _is_attack_active()):
		return

	is_charging_attack = true
	if charge_timer <= 0.0:
		charge_timer = 0.0
	_set_charge_visual_active(true)
	_update_charge_visual()

func _update_attack_charge(delta: float) -> void:
	charge_timer = min(charge_timer + delta, attack_charge_time)

func _release_attack_charge(was_on_floor: bool, was_wall_sliding: bool) -> void:
	is_charging_attack = false
	_set_charge_visual_active(false)

	if dash_timer > 0.0:
		dash_timer = 0.0
		_end_dash()

	var fully_charged: bool = charge_timer >= attack_charge_time
	charge_timer = 0.0

	if fully_charged:
		if _is_attack_active():
			_cancel_attack_for_chain()

		if was_on_floor:
			_start_ground_charged_attack()
		elif was_wall_sliding:
			_start_wall_spin_attack()
		else:
			_start_air_charged_attack()
		return

	if _is_attack_active():
		charge_timer = 0.0
		return

	_start_attack()

func _start_attack() -> void:
	if _is_attack_active() or dash_timer > 0.0:
		return

	attack_mode = ATTACK_SLASH
	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	attack_targets_hit.clear()
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_ground_charged_attack() -> void:
	attack_mode = ATTACK_GROUND_CHARGED
	attack_timer = charged_ground_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_air_charged_attack() -> void:
	attack_mode = ATTACK_AIR_CHARGED
	attack_timer = 0.0
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	velocity.x = facing * charged_air_forward_speed
	velocity.y = 0.0
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_spin_attack() -> void:
	if attack_mode != ATTACK_GROUND_CHARGED:
		return

	attack_mode = ATTACK_SPIN
	attack_timer = spin_attack_duration
	attack_targets_hit.clear()
	velocity.x = max(abs(velocity.x), charged_ground_lunge_speed) * facing
	velocity.y = charged_ground_jump_cancel_velocity
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_wall_spin_attack() -> void:
	if wall_contact_direction == 0:
		_start_air_charged_attack()
		return

	attack_mode = ATTACK_SPIN
	attack_timer = spin_attack_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	facing = wall_contact_direction
	velocity.x = charged_ground_lunge_speed * facing
	velocity.y = charged_ground_jump_cancel_velocity
	wall_jump_lock_timer = wall_jump_control_lock_time
	_set_attack_active(true)
	_update_facing_visual()
	_update_attack_animation()
	_refresh_attack_hits()

func _cancel_attack_for_chain() -> void:
	attack_mode = ATTACK_NONE
	attack_timer = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	_reset_attack_pose()

func _end_attack() -> void:
	var ending_mode: int = attack_mode
	attack_mode = ATTACK_NONE
	attack_timer = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	_reset_attack_pose()

	if ending_mode == ATTACK_GROUND_CHARGED:
		velocity.x = facing * charged_ground_end_speed

func _reset_attack_pose() -> void:
	hitbox.rotation = 0.0
	hitbox_shape.position = hitbox_base_position
	hitbox_shape.scale = Vector2.ONE
	slash_visual.position = slash_visual_base_position
	slash_area_visual.position = slash_area_base_position
	slash_outline.position = slash_outline_base_position
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
	if not _is_attack_active():
		return

	match attack_mode:
		ATTACK_SLASH:
			_animate_normal_slash()
		ATTACK_GROUND_CHARGED:
			_animate_ground_charged_attack()
		ATTACK_AIR_CHARGED:
			_animate_air_charged_attack()
		ATTACK_SPIN:
			_animate_spin_attack()

func _animate_normal_slash() -> void:
	var progress: float = 1.0 - (attack_timer / attack_duration)
	var slash_angle: float = lerp(-0.95, 0.35, progress)
	var slash_scale: float = lerp(0.92, 1.08, sin(progress * PI))
	var alpha: float = lerp(0.9, 0.2, progress)

	hitbox_shape.position = hitbox_base_position
	hitbox_shape.scale = Vector2.ONE
	slash_visual.position = slash_visual_base_position
	slash_area_visual.position = slash_area_base_position
	slash_outline.position = slash_outline_base_position
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

func _animate_ground_charged_attack() -> void:
	var progress: float = 1.0 - (attack_timer / charged_ground_duration)
	var swing: float = lerp(-0.08, 0.12, progress)
	var burst_scale: float = lerp(1.55, 1.18, progress)
	var flash_alpha: float = lerp(1.0, 0.35, progress)

	hitbox_shape.position = Vector2(hitbox_base_position.x + 18.0, hitbox_base_position.y)
	hitbox_shape.scale = Vector2(2.45, 1.45)
	slash_visual.position = slash_visual_base_position + Vector2(20.0, 0.0)
	slash_area_visual.position = slash_area_base_position + Vector2(22.0, 0.0)
	slash_outline.position = slash_outline_base_position + Vector2(22.0, 0.0)
	hitbox.rotation = swing
	slash_visual.rotation = swing
	slash_area_visual.rotation = swing
	slash_outline.rotation = swing
	slash_visual.scale = Vector2(burst_scale * 1.25, burst_scale * 1.0)
	slash_area_visual.scale = Vector2(2.2, 1.4)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(1.0, 0.93, 0.72, flash_alpha)
	slash_area_visual.color = Color(1.0, 0.72, 0.28, lerp(0.52, 0.24, progress))
	slash_outline.default_color = Color(1.0, 0.93, 0.65, lerp(1.0, 0.45, progress))

func _animate_air_charged_attack() -> void:
	var fall_ratio: float = clamp(velocity.y / max_fall_speed, 0.0, 1.0)
	var tilt: float = lerp(-0.18, 0.28, fall_ratio)
	var pulse: float = 0.92 + 0.08 * sin(Time.get_ticks_msec() / 70.0)

	hitbox_shape.position = Vector2(hitbox_base_position.x + 14.0, hitbox_base_position.y + 2.0)
	hitbox_shape.scale = Vector2(2.0, 1.35)
	slash_visual.position = slash_visual_base_position + Vector2(14.0, 2.0)
	slash_area_visual.position = slash_area_base_position + Vector2(16.0, 2.0)
	slash_outline.position = slash_outline_base_position + Vector2(16.0, 2.0)
	hitbox.rotation = tilt
	slash_visual.rotation = tilt
	slash_area_visual.rotation = tilt
	slash_outline.rotation = tilt
	slash_visual.scale = Vector2(1.7 * pulse, 1.15 * pulse)
	slash_area_visual.scale = Vector2(1.95, 1.32)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(0.9, 0.97, 1.0, 0.88)
	slash_area_visual.color = Color(0.4, 0.89, 1.0, 0.34)
	slash_outline.default_color = Color(0.74, 0.98, 1.0, 0.82)

func _animate_spin_attack() -> void:
	var progress: float = 1.0 - (attack_timer / spin_attack_duration)
	var spin_angle: float = progress * TAU * 1.6
	var pulse: float = 1.0 + 0.12 * sin(progress * PI * 4.0)

	hitbox_shape.position = Vector2(-10.0, 4.0)
	hitbox_shape.scale = Vector2(2.9, 2.1)
	slash_visual.position = Vector2(0.0, 4.0)
	slash_area_visual.position = Vector2(0.0, 4.0)
	slash_outline.position = Vector2(0.0, 4.0)
	hitbox.rotation = spin_angle
	slash_visual.rotation = spin_angle
	slash_area_visual.rotation = spin_angle
	slash_outline.rotation = spin_angle
	slash_visual.scale = Vector2(2.2 * pulse, 1.55 * pulse)
	slash_area_visual.scale = Vector2(2.75, 1.95)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(0.98, 0.95, 1.0, 0.82)
	slash_area_visual.color = Color(1.0, 0.84, 0.36, 0.3)
	slash_outline.default_color = Color(1.0, 0.97, 0.78, 0.92)

func _refresh_attack_hits() -> void:
	if not _is_attack_active():
		return

	for area in hitbox.get_overlapping_areas():
		_hit_area(area)

func _hit_area(area: Area2D) -> void:
	if not _is_attack_active():
		return

	if area in attack_targets_hit:
		return

	attack_targets_hit.append(area)

	if area.has_method("take_hit"):
		area.take_hit(global_position, facing, _get_attack_damage())

	if attack_mode == ATTACK_AIR_CHARGED:
		_bounce_out_of_air_charged_attack()

func _on_hitbox_area_entered(area: Area2D) -> void:
	_hit_area(area)

func _set_charge_visual_active(active: bool) -> void:
	charge_visual.visible = active
	charge_outline.visible = active
	charge_visual.color = charge_base_color if active else Color(charge_base_color.r, charge_base_color.g, charge_base_color.b, 0.0)
	charge_outline.default_color = charge_outline_base_color if active else Color(charge_outline_base_color.r, charge_outline_base_color.g, charge_outline_base_color.b, 0.0)

func _update_charge_visual() -> void:
	if not is_charging_attack:
		return

	var progress: float = clamp(charge_timer / attack_charge_time, 0.0, 1.0)
	var pulse: float = 1.0
	if progress >= 1.0:
		pulse = 1.0 + 0.1 * sin(Time.get_ticks_msec() / 55.0)

	var alpha: float = lerp(0.12, 0.56, progress)
	var glow_scale: float = lerp(0.55, 1.12, progress) * pulse
	var outline_alpha: float = lerp(0.35, 0.95, progress)

	charge_visual.scale = Vector2(glow_scale, glow_scale)
	charge_outline.scale = charge_visual.scale
	charge_visual.color = Color(lerp(0.5, 1.0, progress), lerp(0.76, 0.9, progress), lerp(1.0, 0.36, progress), alpha)
	charge_outline.default_color = Color(1.0, lerp(0.95, 0.82, progress), lerp(1.0, 0.3, progress), outline_alpha)

func _start_dash() -> void:
	if dash_timer > 0.0 or dash_cooldown_timer > 0.0 or _is_attack_active():
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

func _locks_facing() -> bool:
	return dash_timer > 0.0 or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_AIR_CHARGED or attack_mode == ATTACK_SPIN

func _update_wall_state() -> void:
	if is_on_floor():
		wall_contact_direction = 0
		return

	if is_on_wall():
		wall_contact_direction = int(sign(get_wall_normal().x))
	else:
		wall_contact_direction = 0

func _can_wall_jump() -> bool:
	return wall_contact_direction != 0 and not is_on_floor()

func _is_wall_sliding() -> bool:
	return _can_wall_jump() and velocity.y > 0.0 and attack_mode != ATTACK_AIR_CHARGED and attack_mode != ATTACK_SPIN and dash_timer <= 0.0

func _is_attack_active() -> bool:
	return attack_mode != ATTACK_NONE

func _bounce_out_of_air_charged_attack() -> void:
	if attack_mode != ATTACK_AIR_CHARGED:
		return

	_cancel_attack_for_chain()
	velocity.x = -facing * charged_air_bounce_back_speed
	velocity.y = charged_air_bounce_up_speed

func _get_attack_damage() -> int:
	match attack_mode:
		ATTACK_GROUND_CHARGED:
			return DAMAGE_GROUND_CHARGED
		ATTACK_AIR_CHARGED:
			return DAMAGE_AIR_CHARGED
		ATTACK_SPIN:
			return DAMAGE_SPIN
		_:
			return DAMAGE_SLASH

func _update_facing_visual() -> void:
	pivot.scale.x = facing
	dash_visual.position.x = -10.0 * facing
	dash_visual.scale.x = abs(dash_visual.scale.x) * facing

func _respawn_player() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = 1
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	attack_timer = 0.0
	attack_cooldown_timer = 0.0
	charge_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	dash_direction = 1
	wall_jump_lock_timer = 0.0
	wall_contact_direction = 0
	attack_mode = ATTACK_NONE
	is_charging_attack = false
	attack_targets_hit.clear()
	_set_attack_active(false)
	_set_charge_visual_active(false)
	_set_dash_visual_active(false)
	_reset_attack_pose()
	_update_facing_visual()
