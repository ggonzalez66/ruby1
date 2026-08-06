extends CharacterBody2D

const STANDING_AND_WALKING_SHEET: Texture2D = preload("res://assets/sprites/player/reng_standing_and_walking-sheet.png")
const JUMPING_SHEET: Texture2D = preload("res://assets/sprites/player/reng_jumping-sheet.png")
const AERIAL_SPINNING_SHEET: Texture2D = preload("res://assets/sprites/player/reng_aerial_spinning-sheet.png")
const UPPERCUT_SHEET: Texture2D = preload("res://assets/sprites/player/reng_uppercut-sheet.png")
const WALLJUMP_SHEET: Texture2D = preload("res://assets/sprites/player/reng_walljump-sheet.png")
const CHARGE_LIGHT_TEXTURE: Texture2D = preload("res://assets/sprites/player/reng_charge_light.png")
const HEAVY_AERIAL_TEXTURE: Texture2D = preload("res://assets/sprites/player/reng_heavy_aerial.png")
const AERIAL_STALL_TEXTURE: Texture2D = preload("res://assets/sprites/player/reng_aerial-stall.png")
const DASH_TEXTURE: Texture2D = preload("res://assets/sprites/player/reng_dash_1.png")
const LIGHT_HITS_SHEET: Texture2D = preload("res://assets/sprites/player/reng_light_hits-sheet.png")
const GROUND_HEAVY_SHEET: Texture2D = preload("res://assets/sprites/player/reng-heavy.png")
const SPRINTING_SHEET: Texture2D = preload("res://assets/sprites/player/reng_sprinting.png")

const CHARACTER_VISUAL_SCALE := 0.18
const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"
const ANIMATION_JUMP := &"jump"
const ANIMATION_SPIN := &"spin"
const ANIMATION_UPPERCUT := &"uppercut"
const ANIMATION_WALL_SLIDE := &"wall_slide"
const ANIMATION_WALL_JUMP := &"wall_jump"
const ANIMATION_CHARGE := &"charge"
const ANIMATION_CHARGE_IDLE := &"charge_idle"
const ANIMATION_HEAVY_AERIAL := &"heavy_aerial"
const ANIMATION_FALL := &"fall"
const ANIMATION_DASH := &"dash"
const ANIMATION_LIGHT_HIT := &"light_hit"
const ANIMATION_GROUND_HEAVY := &"ground_heavy"
const ANIMATION_SPRINT := &"sprint"
const ANIMATION_LONG_JUMP := &"long_jump"

const ATTACK_NONE := 0
const ATTACK_SLASH := 1
const ATTACK_GROUND_CHARGED := 2
const ATTACK_HEAVY := 3
const ATTACK_SPIN := 4
const ATTACK_LIGHT_CHARGED_AIR := 5
const ATTACK_HEAVY_GROUND := 6
const ATTACK_UPPERCUT := 7

const DAMAGE_SLASH := 1
const DAMAGE_GROUND_CHARGED := 3
const DAMAGE_HEAVY := 2
const DAMAGE_SPIN := 2
const DAMAGE_LIGHT_CHARGED_AIR := 3
const DAMAGE_HEAVY_GROUND := 3
const DAMAGE_UPPERCUT := 3

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
@export var wall_jump_animation_duration := 0.18
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
@export var charged_air_forward_speed := 260.0
@export var charged_air_forward_drift := 220.0
@export var charged_air_drag := 1400.0
@export var heavy_attack_rise_gravity_multiplier := 2.1
@export var heavy_attack_fall_gravity_multiplier := 3.2
@export var heavy_attack_max_fall_speed := 1720.0
@export var heavy_attack_start_upward_speed := -330.0
@export var heavy_attack_arc_radius_x := 28.0
@export var heavy_attack_arc_radius_y := 42.0
@export var charged_air_bounce_back_speed := 220.0
@export var heavy_bounce_vertical_ratio := 0.8
@export var light_hit_stall_up_speed := -95.0
@export var spin_attack_duration := 0.34
@export var spin_heavy_cancel_window := 0.12
@export var light_uppercut_duration := 0.08
@export var light_uppercut_velocity := -980.0
@export var light_uppercut_forward_speed := 260.0
@export var ground_heavy_duration := 0.14
@export var ground_heavy_speed := 1240.0
@export var ground_heavy_end_speed := 320.0
@export var ground_heavy_reuse_cooldown := 1.0
@export var heavy_ground_impact_slide_speed := 210.0
@export var heavy_ground_impact_wave_duration := 0.2
@export var dash_speed := 760.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.42
@export var dash_end_speed := 230.0
@export var sprint_speed := 560.0
@export var sprint_turn_duration := 0.28
@export var sprint_brake_deceleration := 2600.0
@export var long_jump_squat_duration := 0.12
@export var long_jump_horizontal_speed := 680.0
@export var long_jump_vertical_speed := -500.0
@export var backflip_horizontal_speed := 520.0
@export var backflip_vertical_speed := -720.0

@onready var pivot: Node2D = $Pivot
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var hitbox: Area2D = $Pivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $Pivot/Hitbox/CollisionShape2D
@onready var slash_visual: Polygon2D = $Pivot/SlashVisual
@onready var slash_area_visual: Polygon2D = $Pivot/SlashAreaVisual
@onready var slash_outline: Line2D = $Pivot/SlashOutline
@onready var charge_visual: Polygon2D = $ChargeVisual
@onready var charge_outline: Line2D = $ChargeOutline
@onready var dash_visual: Polygon2D = $DashVisual
@onready var impact_wave_left: Polygon2D = $ImpactWaveLeft
@onready var impact_wave_right: Polygon2D = $ImpactWaveRight
@onready var impact_wave_left_outline: Line2D = $ImpactWaveLeftOutline
@onready var impact_wave_right_outline: Line2D = $ImpactWaveRightOutline

