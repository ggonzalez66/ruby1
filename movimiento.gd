extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal knife_changed(in_hand: bool)
signal died
signal respawned

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
const KNIFE_SCRIPT := preload("res://knife.gd")
const METATRON_SCRIPT := preload("res://metatron_cube.gd")
const CHARGE_GLOW_SHADER: Shader = preload("res://shaders/charge_glow.gdshader")
const SPRINTING_SHEET: Texture2D = preload("res://assets/sprites/player/reng_sprinting.png")
const BACKFLIP_TEXTURE: Texture2D = preload("res://assets/sprites/player/backflip rengar.png")

const CHARACTER_VISUAL_SCALE := 0.18
const CLAW_ARC_SEGMENTS := 14
const EFFECT_STROKE_COUNT := 3
const EFFECT_ARC_SEGMENTS := 16
# Capas de cada trazo de efecto: contorno, cuerpo y núcleo brillante.
const EFFECT_PALETTE_SILVER: Array[Color] = [Color(0.2, 0.22, 0.3), Color(0.74, 0.79, 0.88), Color(1.0, 1.0, 1.0)]
const EFFECT_PALETTE_GOLD: Array[Color] = [Color(0.32, 0.16, 0.03), Color(1.0, 0.7, 0.14), Color(1.0, 0.97, 0.72)]
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
const ANIMATION_BACKFLIP := &"backflip"
const ANIMATION_FRONTFLIP := &"frontflip"
const ANIMATION_SPRINT_BRAKE := &"sprint_brake"
const ANIMATION_LIGHT_HIT_2 := &"light_hit_2"
const ANIMATION_LIGHT_FINISHER := &"light_finisher"
const ANIMATION_ROAR := &"roar"
const ANIMATION_MANTLE := &"mantle"
const ANIMATION_WALLRIDE := &"wallride"
const ANIMATION_KNIFE_THROW := &"knife_throw"
const LIGHT_FINISHER_CENTER_OFFSET := Vector2(12.0, 0.0)

# Los sprites están dibujados a tamaños distintos; este factor los iguala al de idle/walk.
const ANIMATION_VISUAL_SCALES := {
	ANIMATION_IDLE: 1.0,
	ANIMATION_WALK: 1.0,
	ANIMATION_JUMP: 1.0,
	ANIMATION_SPIN: 1.05,
	ANIMATION_UPPERCUT: 1.2,
	ANIMATION_CHARGE_IDLE: 1.2,
	ANIMATION_WALL_SLIDE: 0.92,
	ANIMATION_WALL_JUMP: 0.92,
	ANIMATION_LONG_JUMP: 0.92,
	ANIMATION_CHARGE: 0.62,
	ANIMATION_HEAVY_AERIAL: 0.48,
	ANIMATION_FALL: 0.8,
	ANIMATION_DASH: 1.2,
	ANIMATION_LIGHT_HIT: 1.25,
	ANIMATION_LIGHT_HIT_2: 1.25,
	ANIMATION_LIGHT_FINISHER: 1.25,
	ANIMATION_ROAR: 0.8,
	ANIMATION_MANTLE: 1.2,
	ANIMATION_WALLRIDE: 1.15,
	ANIMATION_KNIFE_THROW: 1.25,
	ANIMATION_GROUND_HEAVY: 1.3,
	ANIMATION_SPRINT: 1.15,
	ANIMATION_BACKFLIP: 0.8,
	ANIMATION_FRONTFLIP: 1.0,
	ANIMATION_SPRINT_BRAKE: 1.2,
}

const ATTACK_NONE := 0
const ATTACK_SLASH := 1
const ATTACK_GROUND_CHARGED := 2
const ATTACK_HEAVY := 3
const ATTACK_SPIN := 4
const ATTACK_LIGHT_CHARGED_AIR := 5
const ATTACK_HEAVY_GROUND := 6
const ATTACK_UPPERCUT := 7

const DAMAGE_SLASH := 1
const DAMAGE_SLASH_FINISHER := 2
const DAMAGE_GROUND_CHARGED := 3
const DAMAGE_HEAVY := 2
const DAMAGE_SPIN := 2
const DAMAGE_LIGHT_CHARGED_AIR := 3
const DAMAGE_HEAVY_GROUND := 3
const DAMAGE_UPPERCUT := 3
const DAMAGE_WALL_EXPLOSION := 2

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
@export var claw_arc_center := Vector2(4.0, 0.0)
@export var claw_inner_radius := 24.0
@export var claw_outer_radius := 60.0
@export var claw_start_angle_degrees := -80.0
@export var claw_end_angle_degrees := 65.0
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
@export var light_hit_air_boost := -230.0
@export var light_combo_window := 0.3
@export var light_finisher_duration := 0.22
@export var light_finisher_cooldown := 0.38
@export var light_finisher_scale := 1.55
@export var light_hit_scale := 1.3
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
@export var long_jump_squat_duration := 0.0
@export var long_jump_horizontal_speed := 680.0
@export var long_jump_vertical_speed := -500.0
@export var long_jump_chain_window := 0.12
@export var max_health := 100
@export var hitstop_light := 0.05
@export var hitstop_heavy := 0.09
@export var hitstop_deflect := 0.16
# Lanzamiento estándar: desde el spawn llega al primer dummy (unos 450 px) a la altura del cuerpo.
@export var knife_throw_forward := Vector2(950.0, -260.0)
@export var knife_throw_up := Vector2(200.0, -900.0)
@export var knife_throw_diagonal_up := Vector2(650.0, -700.0)
@export var knife_throw_diagonal_down := Vector2(850.0, 250.0)
@export var knife_throw_down := Vector2(0.0, 1100.0)
@export var knife_running_multiplier := 2.0
@export var mantle_max_height := 44.0
@export var mantle_forward := 14.0
@export var mantle_duration := 0.14
@export var roar_explosive_duration := 0.16
@export var riposte_duration := 1.0
# Única curación en combate: conectar el riposte (una vez por riposte, aunque golpee a varios).
@export var riposte_heal := 20
@export var roar_stall_duration := 1.0
@export var roar_lock_duration := 0.25
@export var roar_radius := 46.0
@export var roar_momentum_keep := 0.15
@export var roar_damage := 1
@export var hurt_invulnerability_time := 1.0
@export var hurt_control_lock_time := 0.25
@export var hurt_knockback := Vector2(380.0, -320.0)
@export var wall_explosion_radius := 60.0
@export var wall_explosion_duration := 0.3
@export var wallride_speed := 430.0
# El wallride sube siempre la misma distancia desde donde tocas la pared, aunque mantengas o sueltes el dash.
@export var wallride_distance := 120.0
# Al final del wallride (y en el enganche) el agarre llega más alto: ayuda para no quedarse a un pelo del borde.
@export var wallride_mantle_reach := 64.0
@export var running_wall_cling_time := 0.35
@export var running_wall_cling_slide_speed := 40.0
@export var running_wall_jump_vertical_speed := -620.0
@export var afterimage_interval := 0.06
@export var afterimage_lifetime := 0.42
@export var afterimage_color := Color(0.56, 0.24, 1.0, 1.0)
@export var afterimage_tint := 0.85
@export var afterimage_alpha := 0.7
@export var backflip_horizontal_speed := 520.0
@export var backflip_vertical_speed := -720.0
@export var backflip_chain_window := 0.16

@onready var pivot: Node2D = $Pivot
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var hitbox: Area2D = $Pivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $Pivot/Hitbox/CollisionShape2D
@onready var claw_hitbox_shape: CollisionPolygon2D = $Pivot/Hitbox/ClawShape
@onready var slash_visual: Polygon2D = $Pivot/SlashVisual
@onready var slash_area_visual: Polygon2D = $Pivot/SlashAreaVisual
@onready var slash_outline: Line2D = $Pivot/SlashOutline
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
var long_jump_chain_timer := 0.0
var backflip_active := false
var backflip_direction := 0
var backflip_elapsed := 0.0
var backflip_rotation_duration := 0.0
var backflip_chain_timer := 0.0
var frontflip_active := false
var current_health := 0
var light_combo_step := 0
var light_combo_window_timer := 0.0
var light_combo_queued := false
var jump_cut_available := false
var has_knife := true
var thrown_knife: Node2D
var knife_throw_pose_timer := 0.0
var mantle_active := false
var mantle_elapsed := 0.0
var mantle_from := Vector2.ZERO
var mantle_height := 0.0
var mantle_dir := 1
var mantle_keep_sprint := false
var roar_active := false
var roar_explosive_timer := 0.0
var roar_stall_timer := 0.0
var roar_lock_timer := 0.0
var roar_aura_on := false
var step_fx_timer := 0.0
var roar_hit_targets: Array = []
var roar_aura: Node2D
var roar_aura_spin := 0.0
var hitstop_end_msec := 0
var riposte_timer := 0.0
var dead := false
var death_spin := 0.0
var death_rest_angle := 0.0
var riposte_attack := false
var riposte_healed := false
var hitstop_token := 0
var invulnerability_timer := 0.0
var hurt_lock_timer := 0.0
var wall_cling_timer := 0.0
var wall_embedded := false
var wallride_active := false
var wallride_risen := 0.0
var wallride_target := 0.0
# Altura desde la que empezó el último salto (suelo o frontflip).
var jump_origin_y := 0.0
# Un wallride por salto desde el suelo: entre pared y pared se usa el enganche normal.
var wallride_available := true
var dash_jump_buffered := false
var wall_embed_normal := 0
var wall_cling_direction := 0
var frontflip_elapsed := 0.0
var frontflip_rotation_duration := 0.0
var afterimage_timer := 0.0
var afterimage_container: Node2D
var afterimage_material: ShaderMaterial
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
# H alterna entre los efectos de ataque (por defecto) y las hitboxes de depuración.
var show_hitbox_debug := false
var attack_effects: Node2D
var effect_strokes: Array = []

var slash_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_area_base_color := Color(1.0, 1.0, 1.0, 0.0)
var slash_outline_base_color := Color(1.0, 1.0, 1.0, 0.0)
var charge_glow_material: ShaderMaterial
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
var slash_visual_base_polygon := PackedVector2Array()
var slash_area_base_polygon := PackedVector2Array()
var slash_outline_base_points := PackedVector2Array()
var claw_hitbox_polygon := PackedVector2Array()
var claw_finisher_polygon := PackedVector2Array()