var facing := 1
var air_jumps_remaining := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var ground_heavy_cooldown_timer := 0.0
var charge_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 1
var is_sprinting := false
var sprint_direction := 1
var sprint_turn_timer := 0.0
var sprint_turn_direction := 0
var long_jump_squat_timer := 0.0
var long_jump_active := false
var backflip_active := false
var wall_jump_lock_timer := 0.0
var wall_jump_animation_timer := 0.0
var wall_contact_direction := 0
var wall_visual_direction := 0
var attack_mode := ATTACK_NONE
var is_charging_attack := false
var air_uppercut_available := true
var heavy_attack_visual_progress := 0.0
var heavy_ground_impact_wave_timer := 0.0
var attack_targets_hit: Array[Area2D] = []
var hitbox_visuals_visible := true

var slash_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_area_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var charge_base_color := Color(1.0, 1.0, 1.0, 0.0)
var charge_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var dash_visual_base_color := Color(1.0, 1.0, 1.0, 0.0)
var impact_wave_base_color := Color(1.0, 1.0, 1.0, 0.0)
var impact_wave_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)

var hitbox_base_position := Vector2.ZERO
var slash_visual_base_position := Vector2.ZERO
var slash_area_base_position := Vector2.ZERO
var slash_outline_base_position := Vector2.ZERO
var impact_wave_left_base_position := Vector2.ZERO
var impact_wave_right_base_position := Vector2.ZERO
var impact_wave_left_outline_base_position := Vector2.ZERO
var impact_wave_right_outline_base_position := Vector2.ZERO
var spawn_position := Vector2.ZERO

func _ready() -> void:
	floor_snap_length = 10.0
	_configure_character_animations()
	air_jumps_remaining = max_air_jumps
	slash_base_color = slash_visual.color
	slash_area_base_color = slash_area_visual.color
	slash_outline_base_color = slash_outline.default_color
	charge_base_color = charge_visual.color
	charge_outline_base_color = charge_outline.default_color
	dash_visual_base_color = dash_visual.color
	impact_wave_base_color = impact_wave_left.color
	impact_wave_outline_base_color = impact_wave_left_outline.default_color
	hitbox_base_position = hitbox_shape.position
	slash_visual_base_position = slash_visual.position
	slash_area_base_position = slash_area_visual.position
	slash_outline_base_position = slash_outline.position
	impact_wave_left_base_position = impact_wave_left.position
	impact_wave_right_base_position = impact_wave_right.position
	impact_wave_left_outline_base_position = impact_wave_left_outline.position
	impact_wave_right_outline_base_position = impact_wave_right_outline.position
	spawn_position = global_position
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_update_facing_visual()
	_set_attack_active(false)
	_set_charge_visual_active(false)
	_set_dash_visual_active(false)
	_set_impact_wave_active(false)
	_update_character_animation()

func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()
	_update_wall_state()
	var was_wall_sliding: bool = _is_wall_sliding()
	_update_timers(delta)
	var move_input: float = Input.get_axis("move_left", "move_right")

	if was_on_floor:
		coyote_timer = coyote_time
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true

	if Input.is_action_just_pressed("toggle_hitbox_visuals"):
		hitbox_visuals_visible = not hitbox_visuals_visible
		_update_hitbox_visual_visibility()

	if Input.is_action_just_pressed("jump"):
		if attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_LIGHT_CHARGED_AIR:
			_start_spin_attack()
		elif _try_start_spin_jump_cancel():
			pass
		elif _try_start_sprint_jump(move_input):
			pass
		else:
			jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_pressed("attack"):
		_begin_attack_charge()

	if Input.is_action_just_pressed("heavy_attack"):
		_start_heavy_attack()

	if Input.is_action_just_pressed("respawn"):
		_respawn_player()
		return

	if is_charging_attack:
		_update_attack_charge(delta)
		if Input.is_action_just_released("attack"):
			_release_attack_charge(was_on_floor, was_wall_sliding)

	if Input.is_action_just_pressed("dash"):
		_start_dash()

	if Input.is_action_just_released("dash") and dash_timer <= 0.0:
		_stop_sprint()

	if move_input != 0.0 and not _locks_facing():
		facing = 1 if move_input > 0.0 else -1
		_update_facing_visual()

	if dash_timer > 0.0:
		_apply_dash_movement()
	elif attack_mode == ATTACK_GROUND_CHARGED:
		_apply_ground_charged_movement()
	elif attack_mode == ATTACK_HEAVY:
		_apply_heavy_attack_movement(delta)
	elif attack_mode == ATTACK_HEAVY_GROUND:
		_apply_ground_heavy_movement()
	elif attack_mode == ATTACK_LIGHT_CHARGED_AIR:
		_apply_light_charged_air_movement()
	elif attack_mode == ATTACK_SPIN:
		_apply_spin_attack_movement(delta)
	elif attack_mode == ATTACK_UPPERCUT:
		_apply_uppercut_movement(delta)
	elif _uses_sprint_movement():
		_apply_sprint_movement(move_input, delta)
	else:
		_apply_gravity(delta)
		_consume_jump_buffer()
		_apply_horizontal_movement(move_input, delta)

	_update_attack_animation()
	_update_charge_visual()
	_update_dash_visual()
	_update_impact_wave_visual()
	move_and_slide()
	_update_wall_state()
	_refresh_attack_hits()

	if attack_mode == ATTACK_HEAVY and is_on_floor():
		_land_heavy_attack_on_floor()
	elif attack_mode == ATTACK_HEAVY and is_on_wall():
		_bounce_out_of_heavy_attack()

	if is_on_wall() and not is_on_floor() and _uses_sprint_movement():
		long_jump_active = false
		backflip_active = false
		_stop_sprint()

	if is_on_floor():
		long_jump_active = false
		backflip_active = false
		if Input.is_action_pressed("dash") and dash_timer <= 0.0 and not _is_attack_active():
			if not is_sprinting:
				_start_sprint(sprint_direction)
		elif not Input.is_action_pressed("dash"):
			_stop_sprint()
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true
		if jump_buffer_timer > 0.0:
			_consume_jump_buffer()

	_update_character_animation()

func _configure_character_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_sheet_animation(frames, ANIMATION_IDLE, STANDING_AND_WALKING_SHEET, 3, 5.0, true, [0])
	_add_sheet_animation(frames, ANIMATION_WALK, STANDING_AND_WALKING_SHEET, 3, 8.0, true)
	_add_sheet_animation(frames, ANIMATION_JUMP, JUMPING_SHEET, 3, 10.0, false)
	_add_sheet_animation(frames, ANIMATION_SPIN, AERIAL_SPINNING_SHEET, 3, 12.0, true)
	_add_sheet_animation(frames, ANIMATION_UPPERCUT, UPPERCUT_SHEET, 3, 30.0, false)
	_add_sheet_animation(frames, ANIMATION_WALL_SLIDE, WALLJUMP_SHEET, 2, 1.0, false, [0])
	_add_sheet_animation(frames, ANIMATION_WALL_JUMP, WALLJUMP_SHEET, 2, 1.0, false, [1])
	_add_sheet_animation(frames, ANIMATION_CHARGE_IDLE, UPPERCUT_SHEET, 3, 1.0, false, [0])
	_add_sheet_animation(frames, ANIMATION_LIGHT_HIT, LIGHT_HITS_SHEET, 2, 12.5, false)
	_add_sheet_animation(frames, ANIMATION_GROUND_HEAVY, GROUND_HEAVY_SHEET, 2, 14.0, false)
	_add_sheet_animation(frames, ANIMATION_SPRINT, SPRINTING_SHEET, 3, 12.0, true)
	_add_sheet_animation(frames, ANIMATION_LONG_JUMP, WALLJUMP_SHEET, 2, 1.0, false, [1])
	_add_single_frame_animation(frames, ANIMATION_CHARGE, CHARGE_LIGHT_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_HEAVY_AERIAL, HEAVY_AERIAL_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_FALL, AERIAL_STALL_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_DASH, DASH_TEXTURE)
	animated_sprite.sprite_frames = frames
	animated_sprite.scale = Vector2.ONE * CHARACTER_VISUAL_SCALE

func _add_single_frame_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, 1.0)
	frames.set_animation_loop(animation_name, false)
	frames.add_frame(animation_name, texture)

func _add_sheet_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	columns: int,
	fps: float,
	loops: bool,
	frame_order: Array[int] = []
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	var frame_width: float = texture.get_width() / float(columns)
	var indexes: Array[int] = frame_order
	if indexes.is_empty():
		for index in range(columns):
			indexes.append(index)
	for index in indexes:
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(frame_width * index, 0.0, frame_width, texture.get_height())
		atlas_frame.filter_clip = true
		frames.add_frame(animation_name, atlas_frame)

func _update_character_animation() -> void:
	var next_animation: StringName
	if attack_mode == ATTACK_SPIN:
		next_animation = ANIMATION_SPIN
	elif attack_mode == ATTACK_UPPERCUT:
		next_animation = ANIMATION_UPPERCUT
	elif attack_mode == ATTACK_HEAVY:
		next_animation = ANIMATION_HEAVY_AERIAL
	elif attack_mode == ATTACK_HEAVY_GROUND:
		next_animation = ANIMATION_GROUND_HEAVY
	elif attack_mode == ATTACK_SLASH:
		next_animation = ANIMATION_LIGHT_HIT
	elif dash_timer > 0.0:
		next_animation = ANIMATION_DASH
	elif _is_attack_active():
		next_animation = ANIMATION_CHARGE
	elif wall_jump_animation_timer > 0.0 and not is_on_floor():
		next_animation = ANIMATION_WALL_JUMP
	elif _is_wall_sliding():
		next_animation = ANIMATION_WALL_SLIDE
	elif long_jump_squat_timer > 0.0 or long_jump_active:
		next_animation = ANIMATION_LONG_JUMP
	elif is_charging_attack and is_on_floor() and abs(velocity.x) <= 10.0:
		next_animation = ANIMATION_CHARGE_IDLE
	elif not is_on_floor():
		next_animation = ANIMATION_FALL if velocity.y > 0.0 else ANIMATION_JUMP
	elif is_sprinting:
		next_animation = ANIMATION_SPRINT
	elif abs(velocity.x) > 10.0:
		next_animation = ANIMATION_WALK
	else:
		next_animation = ANIMATION_IDLE

	if animated_sprite.animation != next_animation:
		animated_sprite.play(next_animation)
	_align_character_animation(next_animation)
	_update_character_orientation(next_animation)
	shadow.visible = is_on_floor()

func _update_character_orientation(animation_name: StringName) -> void:
	if animation_name == ANIMATION_WALL_SLIDE or animation_name == ANIMATION_WALL_JUMP:
		# Ambos frames representan una secuencia desde una pared situada a la izquierda:
		# el primero mira hacia ella y el segundo salta en dirección contraria.
		animated_sprite.flip_h = wall_visual_direction < 0
		return
	animated_sprite.flip_h = facing < 0