func _ready() -> void:
	add_to_group(&"player")
	current_health = max_health
	floor_snap_length = 10.0
	_configure_character_animations()
	charge_glow_material = ShaderMaterial.new()
	charge_glow_material.shader = CHARGE_GLOW_SHADER
	animated_sprite.material = charge_glow_material
	_create_afterimage_container()
	_create_roar_aura()
	air_jumps_remaining = max_air_jumps
	slash_base_color = slash_visual.color
	slash_area_base_color = slash_area_visual.color
	slash_outline_base_color = slash_outline.default_color
	dash_visual_base_color = dash_visual.color
	impact_wave_base_color = impact_wave_left.color
	impact_wave_outline_base_color = impact_wave_left_outline.default_color
	hitbox_base_position = hitbox_shape.position
	slash_visual_base_position = slash_visual.position
	slash_area_base_position = slash_area_visual.position
	slash_outline_base_position = slash_outline.position
	slash_visual_base_polygon = slash_visual.polygon
	slash_area_base_polygon = slash_area_visual.polygon
	slash_outline_base_points = slash_outline.points
	claw_hitbox_polygon = _build_claw_arc_polygon(claw_start_angle_degrees, claw_end_angle_degrees, 0.35, light_hit_scale)
	claw_finisher_polygon = _build_claw_arc_polygon(claw_start_angle_degrees - 15.0, claw_end_angle_degrees + 15.0, 0.35, light_finisher_scale, LIGHT_FINISHER_CENTER_OFFSET)
	claw_hitbox_shape.polygon = claw_hitbox_polygon
	_create_attack_effects()
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
	if dead:
		_update_death(delta)
		return
	var was_on_floor: bool = is_on_floor()
	_update_wall_state()
	var was_wall_sliding: bool = _is_wall_sliding()
	_update_timers(delta)
	var move_input: float = Input.get_axis("move_left", "move_right")

	if was_on_floor:
		coyote_timer = coyote_time
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true
	var air_jumps_before: int = air_jumps_remaining

	if Input.is_action_just_pressed("toggle_hitbox_visuals"):
		show_hitbox_debug = not show_hitbox_debug
		_update_hitbox_visual_visibility()

	if Input.is_action_just_pressed("roar"):
		_start_roar()

	if Input.is_action_just_pressed("jump"):
		if roar_active:
			# El rugido solo se cancela saltando.
			_try_roar_jump_cancel()
		elif attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_LIGHT_CHARGED_AIR:
			_start_spin_attack()
		elif _try_start_spin_jump_cancel():
			pass
		elif _try_start_running_wall_jump():
			pass
		elif _try_start_backflip_chain(move_input):
			pass
		elif _try_start_backflip_air_jump(move_input):
			pass
		elif _try_start_long_jump_chain(move_input):
			pass
		elif _try_start_frontflip(move_input):
			pass
		elif _try_start_sprint_jump(move_input):
			pass
		else:
			jump_buffer_timer = jump_buffer_time
			if dash_timer > 0.0:
				# Durante el dash el salto se guarda y sale al terminar (salto largo si sigue corriendo).
				dash_jump_buffered = true

	if Input.is_action_just_pressed("attack") and not _blocks_actions():
		_begin_attack_charge()

	if Input.is_action_just_pressed("heavy_attack"):
		# Tras un parry, el pesado cancela el rugido para contraatacar al instante.
		if roar_active and riposte_timer > 0.0:
			_end_roar()
		if not _blocks_actions():
			_start_heavy_attack()

	if Input.is_action_just_pressed("throw_knife"):
		_on_knife_input(move_input)

	if Input.is_action_just_pressed("respawn"):
		_respawn_player()
		return

	if is_charging_attack:
		_update_attack_charge(delta)
		if Input.is_action_just_released("attack"):
			_release_attack_charge(was_on_floor, was_wall_sliding)

	if Input.is_action_just_pressed("dash"):
		if roar_active and dash_cooldown_timer <= 0.0:
			# El bloqueo del rugido se cancela con salto o con dash.
			_end_roar()
		if not _blocks_actions():
			_start_dash()

	if Input.is_action_just_released("dash") and dash_timer <= 0.0:
		_stop_sprint()

	if move_input != 0.0 and not _locks_facing():
		facing = 1 if move_input > 0.0 else -1
		_update_facing_visual()

	_try_backflip_instant_run(move_input)

	if roar_active:
		if roar_explosive_timer > 0.0:
			_roar_explosive_hits()
		else:
			# Al soltar A el aura se apaga; tras un bloqueo breve Rengar queda libre
			# (saltar o hacer dash lo cancela antes).
			roar_aura_on = roar_aura_on and Input.is_action_pressed("roar")
			if not roar_aura_on and roar_lock_timer <= 0.0:
				_end_roar()
	_update_roar_aura()

	if mantle_active:
		_apply_mantle(delta)
	elif roar_active:
		_apply_roar_movement(delta)
	elif dash_timer > 0.0:
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
	elif wall_embedded:
		_apply_wall_embedded_movement(move_input)
	elif wallride_active:
		_apply_wallride(delta)
	elif wall_cling_timer > 0.0:
		_apply_running_wall_cling_movement(delta)
	elif _uses_sprint_movement():
		_apply_sprint_movement(move_input, delta)
	else:
		_apply_gravity(delta)
		_consume_jump_buffer()
		_apply_horizontal_movement(move_input, delta)

	_update_attack_animation()
	_update_charge_visual()
	_update_riposte_visual()
	_update_dash_visual()
	_update_impact_wave_visual()
	var fall_speed: float = velocity.y
	move_and_slide()
	_update_wall_state()
	_refresh_attack_hits()

	if attack_mode == ATTACK_HEAVY and is_on_floor():
		_land_heavy_attack_on_floor()
	elif attack_mode == ATTACK_HEAVY and is_on_wall():
		_embed_heavy_attack_in_wall()

	_try_start_mantle(move_input)

	if is_on_wall() and not is_on_floor() and _uses_sprint_movement():
		long_jump_active = false
		frontflip_active = false
		backflip_active = false
		_stop_sprint()
		if Input.is_action_pressed("dash") and not _is_attack_active():
			if wallride_available:
				_start_wallride()
			else:
				_start_running_wall_cling()
	elif wall_cling_timer > 0.0 and (is_on_floor() or not is_on_wall() or not Input.is_action_pressed("dash")):
		wall_cling_timer = 0.0
	elif wallride_active and (is_on_floor() or not is_on_wall()):
		wallride_active = false

	if is_on_floor():
		frontflip_active = false
		jump_cut_available = false
		wallride_available = true
		if long_jump_active:
			_land_long_jump(move_input)
		if backflip_active:
			_land_backflip(move_input)
		if Input.is_action_pressed("dash") and dash_timer <= 0.0 and not _is_attack_active() and backflip_chain_timer <= 0.0 and not roar_active and not mantle_active:
			if not is_sprinting:
				_start_sprint(_get_sprint_start_direction(move_input))
		elif not Input.is_action_pressed("dash"):
			_stop_sprint()
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true
		if jump_buffer_timer > 0.0:
			_consume_jump_buffer()

	_update_movement_fx(delta, was_on_floor, air_jumps_before, fall_speed)
	_update_afterimages(delta)
	_update_character_animation()
	_update_hurt_visual()

func _update_movement_fx(delta: float, was_on_floor: bool, air_jumps_before: int, fall_speed: float) -> void:
	var level := get_parent()
	var feet := global_position
	# Despegue desde el suelo.
	if was_on_floor and not is_on_floor() and velocity.y < -150.0:
		Fx.dust(level, feet, Vector2.UP, 7, 1.4, 1.4)
	# Salto aéreo (doble salto, frontflip, doble backflip...): anillo de aire.
	if not was_on_floor and air_jumps_remaining < air_jumps_before:
		Fx.air_ring(level, feet)
	# Aterrizaje desde cierta altura.
	if not was_on_floor and is_on_floor() and fall_speed > 380.0:
		Fx.dust(level, feet, Vector2.LEFT, 4, 1.4, 0.5)
		Fx.dust(level, feet, Vector2.RIGHT, 4, 1.4, 0.5)
	# Pasos y derrape al frenar.
	step_fx_timer = max(step_fx_timer - delta, 0.0)
	if not is_on_floor() or abs(velocity.x) <= 60.0 or step_fx_timer > 0.0:
		return
	var moving_dir: float = sign(velocity.x)
	if is_sprinting and sprint_turn_timer > 0.0:
		Fx.dust(level, feet + Vector2(moving_dir * 8.0, 0.0), Vector2(moving_dir, -0.4), 3, 1.3, 0.4)
		step_fx_timer = 0.04
	elif not _is_attack_active():
		Fx.dust(level, feet - Vector2(moving_dir * 6.0, 0.0), Vector2(-moving_dir, -0.5), 3, 1.0, 0.5)
		step_fx_timer = 0.12 if is_sprinting else 0.26

func _spawn_walljump_fx(away_direction: int) -> void:
	var point := global_position + Vector2(-away_direction * 10.0, -12.0)
	Fx.dust(get_parent(), point, Vector2(away_direction, -0.3), 8, 1.3, 0.8)

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
	_add_sheet_animation(frames, ANIMATION_LIGHT_HIT_2, LIGHT_HITS_SHEET, 2, 12.5, false, [1, 0])
	_add_sheet_animation(frames, ANIMATION_LIGHT_FINISHER, LIGHT_HITS_SHEET, 2, 9.0, false)
	_add_sheet_animation(frames, ANIMATION_KNIFE_THROW, LIGHT_HITS_SHEET, 2, 1.0, false, [1])
	# Placeholder del rugido: la pose de puño en alto.
	_add_single_frame_animation(frames, ANIMATION_ROAR, AERIAL_STALL_TEXTURE)
	# Placeholder del mantle: el frame del uppercut con el brazo estirado hacia arriba.
	_add_sheet_animation(frames, ANIMATION_MANTLE, UPPERCUT_SHEET, 3, 1.0, false, [2])
	# Wallride: la carrera girada 90° para correr pared arriba.
	_add_sheet_animation(frames, ANIMATION_WALLRIDE, SPRINTING_SHEET, 3, 16.0, true)
	_add_sheet_animation(frames, ANIMATION_GROUND_HEAVY, GROUND_HEAVY_SHEET, 2, 14.0, false)
	_add_sheet_animation(frames, ANIMATION_SPRINT, SPRINTING_SHEET, 3, 12.0, true)
	_add_sheet_animation(frames, ANIMATION_LONG_JUMP, WALLJUMP_SHEET, 2, 1.0, false, [1])
	_add_single_frame_animation(frames, ANIMATION_CHARGE, CHARGE_LIGHT_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_HEAVY_AERIAL, HEAVY_AERIAL_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_FALL, AERIAL_STALL_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_DASH, DASH_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_BACKFLIP, BACKFLIP_TEXTURE)
	_add_sheet_animation(frames, ANIMATION_FRONTFLIP, JUMPING_SHEET, 3, 8.0, false)
	_add_sheet_animation(frames, ANIMATION_SPRINT_BRAKE, UPPERCUT_SHEET, 3, 1.0, false, [0])
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
	if roar_active:
		next_animation = ANIMATION_ROAR
	elif mantle_active:
		next_animation = ANIMATION_MANTLE
	elif wallride_active:
		next_animation = ANIMATION_WALLRIDE
	elif attack_mode == ATTACK_SPIN:
		next_animation = ANIMATION_SPIN
	elif attack_mode == ATTACK_UPPERCUT:
		next_animation = ANIMATION_UPPERCUT
	elif attack_mode == ATTACK_HEAVY:
		next_animation = ANIMATION_HEAVY_AERIAL
	elif attack_mode == ATTACK_HEAVY_GROUND:
		next_animation = ANIMATION_GROUND_HEAVY
	elif attack_mode == ATTACK_SLASH:
		next_animation = _get_light_hit_animation()
	elif dash_timer > 0.0:
		next_animation = ANIMATION_DASH
	elif knife_throw_pose_timer > 0.0:
		next_animation = ANIMATION_KNIFE_THROW
	elif _is_attack_active():
		next_animation = ANIMATION_CHARGE
	elif backflip_active:
		next_animation = ANIMATION_BACKFLIP
	elif frontflip_active:
		next_animation = ANIMATION_FRONTFLIP
	elif wall_embedded:
		next_animation = ANIMATION_WALL_SLIDE
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
	elif is_sprinting and sprint_turn_timer > 0.0:
		next_animation = ANIMATION_SPRINT_BRAKE
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
	match animation_name:
		ANIMATION_BACKFLIP:
			animated_sprite.rotation = _get_flip_rotation(backflip_elapsed, backflip_rotation_duration, -facing)
		ANIMATION_FRONTFLIP:
			animated_sprite.rotation = _get_flip_rotation(frontflip_elapsed, frontflip_rotation_duration, facing)
		ANIMATION_WALLRIDE:
			# Mirando hacia la pared y girado para que los pies queden sobre ella.
			animated_sprite.rotation = -facing * PI * 0.5
		_:
			animated_sprite.rotation = 0.0
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
		ANIMATION_JUMP, ANIMATION_FRONTFLIP:
			texture_height = JUMPING_SHEET.get_height()
		ANIMATION_SPIN:
			texture_height = AERIAL_SPINNING_SHEET.get_height()
		ANIMATION_UPPERCUT, ANIMATION_CHARGE_IDLE, ANIMATION_SPRINT_BRAKE, ANIMATION_MANTLE:
			texture_height = UPPERCUT_SHEET.get_height()
		ANIMATION_WALL_SLIDE, ANIMATION_WALL_JUMP:
			texture_height = WALLJUMP_SHEET.get_height()
		ANIMATION_CHARGE:
			texture_height = CHARGE_LIGHT_TEXTURE.get_height()
		ANIMATION_HEAVY_AERIAL:
			texture_height = HEAVY_AERIAL_TEXTURE.get_height()
		ANIMATION_FALL, ANIMATION_ROAR:
			texture_height = AERIAL_STALL_TEXTURE.get_height()
		ANIMATION_DASH:
			texture_height = DASH_TEXTURE.get_height()
		ANIMATION_LIGHT_HIT, ANIMATION_LIGHT_HIT_2, ANIMATION_LIGHT_FINISHER, ANIMATION_KNIFE_THROW:
			texture_height = LIGHT_HITS_SHEET.get_height()
		ANIMATION_GROUND_HEAVY:
			texture_height = GROUND_HEAVY_SHEET.get_height()
		ANIMATION_SPRINT, ANIMATION_WALLRIDE:
			texture_height = SPRINTING_SHEET.get_height()
		ANIMATION_LONG_JUMP:
			texture_height = WALLJUMP_SHEET.get_height()
		ANIMATION_BACKFLIP:
			texture_height = BACKFLIP_TEXTURE.get_height()
	var visual_scale: float = CHARACTER_VISUAL_SCALE * ANIMATION_VISUAL_SCALES.get(animation_name, 1.0)
	animated_sprite.scale = Vector2.ONE * visual_scale
	animated_sprite.position = Vector2(0.0, -texture_height * visual_scale * 0.5)

func _update_timers(delta: float) -> void:
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	ground_heavy_cooldown_timer = max(ground_heavy_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)
	wall_jump_animation_timer = max(wall_jump_animation_timer - delta, 0.0)
	wall_cling_timer = max(wall_cling_timer - delta, 0.0)
	invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	knife_throw_pose_timer = max(knife_throw_pose_timer - delta, 0.0)
	roar_explosive_timer = max(roar_explosive_timer - delta, 0.0)
	roar_stall_timer = max(roar_stall_timer - delta, 0.0)
	roar_lock_timer = max(roar_lock_timer - delta, 0.0)
	riposte_timer = max(riposte_timer - delta, 0.0)
	if light_combo_window_timer > 0.0:
		light_combo_window_timer = max(light_combo_window_timer - delta, 0.0)
		if light_combo_window_timer == 0.0 and attack_mode != ATTACK_SLASH:
			light_combo_step = 0
	hurt_lock_timer = max(hurt_lock_timer - delta, 0.0)
	heavy_ground_impact_wave_timer = max(heavy_ground_impact_wave_timer - delta, 0.0)
	backflip_chain_timer = max(backflip_chain_timer - delta, 0.0)
	long_jump_chain_timer = max(long_jump_chain_timer - delta, 0.0)
	if backflip_active:
		backflip_elapsed += delta
	if frontflip_active:
		frontflip_elapsed += delta

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

	if velocity.y >= 0.0:
		jump_cut_available = false
	# Soltar salto solo recorta saltos normales; no frena uppercuts, rebotes ni saltos de carrera.
	if Input.is_action_just_released("jump") and jump_cut_available and velocity.y < jump_cut_velocity and attack_mode != ATTACK_HEAVY and not backflip_active and not long_jump_active:
		velocity.y = jump_cut_velocity
		jump_cut_available = false

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
		jump_cut_available = true
		jump_origin_y = global_position.y
		return

	if _can_wall_jump():
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true
		velocity.x = wall_contact_direction * wall_jump_horizontal_speed
		velocity.y = wall_jump_vertical_speed
		jump_cut_available = true
		facing = wall_contact_direction
		wall_visual_direction = wall_contact_direction
		wall_jump_lock_timer = wall_jump_control_lock_time
		wall_jump_animation_timer = wall_jump_animation_duration
		_update_facing_visual()
		_spawn_walljump_fx(wall_contact_direction)
		return

	if air_jumps_remaining <= 0:
		return

	jump_buffer_timer = 0.0
	air_jumps_remaining -= 1
	if velocity.y < jump_velocity:
		# Ya sube más rápido que un salto (p. ej. tras un uppercut): el doble salto suma un
		# empujón en vez de frenar la subida.
		velocity.y = max(velocity.y + jump_velocity * 0.35, jump_velocity * 1.9)
		jump_cut_available = false
	else:
		velocity.y = jump_velocity
		jump_cut_available = true
	animated_sprite.play(ANIMATION_JUMP)

func _apply_horizontal_movement(move_input: float, delta: float) -> void:
	if wall_jump_lock_timer > 0.0 and not is_on_floor():
		return
	if hurt_lock_timer > 0.0:
		# Tras recibir daño el retroceso manda y solo se frena con la fricción del aire.
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
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
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	if input_direction == -sprint_direction:
		# Frenando con el input mantenido hacia atrás: backflip sin girarse.
		facing = sprint_direction
		_update_facing_visual()
		_start_backflip()
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
	if long_jump_squat_duration <= 0.0:
		long_jump_squat_timer = 0.0
		_launch_long_jump()

func _launch_long_jump() -> void:
	jump_origin_y = global_position.y
	long_jump_active = true
	long_jump_chain_timer = 0.0
	frontflip_active = false
	backflip_active = false
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.x = sprint_direction * long_jump_horizontal_speed
	velocity.y = long_jump_vertical_speed
	facing = sprint_direction
	_update_facing_visual()

func _land_long_jump(move_input: float) -> void:
	long_jump_active = false
	frontflip_active = false
	long_jump_chain_timer = long_jump_chain_window
	if jump_buffer_timer > 0.0:
		_try_start_long_jump_chain(move_input)

func _try_start_long_jump_chain(move_input: float) -> bool:
	# Bunnyhop: saltar justo al aterrizar de un salto largo encadena otro al instante.
	if long_jump_chain_timer <= 0.0 or not is_on_floor() or _is_attack_active() or dash_timer > 0.0:
		return false
	if int(sign(move_input)) == -sprint_direction:
		return false
	long_jump_squat_timer = 0.0
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	_launch_long_jump()
	Stats.add("bunnyhops")
	return true

func _start_backflip() -> void:
	Stats.add("backflips")
	# El backflip viaja en contra del facing; el personaje sigue mirando hacia delante.
	backflip_direction = -facing
	sprint_direction = facing
	long_jump_squat_timer = 0.0
	long_jump_active = false
	backflip_active = true
	backflip_elapsed = 0.0
	backflip_rotation_duration = _get_backflip_airtime()
	backflip_chain_timer = 0.0
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.x = backflip_direction * backflip_horizontal_speed
	velocity.y = backflip_vertical_speed

func _get_backflip_airtime() -> float:
	return _get_flip_airtime(backflip_vertical_speed)

func _get_flip_airtime(vertical_speed: float) -> float:
	# Tiempo en el aire hasta volver a la misma altura, para que la vuelta cuadre con el salto.
	var rise_time: float = -vertical_speed / gravity
	var apex_height: float = vertical_speed * vertical_speed / (2.0 * gravity)
	var fall_time: float = sqrt(2.0 * apex_height / (gravity * fall_gravity_multiplier))
	return max(rise_time + fall_time, 0.01)

func _get_flip_rotation(elapsed: float, duration: float, spin_direction: int) -> float:
	# spin_direction positivo gira en sentido horario (frontflip mirando a la derecha).
	var progress: float = clamp(elapsed / max(duration, 0.01), 0.0, 1.0)
	return spin_direction * TAU * smoothstep(0.0, 1.0, progress)

func _try_start_frontflip(move_input: float) -> bool:
	# Doble salto durante el salto largo (o tras un running walljump): frontflip sin perder la velocidad
	# horizontal; manteniendo la dirección contraria sale un backflip hacia atrás.
	if not long_jump_active or frontflip_active or is_on_floor() or air_jumps_remaining <= 0 or _is_attack_active() or dash_timer > 0.0:
		return false
	# Si va a aterrizar enseguida, se deja el salto en el buffer para encadenar el bunnyhop.
	if velocity.y > 0.0 and test_move(global_transform, velocity * jump_buffer_time):
		return false

	if int(sign(move_input)) == -sprint_direction:
		air_jumps_remaining -= 1
		facing = sprint_direction
		_update_facing_visual()
		_start_backflip()
		return true
	_perform_frontflip()
	return true

func _perform_frontflip() -> void:
	# Salto aéreo en carrera: el mismo frontflip tanto en el salto largo como tras un rebote.
	air_jumps_remaining -= 1
	jump_origin_y = global_position.y
	frontflip_active = true
	Stats.add("frontflips")
	frontflip_elapsed = 0.0
	frontflip_rotation_duration = _get_flip_airtime(jump_velocity)
	jump_buffer_timer = 0.0
	velocity.y = jump_velocity