func _align_character_animation(animation_name: StringName) -> void:
	var texture_height: float
	match animation_name:
		ANIMATION_IDLE, ANIMATION_WALK:
			texture_height = STANDING_AND_WALKING_SHEET.get_height()
		ANIMATION_JUMP:
			texture_height = JUMPING_SHEET.get_height()
		ANIMATION_SPIN:
			texture_height = AERIAL_SPINNING_SHEET.get_height()
		ANIMATION_UPPERCUT, ANIMATION_CHARGE_IDLE:
			texture_height = UPPERCUT_SHEET.get_height()
		ANIMATION_WALL_SLIDE, ANIMATION_WALL_JUMP:
			texture_height = WALLJUMP_SHEET.get_height()
		ANIMATION_CHARGE:
			texture_height = CHARGE_LIGHT_TEXTURE.get_height()
		ANIMATION_HEAVY_AERIAL:
			texture_height = HEAVY_AERIAL_TEXTURE.get_height()
		ANIMATION_FALL:
			texture_height = AERIAL_STALL_TEXTURE.get_height()
		ANIMATION_DASH:
			texture_height = DASH_TEXTURE.get_height()
		ANIMATION_LIGHT_HIT:
			texture_height = LIGHT_HITS_SHEET.get_height()
		ANIMATION_GROUND_HEAVY:
			texture_height = GROUND_HEAVY_SHEET.get_height()
		ANIMATION_SPRINT:
			texture_height = SPRINTING_SHEET.get_height()
		ANIMATION_LONG_JUMP:
			texture_height = WALLJUMP_SHEET.get_height()
	animated_sprite.position = Vector2(0.0, -texture_height * CHARACTER_VISUAL_SCALE * 0.5)

func _update_timers(delta: float) -> void:
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	ground_heavy_cooldown_timer = max(ground_heavy_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)
	wall_jump_animation_timer = max(wall_jump_animation_timer - delta, 0.0)
	heavy_ground_impact_wave_timer = max(heavy_ground_impact_wave_timer - delta, 0.0)

	if attack_timer > 0.0:
		attack_timer = max(attack_timer - delta, 0.0)
		if attack_timer == 0.0:
			_end_attack()

	if dash_timer > 0.0:
		dash_timer = max(dash_timer - delta, 0.0)
		if dash_timer == 0.0:
			_end_dash()

	if long_jump_squat_timer > 0.0:
		long_jump_squat_timer = max(long_jump_squat_timer - delta, 0.0)
		if long_jump_squat_timer == 0.0:
			_launch_long_jump()

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return

	var gravity_scale: float = fall_gravity_multiplier if velocity.y > 0.0 else 1.0
	if attack_mode == ATTACK_HEAVY:
		gravity_scale = heavy_attack_fall_gravity_multiplier if velocity.y > 0.0 else heavy_attack_rise_gravity_multiplier

	var target_fall_speed: float = max_fall_speed
	if _is_wall_sliding():
		target_fall_speed = wall_slide_speed
	elif attack_mode == ATTACK_HEAVY:
		target_fall_speed = heavy_attack_max_fall_speed

	velocity.y = min(velocity.y + gravity * gravity_scale * delta, target_fall_speed)

	if Input.is_action_just_released("jump") and velocity.y < jump_cut_velocity and attack_mode != ATTACK_HEAVY:
		velocity.y = jump_cut_velocity

func _consume_jump_buffer() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if dash_timer > 0.0 or _uses_sprint_movement() or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_SPIN or attack_mode == ATTACK_LIGHT_CHARGED_AIR or attack_mode == ATTACK_HEAVY_GROUND or attack_mode == ATTACK_UPPERCUT:
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
		air_uppercut_available = true
		velocity.x = wall_contact_direction * wall_jump_horizontal_speed
		velocity.y = wall_jump_vertical_speed
		facing = wall_contact_direction
		wall_visual_direction = wall_contact_direction
		wall_jump_lock_timer = wall_jump_control_lock_time
		wall_jump_animation_timer = wall_jump_animation_duration
		_update_facing_visual()
		return

	if air_jumps_remaining <= 0:
		return

	jump_buffer_timer = 0.0
	air_jumps_remaining -= 1
	velocity.y = jump_velocity
	animated_sprite.play(ANIMATION_JUMP)

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

func _try_start_sprint_jump(move_input: float) -> bool:
	if not is_sprinting or (not is_on_floor() and coyote_timer <= 0.0) or _is_attack_active() or dash_timer > 0.0:
		return false

	var input_direction := int(sign(move_input))
	var reversing: bool = sprint_turn_timer > 0.0 or (input_direction != 0 and input_direction != sprint_direction)
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	if reversing:
		var backflip_direction := sprint_turn_direction
		if backflip_direction == 0:
			backflip_direction = input_direction
		_start_backflip(backflip_direction)
	else:
		_start_long_jump_squat()
	return true

func _start_long_jump_squat() -> void:
	long_jump_squat_timer = long_jump_squat_duration
	long_jump_active = false
	backflip_active = false
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	velocity.y = 0.0

func _launch_long_jump() -> void:
	long_jump_active = true
	backflip_active = false
	velocity.x = sprint_direction * long_jump_horizontal_speed
	velocity.y = long_jump_vertical_speed
	facing = sprint_direction
	_update_facing_visual()

func _start_backflip(direction: int) -> void:
	var target_direction := direction
	if target_direction == 0:
		target_direction = -sprint_direction
	sprint_direction = 1 if target_direction > 0 else -1
	facing = sprint_direction
	long_jump_squat_timer = 0.0
	long_jump_active = false
	backflip_active = true
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	velocity.x = sprint_direction * backflip_horizontal_speed
	velocity.y = backflip_vertical_speed
	_update_facing_visual()

func _uses_sprint_movement() -> bool:
	return is_sprinting or long_jump_squat_timer > 0.0 or long_jump_active or backflip_active

func _apply_sprint_movement(move_input: float, delta: float) -> void:
	if long_jump_squat_timer > 0.0:
		velocity.x = sprint_direction * sprint_speed
		velocity.y = 0.0
		return

	if long_jump_active:
		velocity.x = sprint_direction * long_jump_horizontal_speed
		_apply_gravity(delta)
		return

	if backflip_active:
		velocity.x = sprint_direction * backflip_horizontal_speed
		_apply_gravity(delta)
		return

	if not is_on_floor():
		velocity.x = sprint_direction * sprint_speed
		_apply_gravity(delta)
		return

	if sprint_turn_timer > 0.0:
		sprint_turn_timer = max(sprint_turn_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, sprint_brake_deceleration * delta)
		velocity.y = 0.0
		if sprint_turn_timer == 0.0:
			_complete_sprint_turn()
		return

	var input_direction := int(sign(move_input))
	if input_direction != 0 and input_direction != sprint_direction:
		_start_sprint_turn(input_direction)
		velocity.x = move_toward(velocity.x, 0.0, sprint_brake_deceleration * delta)
		velocity.y = 0.0
		return

	velocity.x = sprint_direction * sprint_speed
	velocity.y = 0.0

func _start_sprint(direction: int) -> void:
	var target_direction := direction
	if target_direction == 0:
		target_direction = facing
	is_sprinting = true
	sprint_direction = 1 if target_direction > 0 else -1
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	facing = sprint_direction
	_update_facing_visual()

func _stop_sprint() -> void:
	is_sprinting = false
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	long_jump_squat_timer = 0.0

func _start_sprint_turn(direction: int) -> void:
	sprint_turn_direction = 1 if direction > 0 else -1
	sprint_turn_timer = sprint_turn_duration

func _complete_sprint_turn() -> void:
	if sprint_turn_direction == 0:
		return
	sprint_direction = sprint_turn_direction
	sprint_turn_direction = 0
	facing = sprint_direction
	velocity.x = sprint_direction * sprint_speed
	_update_facing_visual()

func _apply_dash_movement() -> void:
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0

func _apply_ground_charged_movement() -> void:
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0

func _apply_heavy_attack_movement(delta: float) -> void:
	heavy_attack_visual_progress = min(heavy_attack_visual_progress + (delta / ground_heavy_duration), 1.0)
	velocity.x = facing * max(abs(velocity.x), ground_heavy_speed)
	_apply_gravity(delta)

func _apply_ground_heavy_movement() -> void:
	velocity.x = facing * max(abs(velocity.x), ground_heavy_speed)
	velocity.y = 0.0

func _apply_light_charged_air_movement() -> void:
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0

func _apply_spin_attack_movement(delta: float) -> void:
	_apply_gravity(delta)

func _apply_uppercut_movement(delta: float) -> void:
	var forward_speed := facing * light_uppercut_forward_speed
	var is_moving_forward: bool = sign(velocity.x) == facing or is_zero_approx(velocity.x)
	if not is_moving_forward or abs(velocity.x) < abs(forward_speed):
		velocity.x = move_toward(velocity.x, forward_speed, air_acceleration * 3.2 * delta)
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

		if was_wall_sliding:
			_start_wall_spin_attack()
		elif _wants_uppercut_attack():
			if was_on_floor or _can_start_air_uppercut():
				_start_uppercut_attack(not was_on_floor)
			elif was_on_floor:
				_start_ground_charged_attack()
			else:
				_start_light_charged_air_attack()
		elif was_on_floor:
			_start_ground_charged_attack()
		else:
			_start_light_charged_air_attack()
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

func _start_heavy_attack() -> void:
	var canceling_from_spin: bool = attack_mode == ATTACK_SPIN and not is_on_floor() and attack_timer <= spin_heavy_cancel_window
	if dash_timer > 0.0 or is_charging_attack:
		return

	if canceling_from_spin:
		_cancel_attack_for_chain()
	elif _is_attack_active() or attack_cooldown_timer > 0.0:
		return

	if is_on_floor():
		_start_ground_heavy_attack()
		return

	if _is_wall_sliding():
		facing = wall_contact_direction
		_update_facing_visual()

	attack_mode = ATTACK_HEAVY
	attack_timer = 0.0
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	heavy_attack_visual_progress = 0.0
	velocity.x = facing * max(abs(velocity.x + facing * charged_air_forward_speed), ground_heavy_speed)
	velocity.y = max(velocity.y, 60.0)
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_ground_heavy_attack() -> void:
	if ground_heavy_cooldown_timer > 0.0:
		return

	attack_mode = ATTACK_HEAVY_GROUND
	attack_timer = ground_heavy_duration
	attack_cooldown_timer = attack_cooldown
	ground_heavy_cooldown_timer = ground_heavy_reuse_cooldown
	attack_targets_hit.clear()
	velocity.x = facing * max(abs(velocity.x), ground_heavy_speed)
	velocity.y = 0.0
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_light_charged_air_attack() -> void:
	attack_mode = ATTACK_LIGHT_CHARGED_AIR
	attack_timer = charged_ground_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_uppercut_attack(from_air: bool) -> void:
	attack_mode = ATTACK_UPPERCUT
	attack_timer = light_uppercut_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	if from_air:
		air_jumps_remaining = 0
		air_uppercut_available = false
	velocity.x = facing * max(abs(velocity.x), light_uppercut_forward_speed)
	velocity.y = light_uppercut_velocity
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_spin_attack() -> void:
	if attack_mode != ATTACK_GROUND_CHARGED and attack_mode != ATTACK_LIGHT_CHARGED_AIR:
		return

	attack_mode = ATTACK_SPIN
	attack_timer = spin_attack_duration
	attack_targets_hit.clear()
	velocity.x = max(abs(velocity.x), charged_ground_lunge_speed) * facing
	velocity.y = charged_ground_jump_cancel_velocity
	_set_attack_active(true)
	animated_sprite.play(ANIMATION_SPIN)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_wall_spin_attack() -> void:
	if wall_contact_direction == 0:
		_start_heavy_attack()
		return

	attack_mode = ATTACK_SPIN
	attack_timer = spin_attack_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	air_jumps_remaining = max_air_jumps
	air_uppercut_available = true
	facing = wall_contact_direction
	velocity.x = charged_ground_lunge_speed * facing
	velocity.y = charged_ground_jump_cancel_velocity
	wall_jump_lock_timer = wall_jump_control_lock_time
	_set_attack_active(true)
	_update_facing_visual()
	animated_sprite.play(ANIMATION_SPIN)
	_update_attack_animation()
	_refresh_attack_hits()