func _start_running_wall_cling() -> void:
	# Llegar a una pared con impulso de carrera y correr mantenido engancha sin pulsar hacia ella.
	wall_cling_direction = int(sign(get_wall_normal().x))
	if wall_cling_direction == 0:
		return
	wall_cling_timer = running_wall_cling_time
	wall_contact_direction = wall_cling_direction
	wall_visual_direction = wall_cling_direction
	velocity = Vector2(-wall_cling_direction * 60.0, 0.0)
	if jump_buffer_timer > 0.0:
		_try_start_running_wall_jump()

func _start_wallride() -> void:
	# Saltar corriendo contra una pared: sube por ella una distancia fija.
	wall_cling_direction = int(sign(get_wall_normal().x))
	if wall_cling_direction == 0:
		return
	wallride_available = false
	wallride_active = true
	wallride_risen = 0.0
	wallride_target = wallride_distance
	wall_contact_direction = wall_cling_direction
	wall_visual_direction = wall_cling_direction
	facing = -wall_cling_direction
	_update_facing_visual()
	velocity = Vector2(-wall_cling_direction * 60.0, -wallride_speed)
	if jump_buffer_timer > 0.0:
		_try_start_running_wall_jump()

func _apply_wallride(delta: float) -> void:
	# Frena al acercarse al tope; al llegar queda enganchado como en el running cling.
	var remaining: float = wallride_target - wallride_risen
	var speed: float = wallride_speed * clamp(remaining / 40.0, 0.35, 1.0)
	velocity = Vector2(-wall_cling_direction * 60.0, -speed)
	wallride_risen += speed * delta
	if wallride_risen >= wallride_target:
		wallride_active = false
		wall_cling_timer = running_wall_cling_time
		velocity.y = 0.0

func _apply_running_wall_cling_movement(delta: float) -> void:
	# Empuja contra la pared para seguir en contacto y se desliza muy despacio.
	velocity.x = -wall_cling_direction * 60.0
	velocity.y = move_toward(velocity.y, running_wall_cling_slide_speed, gravity * delta)

func _try_start_running_wall_jump() -> bool:
	if (wall_cling_timer <= 0.0 and not wallride_active) or is_on_floor() or _is_attack_active() or dash_timer > 0.0:
		return false

	wallride_active = false
	# Sale como un salto largo desde la pared: más lejos que el walljump normal y encadenable.
	var direction := wall_cling_direction
	wall_cling_timer = 0.0
	wall_contact_direction = 0
	is_sprinting = true
	sprint_direction = direction
	wall_visual_direction = direction
	wall_jump_animation_timer = wall_jump_animation_duration
	air_jumps_remaining = max_air_jumps
	air_uppercut_available = true
	_launch_long_jump()
	Stats.add("running_walljumps")
	velocity.y = running_wall_jump_vertical_speed
	_spawn_walljump_fx(direction)
	return true

func take_damage(amount: int, source_position: Vector2, attacker: Node = null) -> void:
	if dead:
		return
	if _is_roar_invincible():
		# Frames explosivos del rugido: invencible, y un ataque cuerpo a cuerpo se desvía.
		if attacker and attacker.has_method("on_deflected"):
			attacker.on_deflected(self)
			Stats.add("parries")
			_apply_hitstop(hitstop_deflect)
			# Riposte: durante un instante el siguiente ataque fuerte hace el doble de daño.
			riposte_timer = riposte_duration
		return
	if invulnerability_timer > 0.0 or current_health <= 0:
		return
	_end_roar()
	mantle_active = false

	current_health = max(current_health - amount, 0)
	Stats.add("damage_taken", amount)
	if attacker and attacker.is_in_group(&"sun"):
		Stats.add("sun_hits_taken")
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		Stats.add("deaths")
		_start_death(source_position, amount)
		return

	invulnerability_timer = hurt_invulnerability_time
	hurt_lock_timer = hurt_control_lock_time
	# Interrumpe cualquier estado de movimiento o ataque y empuja lejos del origen del daño.
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wall_embedded = false
	wallride_active = false
	if dash_timer > 0.0:
		dash_timer = 0.0
		_set_dash_visual_active(false)
	if is_charging_attack:
		is_charging_attack = false
		charge_timer = 0.0
		_set_charge_visual_active(false)
	if _is_attack_active():
		_cancel_attack_for_chain()
	var push_direction: float = sign(global_position.x - source_position.x)
	if push_direction == 0.0:
		push_direction = -facing
	velocity = Vector2(push_direction * hurt_knockback.x, hurt_knockback.y)

# ---------- Muerte

func _start_death(source_position: Vector2, amount: int) -> void:
	# Sale despedido por el golpe que lo mató: más lejos cuanto más fuerte fue.
	dead = true
	_cancel_all_states()
	var push_direction: float = sign(global_position.x - source_position.x)
	if push_direction == 0.0:
		push_direction = -facing
	var strength: float = clamp(float(amount), 8.0, 40.0)
	velocity = Vector2(push_direction * (220.0 + strength * 12.0), -(260.0 + strength * 9.0))
	death_spin = push_direction * (10.0 + strength * 0.4)
	death_rest_angle = PI * 0.5 * push_direction
	animated_sprite.play(ANIMATION_FALL)
	_align_character_animation(ANIMATION_FALL)
	animated_sprite.modulate = Color(1.0, 0.75, 0.75)
	shadow.visible = false
	died.emit()

func _update_death(delta: float) -> void:
	if Input.is_action_just_pressed("respawn"):
		_respawn_player()
		return
	# Rebota en paredes, techo y suelo; al final queda tirado de lado.
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)
	var before := velocity
	move_and_slide()
	if is_on_wall():
		velocity.x = -before.x * 0.6
		death_spin = -death_spin * 0.8
	if is_on_ceiling():
		velocity.y = abs(before.y) * 0.3
	if is_on_floor():
		if before.y > 160.0:
			velocity.y = -before.y * 0.35
			death_spin *= 0.7
		else:
			velocity.y = 0.0
			velocity.x = move_toward(velocity.x, 0.0, 1700.0 * delta)
			death_spin = move_toward(death_spin, 0.0, 30.0 * delta)
	if abs(velocity.x) < 6.0 and is_on_floor() and abs(death_spin) < 0.5:
		animated_sprite.rotation = lerp_angle(animated_sprite.rotation, death_rest_angle, 10.0 * delta)
	else:
		animated_sprite.rotation += death_spin * delta

func _cancel_all_states() -> void:
	_end_roar()
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wallride_active = false
	wall_embedded = false
	mantle_active = false
	is_charging_attack = false
	charge_timer = 0.0
	_set_charge_visual_active(false)
	if dash_timer > 0.0:
		dash_timer = 0.0
		_set_dash_visual_active(false)
	if _is_attack_active():
		_cancel_attack_for_chain()

func _update_hurt_visual() -> void:
	if invulnerability_timer <= 0.0:
		animated_sprite.modulate = Color.WHITE
		return
	var elapsed: float = hurt_invulnerability_time - invulnerability_timer
	if elapsed < 0.12:
		animated_sprite.modulate = Color(1.0, 0.35, 0.35)
	else:
		# Parpadeo mientras dura la invulnerabilidad.
		var visible_phase: bool = int(invulnerability_timer * 16.0) % 2 == 0
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 if visible_phase else 0.35)

func _blocks_actions() -> bool:
	return roar_active or mantle_active

# ---------- Hitstop e impactos

func _apply_hitstop(duration: float) -> void:
	# Congela el juego un instante al conectar; si ya hay uno activo, se queda el más largo.
	var end_msec: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if end_msec <= hitstop_end_msec:
		return
	hitstop_end_msec = end_msec
	hitstop_token += 1
	Engine.time_scale = 0.05
	# El temporizador ignora la escala de tiempo; solo el último hitstop restaura la velocidad.
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hitstop.bind(hitstop_token))

func _end_hitstop(token: int) -> void:
	if token == hitstop_token:
		Engine.time_scale = 1.0
		hitstop_end_msec = 0

func _on_attack_blocked(area: Node2D) -> void:
	# El guardián paró el golpe: chispa, retroceso y sin daño.
	Stats.add("blocked")
	var point: Vector2 = _get_target_center(area).lerp(global_position + Vector2(0.0, -14.0), 0.5)
	Fx.impact(get_parent(), point, Fx.SILVER, 1.4)
	Fx.text(get_parent(), point + Vector2(0, -30), "¡BLOQUEO!", Color(0.85, 0.9, 1.0))
	velocity.x = -facing * 260.0
	_apply_hitstop(hitstop_light + 0.03)

func _consume_riposte() -> void:
	riposte_attack = riposte_timer > 0.0
	riposte_healed = false
	riposte_timer = 0.0

func heal(amount: int) -> int:
	# Devuelve cuánto se curó de verdad (sin pasar del máximo) y lo muestra sobre Rengar.
	if dead or amount <= 0:
		return 0
	var healed: int = min(amount, max_health - current_health)
	if healed <= 0:
		return 0
	current_health += healed
	Stats.add("health_healed", healed)
	health_changed.emit(current_health, max_health)
	Fx.text(get_parent(), global_position + Vector2(0, -52), "+%d" % healed, Color(0.45, 1.0, 0.5))
	return healed

func _update_riposte_visual() -> void:
	# Brillo rojo-dorado pulsante mientras el riposte está disponible (el de carga es amarillo).
	if is_charging_attack:
		return
	if riposte_timer > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 45.0)
		charge_glow_material.set_shader_parameter("glow_color", Color(1.0, 0.35, 0.12))
		charge_glow_material.set_shader_parameter("glow_amount", lerp(0.35, 0.8, pulse))
	else:
		charge_glow_material.set_shader_parameter("glow_amount", 0.0)

func _spawn_hit_feedback(area: Node2D) -> void:
	var heavy: bool = attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_HEAVY_GROUND
	var finisher: bool = attack_mode == ATTACK_SLASH and light_combo_step == 3
	var point: Vector2 = _get_target_center(area).lerp(global_position + Vector2(0.0, -14.0), 0.35)
	if heavy and riposte_attack:
		Fx.impact(get_parent(), point, Fx.GOLD, 2.2)
		Fx.impact(get_parent(), point, Fx.ROAR, 1.4)
		Fx.text(get_parent(), point + Vector2(0, -36), "¡RIPOSTE!", Color(1.0, 0.55, 0.25))
		_apply_hitstop(hitstop_deflect)
		if not riposte_healed:
			riposte_healed = true
			heal(riposte_heal)
		return
	Fx.impact(get_parent(), point, Fx.GOLD if heavy else Fx.SILVER, 1.35 if heavy or finisher else 1.0)
	if heavy:
		_apply_hitstop(hitstop_heavy)
	elif finisher:
		_apply_hitstop(hitstop_light + 0.03)
	else:
		_apply_hitstop(hitstop_light)

func _get_target_center(target: Node2D) -> Vector2:
	var offset = target.get("impact_offset")
	return target.global_position + (offset if offset is Vector2 else Vector2.ZERO)

# ---------- Cuchillo

func _on_knife_input(move_input: float) -> void:
	if not has_knife:
		# Segunda pulsación: recall.
		if is_instance_valid(thrown_knife):
			thrown_knife.recall()
		return
	if _blocks_actions() or wall_embedded or _is_attack_active() or dash_timer > 0.0 or hurt_lock_timer > 0.0:
		return
	if is_charging_attack:
		is_charging_attack = false
		charge_timer = 0.0
		_set_charge_visual_active(false)
	var knife := KNIFE_SCRIPT.new()
	get_parent().add_child(knife)
	knife.launch(self, global_position + Vector2(facing * 12.0, -22.0), _get_knife_throw_velocity(move_input))
	thrown_knife = knife
	Stats.add("knife_throws")
	has_knife = false
	knife_throw_pose_timer = 0.15
	knife_changed.emit(false)

func _get_knife_throw_velocity(move_input: float) -> Vector2:
	var up := Input.is_action_pressed("move_up")
	var down := Input.is_action_pressed("move_down")
	var sideways := move_input != 0.0
	var throw_velocity: Vector2 = knife_throw_forward
	if up and sideways:
		throw_velocity = knife_throw_diagonal_up
	elif up:
		throw_velocity = knife_throw_up
	elif down and sideways:
		throw_velocity = knife_throw_diagonal_down
	elif down:
		throw_velocity = knife_throw_down
	var result := Vector2(throw_velocity.x * facing, throw_velocity.y)
	if is_sprinting or long_jump_active:
		# Corriendo, Rengar alcanzaría su propio cuchillo: sale el doble de rápido.
		result.x *= knife_running_multiplier
	return result

func on_knife_hit(point: Vector2) -> void:
	Fx.impact(get_parent(), point, Fx.GOLD, 1.1)
	_apply_hitstop(hitstop_light + 0.01)

func on_knife_caught() -> void:
	has_knife = true
	thrown_knife = null
	knife_changed.emit(true)

# ---------- Mantle automático

func _try_start_mantle(move_input: float) -> void:
	# Al chocar contra un borde cuya parte de arriba queda a la altura del cuerpo, se sube solo.
	if is_on_floor() or not is_on_wall() or mantle_active or roar_active or wall_embedded:
		return
	if _is_attack_active() or hurt_lock_timer > 0.0 or dash_timer > 0.0:
		return
	var normal := int(sign(get_wall_normal().x))
	if normal == 0:
		return
	var direction := -normal
	# El wallride y el enganche de carrera empujan contra la pared aunque no se pulse la dirección.
	var pushing: bool = int(sign(move_input)) == direction or _uses_sprint_movement() or velocity.x * direction > 40.0 or wallride_active or wall_cling_timer > 0.0
	if not pushing:
		return
	var reach: float = wallride_mantle_reach if wallride_active or wall_cling_timer > 0.0 else mantle_max_height
	var height := _find_mantle_height(direction, reach)
	if height < 0.0:
		return
	mantle_keep_sprint = (is_sprinting or long_jump_active or wallride_active or wall_cling_timer > 0.0) and Input.is_action_pressed("dash")
	wallride_active = false
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	mantle_active = true
	Stats.add("mantles")
	mantle_elapsed = 0.0
	mantle_from = global_position
	mantle_height = height
	mantle_dir = direction
	Fx.dust(get_parent(), global_position + Vector2(direction * 12.0, -height), Vector2(-direction, -0.6), 6, 1.2)
	facing = direction
	_update_facing_visual()
	velocity = Vector2.ZERO

func _find_mantle_height(direction: int, reach: float) -> float:
	var height := 4.0
	while height <= reach:
		if test_move(global_transform, Vector2(0.0, -height)):
			return -1.0
		var raised := global_transform.translated(Vector2(0.0, -height))
		if not test_move(raised, Vector2(direction * mantle_forward, 0.0)):
			# Hay hueco a esa altura; tiene que haber suelo debajo para apoyarse.
			var ahead := raised.translated(Vector2(direction * mantle_forward, 0.0))
			return height if test_move(ahead, Vector2(0.0, height + 6.0)) else -1.0
		height += 4.0
	return -1.0

func _apply_mantle(delta: float) -> void:
	# Primero sube pegado a la pared y después avanza sobre el borde.
	mantle_elapsed += delta
	var t: float = clamp(mantle_elapsed / mantle_duration, 0.0, 1.0)
	var rise: float = clamp(t / 0.6, 0.0, 1.0)
	var advance: float = clamp((t - 0.6) / 0.4, 0.0, 1.0)
	global_position = mantle_from + Vector2(mantle_dir * mantle_forward * advance, -(mantle_height + 1.0) * rise)
	velocity = Vector2.ZERO
	if t >= 1.0:
		mantle_active = false
		velocity = Vector2(mantle_dir * max_speed * 0.6, 40.0)
		if mantle_keep_sprint and Input.is_action_pressed("dash"):
			_start_sprint(mantle_dir)
			velocity.x = mantle_dir * sprint_speed

# ---------- Rugido (shine / deflect)

func _start_roar() -> void:
	if roar_active or mantle_active or hurt_lock_timer > 0.0 or current_health <= 0:
		return
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wall_embedded = false
	wallride_active = false
	if dash_timer > 0.0:
		dash_timer = 0.0
		_set_dash_visual_active(false)
	if is_charging_attack:
		is_charging_attack = false
		charge_timer = 0.0
		_set_charge_visual_active(false)
	if _is_attack_active():
		_cancel_attack_for_chain()
	jump_cut_available = false
	# Frena casi todo el impulso de golpe (no en seco).
	velocity *= roar_momentum_keep
	roar_active = true
	Stats.add("roars")
	roar_explosive_timer = roar_explosive_duration
	roar_lock_timer = roar_lock_duration
	roar_aura_on = true
	roar_stall_timer = 0.0 if is_on_floor() else roar_stall_duration
	roar_hit_targets.clear()
	Fx.impact(get_parent(), get_roar_center(), Fx.ROAR, 2.0)
	_roar_explosive_hits()

func _end_roar() -> void:
	roar_active = false
	roar_aura_on = false
	roar_explosive_timer = 0.0
	roar_stall_timer = 0.0
	roar_lock_timer = 0.0

func _try_roar_jump_cancel() -> void:
	var grounded: bool = is_on_floor() or coyote_timer > 0.0
	if not grounded and air_jumps_remaining <= 0:
		return
	_end_roar()
	jump_buffer_timer = 0.0
	if grounded:
		coyote_timer = 0.0
	else:
		air_jumps_remaining -= 1
	velocity.y = jump_velocity
	jump_cut_available = true
	animated_sprite.play(ANIMATION_JUMP)

func _apply_roar_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	if roar_stall_timer > 0.0 and not is_on_floor():
		# Stall en el aire durante el primer segundo del rugido.
		velocity.y = move_toward(velocity.y, 0.0, 2600.0 * delta)
	else:
		_apply_gravity(delta)

func _roar_explosive_hits() -> void:
	var circle := CircleShape2D.new()
	circle.radius = roar_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, get_roar_center())
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_any := false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target: Object = result.collider
		if target in roar_hit_targets or not target.has_method("take_hit") or not target.visible:
			continue
		roar_hit_targets.append(target)
		var direction: int = 1 if target.global_position.x >= global_position.x else -1
		target.take_hit(get_roar_center(), direction, roar_damage)
		Fx.impact(get_parent(), _get_target_center(target), Fx.ROAR, 1.0)
		hit_any = true
	if hit_any:
		_apply_hitstop(hitstop_light)

func on_projectile_reflected() -> void:
	_apply_hitstop(0.04)

func is_roar_aura_active() -> bool:
	return roar_active and (roar_explosive_timer > 0.0 or roar_aura_on)

func get_roar_center() -> Vector2:
	return global_position + Vector2(0.0, -14.0)

func _is_roar_invincible() -> bool:
	return roar_active and roar_explosive_timer > 0.0

func _create_roar_aura() -> void:
	# El aura del rugido es un Cubo de Metatrón dorado.
	roar_aura = METATRON_SCRIPT.new()
	roar_aura.outer_radius = roar_radius
	roar_aura.position = Vector2(0.0, -14.0)
	roar_aura.z_index = 1
	roar_aura.visible = false
	add_child(roar_aura)

func _update_roar_aura() -> void:
	roar_aura.visible = is_roar_aura_active()
	if not roar_aura.visible:
		roar_aura_spin = 0.0
		return
	var delta: float = get_physics_process_delta_time()
	if roar_explosive_timer > 0.0:
		# Frames explosivos: aparece al instante, derecho y a tamaño completo, con un destello.
		var progress: float = 1.0 - roar_explosive_timer / roar_explosive_duration
		roar_aura.scale = Vector2.ONE
		roar_aura.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.3, 1.2, 1.05, 1.0), 1.0 - progress)
		roar_aura_spin = 0.0
	else:
		# Aura latente (manteniendo): empieza a girar despacio y pulsa; solo devuelve proyectiles.
		var pulse: float = sin(Time.get_ticks_msec() / 110.0)
		roar_aura.scale = Vector2.ONE * (1.0 + 0.035 * pulse)
		roar_aura.modulate = Color(1.0, 1.0, 1.0, 0.7 + 0.12 * pulse)
		roar_aura_spin += 0.9 * delta
	roar_aura.rotation = roar_aura_spin

func _get_sprint_start_direction(move_input: float) -> int:
	if move_input != 0.0:
		return 1 if move_input > 0.0 else -1
	return facing

func _create_afterimage_container() -> void:
	afterimage_container = Node2D.new()
	afterimage_container.name = "PlayerAfterimages"
	_attach_afterimage_container.call_deferred()
	afterimage_material = ShaderMaterial.new()
	afterimage_material.shader = CHARGE_GLOW_SHADER
	afterimage_material.set_shader_parameter("glow_color", afterimage_color)
	afterimage_material.set_shader_parameter("glow_amount", afterimage_tint)

func _attach_afterimage_container() -> void:
	# Vive en el nivel, justo antes del jugador: las sombras se quedan donde se crearon
	# y se dibujan detrás de Rengar pero delante del escenario.
	var level := get_parent()
	level.add_child(afterimage_container)
	level.move_child(afterimage_container, get_index())

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(afterimage_container):
		afterimage_container.queue_free()

func _update_afterimages(delta: float) -> void:
	afterimage_timer = max(afterimage_timer - delta, 0.0)
	# Sombras estilo Alucard a partir de la velocidad de carrera; el backflip es la excepción.
	var fast_enough: bool = abs(velocity.x) >= sprint_speed - 1.0 or backflip_active or wallride_active
	if not fast_enough or afterimage_timer > 0.0 or not afterimage_container.is_inside_tree():
		return
	afterimage_timer = afterimage_interval
	_spawn_afterimage()