func _cancel_attack_for_chain() -> void:
	attack_mode = ATTACK_NONE
	attack_timer = 0.0
	heavy_attack_visual_progress = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	_reset_attack_pose()

func _end_attack() -> void:
	var ending_mode: int = attack_mode
	attack_mode = ATTACK_NONE
	attack_timer = 0.0
	heavy_attack_visual_progress = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	_reset_attack_pose()

	if ending_mode == ATTACK_GROUND_CHARGED or ending_mode == ATTACK_LIGHT_CHARGED_AIR:
		velocity.x = facing * charged_ground_end_speed
	elif ending_mode == ATTACK_HEAVY_GROUND:
		velocity.x = facing * ground_heavy_end_speed

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

func _set_impact_wave_active(active: bool) -> void:
	impact_wave_left.visible = active
	impact_wave_right.visible = active
	impact_wave_left_outline.visible = active
	impact_wave_right_outline.visible = active
	if not active:
		impact_wave_left.color = Color(impact_wave_base_color.r, impact_wave_base_color.g, impact_wave_base_color.b, 0.0)
		impact_wave_right.color = impact_wave_left.color
		impact_wave_left_outline.default_color = Color(impact_wave_outline_base_color.r, impact_wave_outline_base_color.g, impact_wave_outline_base_color.b, 0.0)
		impact_wave_right_outline.default_color = impact_wave_left_outline.default_color

func _update_impact_wave_visual() -> void:
	if heavy_ground_impact_wave_timer <= 0.0:
		if impact_wave_left.visible:
			_set_impact_wave_active(false)
		return

	var progress: float = 1.0 - (heavy_ground_impact_wave_timer / heavy_ground_impact_wave_duration)
	var width_scale: float = lerp(0.5, 1.7, progress)
	var height_scale: float = lerp(0.65, 1.15, progress)
	var alpha: float = lerp(0.65, 0.0, progress)
	var rise: float = lerp(0.0, -10.0, progress)

	impact_wave_left.position = impact_wave_left_base_position + Vector2(-16.0 * progress, rise)
	impact_wave_right.position = impact_wave_right_base_position + Vector2(16.0 * progress, rise)
	impact_wave_left_outline.position = impact_wave_left_outline_base_position + Vector2(-16.0 * progress, rise)
	impact_wave_right_outline.position = impact_wave_right_outline_base_position + Vector2(16.0 * progress, rise)
	impact_wave_left.scale = Vector2(width_scale, height_scale)
	impact_wave_right.scale = Vector2(width_scale, height_scale)
	impact_wave_left_outline.scale = Vector2(width_scale, height_scale)
	impact_wave_right_outline.scale = Vector2(width_scale, height_scale)
	impact_wave_left.color = Color(impact_wave_base_color.r, impact_wave_base_color.g, impact_wave_base_color.b, alpha)
	impact_wave_right.color = impact_wave_left.color
	impact_wave_left_outline.default_color = Color(impact_wave_outline_base_color.r, impact_wave_outline_base_color.g, impact_wave_outline_base_color.b, alpha * 1.1)
	impact_wave_right_outline.default_color = impact_wave_left_outline.default_color

func _set_attack_active(active: bool) -> void:
	hitbox.monitoring = active
	hitbox_shape.disabled = not active
	_update_hitbox_visual_visibility()
	slash_visual.color = slash_base_color if active else Color(slash_base_color.r, slash_base_color.g, slash_base_color.b, 0.0)
	slash_area_visual.color = slash_area_base_color if active else Color(slash_area_base_color.r, slash_area_base_color.g, slash_area_base_color.b, 0.0)
	slash_outline.default_color = slash_outline_base_color if active else Color(slash_outline_base_color.r, slash_outline_base_color.g, slash_outline_base_color.b, 0.0)

func _update_hitbox_visual_visibility() -> void:
	var should_show := hitbox_visuals_visible and _is_attack_active()
	slash_visual.visible = should_show
	slash_area_visual.visible = should_show
	slash_outline.visible = should_show

func _update_attack_animation() -> void:
	if not _is_attack_active():
		return

	match attack_mode:
		ATTACK_SLASH:
			_animate_normal_slash()
		ATTACK_GROUND_CHARGED:
			_animate_ground_charged_attack()
		ATTACK_HEAVY:
			_animate_heavy_attack()
		ATTACK_HEAVY_GROUND:
			_animate_ground_heavy_attack()
		ATTACK_SPIN:
			_animate_spin_attack()
		ATTACK_LIGHT_CHARGED_AIR:
			_animate_light_charged_air_attack()
		ATTACK_UPPERCUT:
			_animate_uppercut_attack()

func _animate_normal_slash() -> void:
	var progress: float = 1.0 - (attack_timer / attack_duration)
	var slash_angle: float = lerp(-0.95, 0.35, progress)
	var slash_scale: float = lerp(0.92, 1.08, sin(progress * PI))
	var alpha: float = lerp(0.9, 0.2, progress)

	hitbox_shape.position = hitbox_base_position + Vector2(28.0, 0.0)
	hitbox_shape.scale = Vector2(2.0, 1.18)
	slash_visual.position = slash_visual_base_position + Vector2(30.0, 0.0)
	slash_area_visual.position = slash_area_base_position + Vector2(32.0, 0.0)
	slash_outline.position = slash_outline_base_position + Vector2(32.0, 0.0)
	hitbox.rotation = slash_angle
	slash_visual.rotation = slash_angle
	slash_area_visual.rotation = slash_angle
	slash_outline.rotation = slash_angle
	slash_visual.scale = Vector2(slash_scale * 1.85, slash_scale * 1.05)
	slash_area_visual.scale = Vector2(lerp(1.95, 2.1, progress), lerp(1.0, 1.14, progress))
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(1.0, 0.95, 0.72, alpha)
	slash_area_visual.color = Color(1.0, 0.82, 0.32, lerp(0.42, 0.16, progress))
	slash_outline.default_color = Color(1.0, 0.94, 0.62, lerp(0.95, 0.35, progress))

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

func _animate_heavy_attack() -> void:
	var progress: float = heavy_attack_visual_progress
	var arc_angle: float = lerp(-1.42, 0.22, progress)
	var arc_offset := Vector2(cos(arc_angle) * 22.0, sin(arc_angle) * 30.0 - 6.0)
	var blade_rotation: float = arc_angle + 1.02
	var pulse: float = 1.0 + 0.05 * sin(Time.get_ticks_msec() / 55.0)

	hitbox_shape.position = Vector2(8.0, -2.0) + arc_offset
	hitbox_shape.scale = Vector2(1.28, 2.2)
	slash_visual.position = Vector2(10.0, 0.0) + arc_offset
	slash_area_visual.position = Vector2(12.0, 2.0) + arc_offset
	slash_outline.position = Vector2(12.0, 2.0) + arc_offset
	hitbox.rotation = blade_rotation
	slash_visual.rotation = blade_rotation
	slash_area_visual.rotation = blade_rotation
	slash_outline.rotation = blade_rotation
	slash_visual.scale = Vector2(1.18 * pulse, 2.0 * pulse)
	slash_area_visual.scale = Vector2(1.34, 2.32)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(0.88, 0.96, 1.0, 0.96)
	slash_area_visual.color = Color(0.35, 0.86, 1.0, 0.38)
	slash_outline.default_color = Color(0.7, 0.97, 1.0, 0.9)

func _animate_ground_heavy_attack() -> void:
	var progress: float = 1.0 - (attack_timer / ground_heavy_duration)
	var arc_angle: float = lerp(-1.42, 0.22, progress)
	var arc_offset := Vector2(cos(arc_angle) * 22.0, sin(arc_angle) * 30.0 - 6.0)
	var blade_rotation: float = arc_angle + 1.02
	var stretch: float = lerp(1.2, 1.0, progress)

	hitbox_shape.position = Vector2(8.0, -2.0) + arc_offset
	hitbox_shape.scale = Vector2(1.28, 2.2)
	slash_visual.position = Vector2(10.0, 0.0) + arc_offset
	slash_area_visual.position = Vector2(12.0, 2.0) + arc_offset
	slash_outline.position = Vector2(12.0, 2.0) + arc_offset
	hitbox.rotation = blade_rotation
	slash_visual.rotation = blade_rotation
	slash_area_visual.rotation = blade_rotation
	slash_outline.rotation = blade_rotation
	slash_visual.scale = Vector2(1.18 * stretch, 2.0 * stretch)
	slash_area_visual.scale = Vector2(1.34, 2.32)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(0.88, 0.96, 1.0, 0.98)
	slash_area_visual.color = Color(0.3, 0.84, 1.0, 0.42)
	slash_outline.default_color = Color(0.74, 0.98, 1.0, 0.95)

func _animate_light_charged_air_attack() -> void:
	_animate_ground_charged_attack()

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

func _animate_uppercut_attack() -> void:
	var progress: float = 1.0 - (attack_timer / light_uppercut_duration)
	var arc_angle: float = lerp(-0.22, -1.72, progress)
	var vertical_offset: float = lerp(6.0, -40.0, progress)
	var pulse: float = 1.0 + 0.1 * sin(progress * PI * 3.6)

	hitbox_shape.position = Vector2(10.0, vertical_offset)
	hitbox_shape.scale = Vector2(1.46, 2.58)
	slash_visual.position = Vector2(12.0, vertical_offset - 2.0)
	slash_area_visual.position = Vector2(14.0, vertical_offset - 2.0)
	slash_outline.position = Vector2(14.0, vertical_offset - 2.0)
	hitbox.rotation = arc_angle
	slash_visual.rotation = arc_angle
	slash_area_visual.rotation = arc_angle
	slash_outline.rotation = arc_angle
	slash_visual.scale = Vector2(1.22 * pulse, 2.18 * pulse)
	slash_area_visual.scale = Vector2(1.46, 2.55)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(1.0, 0.94, 0.72, 0.96)
	slash_area_visual.color = Color(1.0, 0.8, 0.24, 0.36)
	slash_outline.default_color = Color(1.0, 0.96, 0.72, 0.95)

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

	if attack_mode == ATTACK_HEAVY:
		_bounce_out_of_heavy_attack()
	elif attack_mode == ATTACK_SLASH and not is_on_floor():
		_apply_light_hit_stall()

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
	charge_visual.color = Color(1.0, lerp(0.82, 0.96, progress), lerp(0.42, 0.22, progress), alpha)
	charge_outline.default_color = Color(1.0, lerp(0.96, 0.9, progress), lerp(0.72, 0.4, progress), outline_alpha)