func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.flip_h = animated_sprite.flip_h
	ghost.material = afterimage_material
	ghost.modulate = Color(1.0, 1.0, 1.0, afterimage_alpha)
	afterimage_container.add_child(ghost)
	ghost.global_transform = animated_sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, afterimage_lifetime)
	tween.tween_callback(ghost.queue_free)

func _land_backflip(move_input: float) -> void:
	backflip_active = false
	backflip_direction = 0
	_stop_sprint()
	backflip_chain_timer = backflip_chain_window
	if jump_buffer_timer > 0.0 and _try_start_backflip_chain(move_input):
		return
	_try_backflip_instant_run(move_input)

func _try_start_backflip_chain(move_input: float) -> bool:
	if backflip_chain_timer <= 0.0 or not is_on_floor() or _is_attack_active() or dash_timer > 0.0:
		return false
	if int(sign(move_input)) != -facing:
		return false
	_start_backflip()
	return true

func _try_start_backflip_air_jump(move_input: float) -> bool:
	if not backflip_active or is_on_floor() or air_jumps_remaining <= 0 or _is_attack_active() or dash_timer > 0.0:
		return false

	air_jumps_remaining -= 1
	if int(sign(move_input)) == -facing:
		# Doble backflip: mantiene el facing y reinicia el giro.
		_start_backflip()
		return true

	if int(sign(move_input)) == facing:
		# Hacia delante: el frontflip de siempre, a velocidad de carrera hacia donde mira.
		backflip_active = false
		backflip_direction = 0
		air_jumps_remaining += 1
		if Input.is_action_pressed("dash"):
			_start_sprint(facing)
		velocity.x = facing * sprint_speed
		_perform_frontflip()
		return true

	# Doble salto normal: sale del backflip conservando el impulso hacia atrás.
	backflip_active = false
	backflip_direction = 0
	_stop_sprint()
	jump_buffer_timer = 0.0
	velocity.y = jump_velocity
	animated_sprite.play(ANIMATION_JUMP)
	return true

func _try_backflip_instant_run(move_input: float) -> void:
	if backflip_chain_timer <= 0.0 or not is_on_floor() or _is_attack_active() or dash_timer > 0.0:
		return
	if int(sign(move_input)) != facing:
		return
	backflip_chain_timer = 0.0
	if Input.is_action_pressed("dash"):
		_start_sprint(facing)
		velocity.x = facing * sprint_speed
	else:
		velocity.x = facing * max_speed

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
		velocity.x = backflip_direction * backflip_horizontal_speed
		_apply_gravity(delta)
		return

	if not is_on_floor():
		# En el aire corriendo (p. ej. tras rebotar con el heavy) se conserva el impulso
		# hacia delante y se puede usar el salto aéreo.
		velocity.x = sprint_direction * sprint_speed
		_apply_gravity(delta)
		_consume_sprint_air_jump()
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

func _consume_sprint_air_jump() -> void:
	if jump_buffer_timer <= 0.0 or air_jumps_remaining <= 0 or _is_attack_active():
		return
	# Manteniendo la dirección contraria, el frontflip sale hacia ese lado: gira el facing y la carrera.
	var input_direction := int(sign(Input.get_axis("move_left", "move_right")))
	if input_direction != 0 and input_direction != sprint_direction:
		sprint_direction = input_direction
		facing = input_direction
		_update_facing_visual()
		velocity.x = sprint_direction * sprint_speed
	_perform_frontflip()

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
	var combo_open: bool = light_combo_window_timer > 0.0 and light_combo_step < 3
	if is_charging_attack or dash_timer > 0.0 or (attack_cooldown_timer > 0.0 and not _is_attack_active() and not combo_open):
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
		elif was_on_floor:
			_start_ground_charged_attack()
		else:
			_start_light_charged_air_attack()
		return

	if attack_mode == ATTACK_SLASH:
		# Pulsado durante un golpe del combo: el siguiente sale en cuanto termine este.
		if light_combo_step < 3:
			light_combo_queued = true
		return
	if _is_attack_active():
		charge_timer = 0.0
		return

	_start_attack()

func _start_attack() -> void:
	# Sin cuchillo no hay combo ligero.
	if _is_attack_active() or dash_timer > 0.0 or not has_knife:
		return

	if light_combo_window_timer > 0.0 and light_combo_step > 0 and light_combo_step < 3:
		light_combo_step += 1
	else:
		light_combo_step = 1
	light_combo_window_timer = 0.0
	light_combo_queued = false

	attack_mode = ATTACK_SLASH
	attack_targets_hit.clear()
	if light_combo_step == 3:
		attack_timer = light_finisher_duration
		attack_cooldown_timer = light_finisher_cooldown
		claw_hitbox_shape.polygon = claw_finisher_polygon
	else:
		attack_timer = attack_duration
		attack_cooldown_timer = attack_cooldown
		claw_hitbox_shape.polygon = claw_hitbox_polygon
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _get_light_hit_animation() -> StringName:
	match light_combo_step:
		2:
			return ANIMATION_LIGHT_HIT_2
		3:
			return ANIMATION_LIGHT_FINISHER
		_:
			return ANIMATION_LIGHT_HIT

func _get_light_attack_duration() -> float:
	return light_finisher_duration if light_combo_step == 3 else attack_duration

func _get_claw_angles() -> Vector2:
	# Golpe 1 de arriba abajo, golpe 2 de abajo arriba, remate más amplio.
	match light_combo_step:
		2:
			return Vector2(claw_end_angle_degrees, claw_start_angle_degrees)
		3:
			return Vector2(claw_start_angle_degrees - 15.0, claw_end_angle_degrees + 15.0)
		_:
			return Vector2(claw_start_angle_degrees, claw_end_angle_degrees)

func _get_claw_center_offset() -> Vector2:
	return LIGHT_FINISHER_CENTER_OFFSET if light_combo_step == 3 else Vector2.ZERO

func _get_claw_scale() -> float:
	return light_finisher_scale if light_combo_step == 3 else light_hit_scale

func _start_ground_charged_attack() -> void:
	_face_attack_input()
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
	if Input.is_action_pressed("move_up"):
		_try_heavy_uppercut()
		return
	var canceling_from_spin: bool = attack_mode == ATTACK_SPIN and not is_on_floor() and attack_timer <= spin_heavy_cancel_window
	# Los ataques pesados son del cuchillo: sin él no se pueden hacer.
	if dash_timer > 0.0 or is_charging_attack or not has_knife:
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
	else:
		_face_attack_input()

	attack_mode = ATTACK_HEAVY
	_consume_riposte()
	attack_timer = 0.0
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	heavy_attack_visual_progress = 0.0
	velocity.x = facing * max(abs(velocity.x + facing * charged_air_forward_speed), ground_heavy_speed)
	velocity.y = max(velocity.y, 60.0)
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _try_heavy_uppercut() -> void:
	# Pesado + arriba: uppercut sin cargar. Es la excepción que se puede hacer sin el cuchillo.
	if dash_timer > 0.0 or is_charging_attack or _is_attack_active() or attack_cooldown_timer > 0.0:
		return
	if not is_on_floor() and not _can_start_air_uppercut():
		return
	_start_uppercut_attack(not is_on_floor())

func _face_attack_input() -> void:
	# En backflip, running walljump o carrera el facing está bloqueado: mantener la dirección
	# contraria lanza el ataque hacia ese lado, y Rengar queda mirando y corriendo hacia allí.
	var input_direction := int(sign(Input.get_axis("move_left", "move_right")))
	if input_direction != 0 and input_direction != facing:
		facing = input_direction
		_update_facing_visual()
	backflip_active = false
	long_jump_active = false
	frontflip_active = false
	sprint_direction = facing
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0

func _start_ground_heavy_attack() -> void:
	if ground_heavy_cooldown_timer > 0.0:
		return

	attack_mode = ATTACK_HEAVY_GROUND
	_consume_riposte()
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
	_face_attack_input()
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
	_face_attack_input()
	attack_mode = ATTACK_UPPERCUT
	attack_timer = light_uppercut_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	if from_air:
		air_uppercut_available = false
	jump_cut_available = false
	# Sale del suelo por el uppercut: no hay coyote time que convierta el siguiente salto en uno de suelo.
	coyote_timer = 0.0
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
	light_combo_step = 0
	light_combo_window_timer = 0.0
	light_combo_queued = false
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

	if ending_mode == ATTACK_SLASH:
		if light_combo_step < 3:
			light_combo_window_timer = light_combo_window
			if light_combo_queued:
				_start_attack()
		else:
			light_combo_step = 0
		light_combo_queued = false
	elif ending_mode == ATTACK_GROUND_CHARGED or ending_mode == ATTACK_LIGHT_CHARGED_AIR:
		velocity.x = facing * charged_ground_end_speed
	elif ending_mode == ATTACK_HEAVY_GROUND:
		velocity.x = facing * ground_heavy_end_speed

func _reset_attack_pose() -> void:
	claw_hitbox_shape.disabled = true
	slash_visual.polygon = slash_visual_base_polygon
	slash_area_visual.polygon = slash_area_base_polygon
	slash_outline.points = slash_outline_base_points
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
	if active:
		frontflip_active = false
		wall_embedded = false
		wallride_active = false
	else:
		riposte_attack = false
	claw_hitbox_shape.disabled = true
	_update_hitbox_visual_visibility()
	slash_visual.color = slash_base_color if active else Color(slash_base_color.r, slash_base_color.g, slash_base_color.b, 0.0)
	slash_area_visual.color = slash_area_base_color if active else Color(slash_area_base_color.r, slash_area_base_color.g, slash_area_base_color.b, 0.0)
	slash_outline.default_color = slash_outline_base_color if active else Color(slash_outline_base_color.r, slash_outline_base_color.g, slash_outline_base_color.b, 0.0)

func _update_hitbox_visual_visibility() -> void:
	var attacking := _is_attack_active()
	var show_hitboxes := show_hitbox_debug and attacking
	slash_visual.visible = show_hitboxes
	slash_area_visual.visible = show_hitboxes
	slash_outline.visible = show_hitboxes
	if attack_effects:
		attack_effects.visible = attacking and not show_hitbox_debug

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
	_update_attack_effects()

func _create_attack_effects() -> void:
	attack_effects = Node2D.new()
	attack_effects.name = "AttackEffects"
	attack_effects.visible = false
	pivot.add_child(attack_effects)

	# Media luna afilada: nace de la nada, engorda y termina en punta.
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))
	width_curve.add_point(Vector2(0.55, 1.0))
	width_curve.add_point(Vector2(0.85, 0.75))
	width_curve.add_point(Vector2(1.0, 0.12))

	for index in range(EFFECT_STROKE_COUNT):
		effect_strokes.append([])
	# Todos los contornos primero, luego cuerpos y núcleos, para que no se tapen entre trazos.
	for layer in range(3):
		for index in range(EFFECT_STROKE_COUNT):
			var line := Line2D.new()
			line.width_curve = width_curve
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.gradient = Gradient.new()
			line.visible = false
			attack_effects.add_child(line)
			effect_strokes[index].append(line)

func _set_effect_stroke(index: int, points: PackedVector2Array, width: float, palette: Array[Color], alpha: float) -> void:
	var layers: Array = effect_strokes[index]
	if points.size() < 2 or alpha <= 0.0:
		for line in layers:
			line.visible = false
		return

	var widths: Array[float] = [width + 2.0, width, max(width * 0.35, 1.0)]
	for layer in range(3):
		var line: Line2D = layers[layer]
		var color: Color = palette[layer]
		line.visible = true
		line.points = points
		line.width = widths[layer]
		# La cola se desvanece hacia la parte más antigua del trazo.
		line.gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
		line.gradient.set_color(1, Color(color.r, color.g, color.b, alpha))

func _hide_effect_strokes(from_index: int) -> void:
	for index in range(from_index, EFFECT_STROKE_COUNT):
		_set_effect_stroke(index, PackedVector2Array(), 0.0, EFFECT_PALETTE_SILVER, 0.0)

func _effect_arc_points(center: Vector2, radius: Vector2, from_angle: float, to_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(EFFECT_ARC_SEGMENTS + 1):
		var angle: float = lerp(from_angle, to_angle, float(index) / float(EFFECT_ARC_SEGMENTS))
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _effect_fade(progress: float, fade_start: float) -> float:
	if progress <= fade_start:
		return 1.0
	return clamp(1.0 - (progress - fade_start) / (1.0 - fade_start), 0.0, 1.0)

func _update_attack_effects() -> void:
	match attack_mode:
		ATTACK_SLASH:
			_effect_claw_slash()
		ATTACK_GROUND_CHARGED, ATTACK_LIGHT_CHARGED_AIR:
			_effect_charged_lunge()
		ATTACK_UPPERCUT:
			_effect_uppercut()
		ATTACK_SPIN:
			_effect_spin()
		ATTACK_HEAVY:
			_effect_heavy_arc(heavy_attack_visual_progress, true)
		ATTACK_HEAVY_GROUND:
			_effect_heavy_arc(1.0 - (attack_timer / ground_heavy_duration), false)

func _effect_claw_slash() -> void:
	# Tres zarpazos plateados paralelos siguiendo el arco de la hitbox; el remate es más grande.
	var progress: float = 1.0 - (attack_timer / _get_light_attack_duration())
	var sweep: float = 1.0 - pow(1.0 - progress, 2.4)
	var alpha: float = _effect_fade(progress, 0.55)
	var angles: Vector2 = _get_claw_angles()
	var start_angle: float = deg_to_rad(angles.x)
	var end_angle: float = deg_to_rad(angles.y)
	var claw_scale: float = _get_claw_scale()
	var mid_radius: float = (claw_inner_radius + claw_outer_radius) * 0.5 * claw_scale
	var spacing: float = (claw_outer_radius - claw_inner_radius) * 0.3 * claw_scale
	for index in range(3):
		var lead: float = (index - 1) * 0.06
		var head: float = lerp(start_angle, end_angle, clamp(sweep + lead, 0.08, 1.0))
		var tail: float = lerp(start_angle, head, clamp(progress * 1.3 - 0.35, 0.0, 0.8))
		var radius: float = mid_radius + (index - 1) * spacing
		var width: float = (5.5 if index == 1 else 4.5) * claw_scale
		_set_effect_stroke(index, _effect_arc_points(claw_arc_center + _get_claw_center_offset(), Vector2(radius, radius), tail, head), width, EFFECT_PALETTE_SILVER, alpha)

func _effect_charged_lunge() -> void:
	# Estocada: tres garras horizontales que convergen hacia la punta.
	var progress: float = 1.0 - (attack_timer / charged_ground_duration)
	var reveal: float = 1.0 - pow(1.0 - progress, 3.0)
	var alpha: float = _effect_fade(progress, 0.6)
	var head_x: float = lerp(14.0, 84.0, reveal)
	var tail_x: float = lerp(-14.0, head_x - 24.0, clamp(progress * 1.5 - 0.5, 0.0, 1.0))
	for index in range(3):
		var base_y: float = (index - 1) * 10.0
		var points := PackedVector2Array()
		for step in range(9):
			var t: float = step / 8.0
			var x: float = lerp(tail_x, head_x, t)
			var y: float = base_y * lerp(1.0, 0.45, t) - sin(t * PI) * 3.0
			points.append(Vector2(x, y))
		var width: float = 6.0 if index == 1 else 4.5
		_set_effect_stroke(index, points, width, EFFECT_PALETTE_SILVER, alpha)

func _effect_uppercut() -> void:
	# Media luna vertical que sube por delante del personaje.
	var progress: float = 1.0 - (attack_timer / light_uppercut_duration)
	var sweep: float = 1.0 - pow(1.0 - progress, 2.0)
	var start_angle: float = deg_to_rad(60.0)
	var head: float = lerp(start_angle, deg_to_rad(-110.0), max(sweep, 0.15))
	for index in range(2):
		var radius: float = 30.0 + index * 10.0
		var width: float = 6.0 if index == 0 else 4.5
		_set_effect_stroke(index, _effect_arc_points(Vector2(6.0, -12.0), Vector2(radius, radius), start_angle, head - index * 0.12), width, EFFECT_PALETTE_SILVER, 1.0)
	_hide_effect_strokes(2)

func _effect_spin() -> void:
	# Anillo de cortes plateados que gira junto con la hitbox.
	var progress: float = 1.0 - (attack_timer / spin_attack_duration)
	var head: float = progress * TAU * 1.6
	var alpha: float = _effect_fade(progress, 0.75)
	for index in range(2):
		var radius: float = 36.0 + index * 10.0
		var stroke_head: float = head - index * 0.35
		var width: float = 6.0 if index == 0 else 4.5
		_set_effect_stroke(index, _effect_arc_points(Vector2(0.0, 4.0), Vector2(radius, radius), stroke_head - deg_to_rad(230.0), stroke_head), width, EFFECT_PALETTE_SILVER, alpha)
	_hide_effect_strokes(2)

func _effect_heavy_arc(progress: float, aerial: bool) -> void:
	# Gran tajo dorado siguiendo la elipse de la hitbox pesada.
	var start_angle := -1.42
	# Barrido rápido al principio para que el tajo se vea entero aunque el ataque dure poco.
	var sweep: float = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 2.5)
	var head: float = lerp(start_angle, 0.35, max(sweep, 0.2))
	var alpha: float = 1.0
	if aerial and progress >= 1.0:
		alpha = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 55.0)
	elif not aerial:
		alpha = _effect_fade(progress, 0.7)
	var center := Vector2(10.0, -6.0)
	_set_effect_stroke(0, _effect_arc_points(center, Vector2(48.0, 56.0), start_angle - 0.2, head), 14.0, EFFECT_PALETTE_GOLD, alpha)
	_set_effect_stroke(1, _effect_arc_points(center, Vector2(34.0, 42.0), start_angle, head - 0.1), 8.0, EFFECT_PALETTE_GOLD, alpha)

	if aerial and velocity.y > 0.0:
		# Estela de la caída en picado, apuntando en contra de la velocidad.
		var local_velocity := Vector2(velocity.x * facing, velocity.y)
		var trail_direction: Vector2 = -local_velocity.normalized()
		var streak_length: float = min(local_velocity.length() * 0.045, 64.0)
		var points := PackedVector2Array()
		for step in range(7):
			points.append(Vector2(-4.0, 4.0) + trail_direction * streak_length * (1.0 - step / 6.0))
		_set_effect_stroke(2, points, 8.0, EFFECT_PALETTE_GOLD, 0.8)
	else:
		_hide_effect_strokes(2)

func _animate_normal_slash() -> void:
	var progress: float = 1.0 - (attack_timer / _get_light_attack_duration())
	# El zarpazo barre rápido al principio y se desvanece al final.
	var sweep: float = 1.0 - pow(1.0 - progress, 2.4)
	var angles: Vector2 = _get_claw_angles()
	var sweep_end: float = lerp(angles.x, angles.y, max(sweep, 0.12))
	var sweep_start: float = lerp(angles.x, sweep_end, clamp(progress * 1.4 - 0.4, 0.0, 0.85))
	var alpha: float = lerp(0.95, 0.15, progress)

	# La hitbox cubre todo el arco desde el primer frame para que el golpe no falle.
	hitbox_shape.disabled = true
	claw_hitbox_shape.disabled = false
	hitbox.rotation = 0.0
	for visual in [slash_visual, slash_area_visual, slash_outline]:
		visual.position = Vector2.ZERO
		visual.rotation = 0.0
		visual.scale = Vector2.ONE

	var hitbox_polygon: PackedVector2Array = claw_finisher_polygon if light_combo_step == 3 else claw_hitbox_polygon
	slash_visual.polygon = _build_claw_arc_polygon(sweep_start, sweep_end, 0.85, _get_claw_scale(), _get_claw_center_offset())
	slash_area_visual.polygon = hitbox_polygon
	var outline_points := hitbox_polygon.duplicate()
	outline_points.append(hitbox_polygon[0])
	slash_outline.points = outline_points
	slash_visual.color = Color(1.0, 0.95, 0.72, alpha)
	slash_area_visual.color = Color(1.0, 0.82, 0.32, lerp(0.42, 0.16, progress))
	slash_outline.default_color = Color(1.0, 0.94, 0.62, lerp(0.95, 0.35, progress))