func _start_dash() -> void:
	if dash_timer > 0.0 or dash_cooldown_timer > 0.0 or _is_attack_active():
		return

	_stop_sprint()
	long_jump_active = false
	backflip_active = false
	var move_input: float = Input.get_axis("move_left", "move_right")
	dash_direction = facing if move_input == 0.0 else (1 if move_input > 0.0 else -1)
	sprint_direction = dash_direction
	facing = dash_direction
	_update_facing_visual()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	_set_dash_visual_active(true)
	_update_dash_visual()

func _end_dash() -> void:
	_set_dash_visual_active(false)
	if Input.is_action_pressed("dash") and is_on_floor():
		_start_sprint(dash_direction)
		velocity.x = sprint_direction * sprint_speed
		return
	velocity.x = dash_direction * dash_end_speed

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
	return dash_timer > 0.0 or _uses_sprint_movement() or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_SPIN or attack_mode == ATTACK_LIGHT_CHARGED_AIR or attack_mode == ATTACK_HEAVY_GROUND or attack_mode == ATTACK_UPPERCUT

func _update_wall_state() -> void:
	if is_on_floor():
		wall_contact_direction = 0
		return

	if is_on_wall():
		wall_contact_direction = int(sign(get_wall_normal().x))
		wall_visual_direction = wall_contact_direction
	else:
		wall_contact_direction = 0

func _can_wall_jump() -> bool:
	return wall_contact_direction != 0 and not is_on_floor()

func _is_wall_sliding() -> bool:
	return _can_wall_jump() and velocity.y > 0.0 and attack_mode != ATTACK_HEAVY and attack_mode != ATTACK_SPIN and attack_mode != ATTACK_LIGHT_CHARGED_AIR and attack_mode != ATTACK_UPPERCUT and dash_timer <= 0.0

func _is_attack_active() -> bool:
	return attack_mode != ATTACK_NONE

func _bounce_out_of_heavy_attack() -> void:
	if attack_mode != ATTACK_HEAVY:
		return

	_cancel_attack_for_chain()
	velocity.x = -facing * charged_air_bounce_back_speed
	velocity.y = jump_velocity * heavy_bounce_vertical_ratio

func _land_heavy_attack_on_floor() -> void:
	if attack_mode != ATTACK_HEAVY:
		return

	_cancel_attack_for_chain()
	velocity.x = facing * heavy_ground_impact_slide_speed
	velocity.y = 0.0
	heavy_ground_impact_wave_timer = heavy_ground_impact_wave_duration
	_set_impact_wave_active(true)
	_update_impact_wave_visual()

func _apply_light_hit_stall() -> void:
	velocity.y = min(velocity.y, light_hit_stall_up_speed)

func _get_attack_damage() -> int:
	match attack_mode:
		ATTACK_GROUND_CHARGED:
			return DAMAGE_GROUND_CHARGED
		ATTACK_HEAVY:
			return DAMAGE_HEAVY
		ATTACK_HEAVY_GROUND:
			return DAMAGE_HEAVY_GROUND
		ATTACK_SPIN:
			return DAMAGE_SPIN
		ATTACK_LIGHT_CHARGED_AIR:
			return DAMAGE_LIGHT_CHARGED_AIR
		ATTACK_UPPERCUT:
			return DAMAGE_UPPERCUT
		_:
			return DAMAGE_SLASH

func _update_facing_visual() -> void:
	pivot.scale.x = facing
	animated_sprite.flip_h = facing < 0
	dash_visual.position.x = -10.0 * facing
	dash_visual.scale.x = abs(dash_visual.scale.x) * facing

func _try_start_spin_jump_cancel() -> bool:
	if attack_mode != ATTACK_SPIN or is_on_floor() or air_jumps_remaining <= 0:
		return false

	_cancel_attack_for_chain()
	air_jumps_remaining -= 1
	velocity.y = jump_velocity
	return true

func _wants_uppercut_attack() -> bool:
	return Input.is_action_pressed("move_up")

func _can_start_air_uppercut() -> bool:
	return air_uppercut_available

func _respawn_player() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = 1
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	attack_timer = 0.0
	attack_cooldown_timer = 0.0
	ground_heavy_cooldown_timer = 0.0
	charge_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	dash_direction = 1
	is_sprinting = false
	sprint_direction = 1
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	long_jump_squat_timer = 0.0
	long_jump_active = false
	backflip_active = false
	wall_jump_lock_timer = 0.0
	wall_jump_animation_timer = 0.0
	wall_contact_direction = 0
	wall_visual_direction = 0
	attack_mode = ATTACK_NONE
	is_charging_attack = false
	air_uppercut_available = true
	heavy_attack_visual_progress = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	_set_charge_visual_active(false)
	_set_dash_visual_active(false)
	heavy_ground_impact_wave_timer = 0.0
	_set_impact_wave_active(false)
	impact_wave_left.position = impact_wave_left_base_position
	impact_wave_right.position = impact_wave_right_base_position
	impact_wave_left_outline.position = impact_wave_left_outline_base_position
	impact_wave_right_outline.position = impact_wave_right_outline_base_position
	_reset_attack_pose()
	_update_facing_visual()