func _build_claw_arc_polygon(from_degrees: float, to_degrees: float, taper: float, radius_scale: float = 1.0, center_offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	# Media luna: borde exterior de ida y borde interior de vuelta, más fina en las puntas.
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var mid_radius: float = (claw_inner_radius + claw_outer_radius) * 0.5 * radius_scale
	var half_thickness: float = (claw_outer_radius - claw_inner_radius) * 0.5 * radius_scale
	for index in range(CLAW_ARC_SEGMENTS + 1):
		var t: float = float(index) / float(CLAW_ARC_SEGMENTS)
		var angle: float = deg_to_rad(lerp(from_degrees, to_degrees, t))
		var thickness: float = half_thickness * lerp(1.0, max(sin(t * PI), 0.06), taper)
		var direction := Vector2(cos(angle), sin(angle))
		outer_points.append(claw_arc_center + center_offset + direction * (mid_radius + thickness))
		inner_points.append(claw_arc_center + center_offset + direction * (mid_radius - thickness))
	inner_points.reverse()
	outer_points.append_array(inner_points)
	return outer_points

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

	if attack_mode == ATTACK_SLASH and area.has_method("try_block") and area.try_block(global_position):
		_on_attack_blocked(area)
		return

	if area.has_method("take_hit"):
		area.take_hit(global_position, facing, _get_attack_damage())
		_spawn_hit_feedback(area)

	if attack_mode == ATTACK_HEAVY:
		# Diferido: puede venir de la señal de colisión, donde no se puede desactivar la hitbox.
		_bounce_out_of_heavy_attack.call_deferred(true)
	elif attack_mode == ATTACK_SLASH and not is_on_floor():
		_apply_light_hit_air_boost()

func _on_hitbox_area_entered(area: Area2D) -> void:
	_hit_area(area)

func _set_charge_visual_active(active: bool) -> void:
	charge_glow_material.set_shader_parameter("glow_color", Color(1.0, 0.86, 0.45))
	if not active:
		charge_glow_material.set_shader_parameter("glow_amount", 0.0)

func _update_charge_visual() -> void:
	if not is_charging_attack:
		return

	var progress: float = clamp(charge_timer / attack_charge_time, 0.0, 1.0)
	# El sprite se va iluminando mientras carga y late al estar cargado del todo.
	var glow: float = lerp(0.05, 0.6, progress * progress)
	if progress >= 1.0:
		glow = 0.7 + 0.2 * sin(Time.get_ticks_msec() / 55.0)
	charge_glow_material.set_shader_parameter("glow_amount", glow)

func _start_dash() -> void:
	if dash_timer > 0.0 or dash_cooldown_timer > 0.0 or _is_attack_active():
		return

	_stop_sprint()
	long_jump_active = false
	long_jump_chain_timer = 0.0
	backflip_active = false
	backflip_chain_timer = 0.0
	wall_cling_timer = 0.0
	wall_embedded = false
	wallride_active = false
	dash_jump_buffered = false
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
	var buffered_jump := dash_jump_buffered
	dash_jump_buffered = false
	if Input.is_action_pressed("dash") and is_on_floor():
		_start_sprint(dash_direction)
		velocity.x = sprint_direction * sprint_speed
		if buffered_jump:
			_try_start_sprint_jump(Input.get_axis("move_left", "move_right"))
		return
	if not is_on_floor():
		# En el aire el dash deja a velocidad de carrera; manteniendo correr se sigue corriendo
		# (y se aterriza corriendo).
		if Input.is_action_pressed("dash"):
			_start_sprint(dash_direction)
		velocity.x = dash_direction * sprint_speed
	else:
		velocity.x = dash_direction * dash_end_speed
	if buffered_jump:
		jump_buffer_timer = jump_buffer_time

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
	return dash_timer > 0.0 or _uses_sprint_movement() or backflip_chain_timer > 0.0 or wall_cling_timer > 0.0 or wallride_active or wall_embedded or roar_active or mantle_active or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_SPIN or attack_mode == ATTACK_LIGHT_CHARGED_AIR or attack_mode == ATTACK_HEAVY_GROUND or attack_mode == ATTACK_UPPERCUT

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

func _embed_heavy_attack_in_wall() -> void:
	Stats.add("wall_embeds")
	# El cuchillo se clava en la pared: explosión en área y Rengar queda fijo, sin deslizarse.
	var normal := int(sign(get_wall_normal().x))
	if normal == 0:
		normal = -facing
	_cancel_attack_for_chain()
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wall_embedded = true
	wall_embed_normal = normal
	wall_contact_direction = normal
	wall_visual_direction = normal
	facing = -normal
	_update_facing_visual()
	velocity = Vector2.ZERO
	_trigger_wall_explosion(global_position + Vector2(-normal * 12.0, -16.0))

func _apply_wall_embedded_movement(move_input: float) -> void:
	# Empuja levemente contra la pared para seguir en contacto; sin gravedad ni deslizamiento.
	velocity = Vector2(-wall_embed_normal * 20.0, 0.0)
	if jump_buffer_timer > 0.0:
		wall_embedded = false
		wall_contact_direction = wall_embed_normal
		_consume_jump_buffer()
		return
	if int(sign(move_input)) == wall_embed_normal:
		# Pulsar hacia fuera de la pared suelta el cuchillo.
		wall_embedded = false
		velocity = Vector2(wall_embed_normal * 60.0, 0.0)

func _trigger_wall_explosion(center: Vector2) -> void:
	var circle := CircleShape2D.new()
	circle.radius = wall_explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var target: Object = result.collider
		if target and target.has_method("take_hit") and target.visible:
			var direction: int = 1 if target.global_position.x >= center.x else -1
			target.take_hit(center, direction, DAMAGE_WALL_EXPLOSION)
			Fx.impact(get_parent(), _get_target_center(target), Fx.GOLD, 1.2)
			_apply_hitstop(hitstop_heavy)
	_spawn_wall_explosion_visual(center)

func _spawn_wall_explosion_visual(center: Vector2) -> void:
	var level := get_parent()
	var burst := Node2D.new()
	level.add_child(burst)
	burst.global_position = center
	var tween := burst.create_tween().set_parallel(true)
	var duration: float = wall_explosion_duration

	if show_hitbox_debug:
		# Modo hitboxes: muestra el área exacta de la explosión.
		var area := Polygon2D.new()
		area.polygon = _circle_points(wall_explosion_radius, 24)
		area.color = Color(0.35, 0.86, 1.0, 0.35)
		burst.add_child(area)
		tween.tween_property(area, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(burst.queue_free)
		return

	var palette: Array[Color] = EFFECT_PALETTE_GOLD
	var core := Polygon2D.new()
	core.polygon = _circle_points(9.0, 16)
	core.color = palette[2]
	burst.add_child(core)
	tween.tween_property(core, "scale", Vector2.ONE * 2.4, duration * 0.35)
	tween.tween_property(core, "modulate:a", 0.0, duration * 0.35)

	var ring := Line2D.new()
	var ring_points := _circle_points(wall_explosion_radius * 0.35, 24)
	ring_points.append(ring_points[0])
	ring.points = ring_points
	ring.width = 3.0
	ring.default_color = palette[1]
	burst.add_child(ring)
	tween.tween_property(ring, "scale", Vector2.ONE * (1.0 / 0.35), duration)
	tween.tween_property(ring, "width", 0.5, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)

	for index in range(10):
		var angle: float = TAU * index / 10.0 + randf_range(-0.2, 0.2)
		var direction := Vector2(cos(angle), sin(angle))
		var length: float = randf_range(14.0, 24.0)
		var spark := Line2D.new()
		spark.points = PackedVector2Array([Vector2.ZERO, direction * length])
		spark.width = 2.5
		spark.default_color = palette[2] if index % 2 == 0 else palette[1]
		spark.position = direction * 6.0
		burst.add_child(spark)
		tween.tween_property(spark, "position", direction * wall_explosion_radius * randf_range(0.7, 1.0), duration)
		tween.tween_property(spark, "scale", Vector2.ONE * 0.3, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(burst.queue_free)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * index / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _bounce_out_of_heavy_attack(hit_enemy: bool = false) -> void:
	if attack_mode != ATTACK_HEAVY:
		return

	if hit_enemy:
		# Rebotar en un enemigo devuelve un salto aéreo, sin acumular más del máximo.
		air_jumps_remaining = min(air_jumps_remaining + 1, max_air_jumps)

	_cancel_attack_for_chain()
	long_jump_active = false
	# Sin ir corriendo, mantener correr al golpear convierte el rebote en uno de carrera: sale lanzado
	# hacia delante a velocidad de sprint y sigue corriendo (gana impulso en vez de quedarse en el sitio).
	if hit_enemy and not is_sprinting and Input.is_action_pressed("dash"):
		_start_sprint(facing)
		Stats.add("running_bounces")
	velocity.x = -facing * charged_air_bounce_back_speed
	velocity.y = jump_velocity * heavy_bounce_vertical_ratio
	jump_cut_available = false
	# El rebote siempre gira con el frontflip.
	frontflip_active = true
	frontflip_elapsed = 0.0
	frontflip_rotation_duration = _get_flip_airtime(velocity.y)

func _land_heavy_attack_on_floor() -> void:
	if attack_mode != ATTACK_HEAVY:
		return

	_cancel_attack_for_chain()
	velocity.x = facing * heavy_ground_impact_slide_speed
	velocity.y = 0.0
	heavy_ground_impact_wave_timer = heavy_ground_impact_wave_duration
	_set_impact_wave_active(true)
	_update_impact_wave_visual()

func _apply_light_hit_air_boost() -> void:
	# Cada golpe ligero que conecta en el aire da un pequeño impulso hacia arriba.
	velocity.y = min(velocity.y, light_hit_air_boost)

func _get_attack_damage() -> int:
	var multiplier := 2 if riposte_attack else 1
	match attack_mode:
		ATTACK_GROUND_CHARGED:
			return DAMAGE_GROUND_CHARGED
		ATTACK_HEAVY:
			return DAMAGE_HEAVY * multiplier
		ATTACK_HEAVY_GROUND:
			return DAMAGE_HEAVY_GROUND * multiplier
		ATTACK_SPIN:
			return DAMAGE_SPIN
		ATTACK_LIGHT_CHARGED_AIR:
			return DAMAGE_LIGHT_CHARGED_AIR
		ATTACK_UPPERCUT:
			return DAMAGE_UPPERCUT
		_:
			return DAMAGE_SLASH_FINISHER if light_combo_step == 3 else DAMAGE_SLASH

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
	dead = false
	animated_sprite.rotation = 0.0
	get_tree().call_group(&"training_dummies", &"reset_dummy")
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
	long_jump_chain_timer = 0.0
	backflip_active = false
	backflip_direction = 0
	backflip_elapsed = 0.0
	backflip_chain_timer = 0.0
	frontflip_active = false
	frontflip_elapsed = 0.0
	wall_cling_timer = 0.0
	wall_cling_direction = 0
	wall_embedded = false
	wallride_active = false
	wallride_available = true
	dash_jump_buffered = false
	mantle_active = false
	_end_roar()
	knife_throw_pose_timer = 0.0
	if is_instance_valid(thrown_knife):
		thrown_knife.queue_free()
	thrown_knife = null
	has_knife = true
	knife_changed.emit(true)
	for projectile in get_tree().get_nodes_in_group(&"projectiles"):
		projectile.queue_free()
	hitstop_end_msec = 0
	Engine.time_scale = 1.0
	current_health = max_health
	light_combo_step = 0
	light_combo_window_timer = 0.0
	light_combo_queued = false
	jump_cut_available = false
	riposte_timer = 0.0
	riposte_attack = false
	invulnerability_timer = 0.0
	hurt_lock_timer = 0.0
	animated_sprite.modulate = Color.WHITE
	health_changed.emit(current_health, max_health)
	afterimage_timer = 0.0
	for ghost in afterimage_container.get_children():
		ghost.queue_free()
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
	respawned.emit()
