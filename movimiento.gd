extends CharacterBody2D

@export var execution_duration := 0.38
@export var execution_heal := 12
@export var critical_heal := 8
@export var boss_execution_heal := 25
@export var execution_ground_exit_duration := 0.16
@export var execution_ground_exit_speed := 520.0
@export var execution_apex_flip_duration := 0.22
@export var uppercut_flip_lead_time := 0.18
@export var uppercut_flip_duration := 0.24

var execution_core: Node2D
var execution_started := false
var execution_previous_z := 0
var execution_elapsed := 0.0
var execution_aerial := false
var execution_direction := 1
var execution_keep_sprint := false
var execution_speed := 0.0
var execution_bonus := 0.0
var execution_trajectory := 0
var execution_jump_buffered := false
var execution_action := &""
var execution_ground_exit_timer := 0.0
enum ExecutionAirExit { NONE, LAUNCH, APEX_FLIP, UPPERCUT_RISE, UPPERCUT_FLIP, BOUNCE_FLIP }
var execution_air_exit := ExecutionAirExit.NONE

signal health_changed(current: int, maximum: int)
signal knife_changed(in_hand: bool)
# Se intentó un ataque que necesita el cuchillo sin tenerlo (para el aviso del HUD).
signal knife_missing
# Durabilidad del shine (para la barra vertical del HUD).
signal shine_changed(durability: float, maximum: float, broken: bool)
signal died
signal respawned

const LIQUID_LANDING_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_liquid_landing.png")
const DASH_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_liquid_dash.png")
const LIGHT_HITS_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_light_hits.png")
const LIQUID_BEAST_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_liquid_beast_v2.png")
const LIQUID_SPIN_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_liquid_ouroboros.png")
const KNIFE_SCRIPT := preload("res://knife.gd")
const METATRON_SCRIPT := preload("res://metatron_cube.gd")
const KNIFE_MISSING_CUE_SCRIPT := preload("res://knife_missing_cue.gd")
const ELECTRIC_FX_SCRIPT := preload("res://electric_fx.gd")
const MANE_EMITTER_SCRIPT := preload("res://mane_emitter.gd")
const KNIFE_SCRAPE_SCRIPT := preload("res://knife_scrape_fx.gd")
const CHARGE_GLOW_SHADER: Shader = preload("res://shaders/charge_glow.gdshader")
# Sprites nuevos (hojas en cuadrícula: celdas de ancho fijo con el borde de abajo recortado a los pies).
const STANDING_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_idle.png")
const PROUD_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_proud.png")
const WALKING_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_walk_v2.png")
const SPRINTING_ALTERNATE_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_sprint_alternate.png")
const SPRINTING_NEW_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_sprint_closed.png")
const MANTLING_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_mantle.png")
const DASH_ATTACK_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_dash_attack.png")
const CLING_WALL_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_wall_cling.png")
const WALLRUN_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_wallrun.png")
const AERIAL_STALL_NEW: Texture2D = preload("res://assets/sprites/player/viridy/viridy_aerial_stall.png")
const BACKFLIP_NEW: Texture2D = preload("res://assets/sprites/player/viridy/viridy_backflip.png")
const JUMP_OFF_WALL_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_wall_jump.png")
const JUMP_SQUAT_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_jump_squat.png")
const JUMP_AIR_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_jump.png")
# Poses sueltas recortadas al cuerpo (pies en el borde de abajo).
const ROAR_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_roar.png")
const ROAR_HOLD_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_roar_hold.png")
const BRAKE_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_brake.png")
const BRAKE_RECOVER_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_brake_recover.png")
const FRONTFLIP_TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_frontflip.png")
# Recortes de los sprites de una sola pose (recuadro del cuerpo, pies en el borde de abajo) y de los
# frames del aire (misma altura, centrados en cada cuerpo).
const AERIAL_STALL_REGION := Rect2(136, 43, 1373, 939)
const BACKFLIP_REGION := Rect2(122, 62, 1069, 1077)
const JUMP_OFF_WALL_REGION := Rect2(1160, 64, 846, 542)
const JUMP_SQUAT_REGION := Rect2(898, 271, 851, 545)
const JUMP_AIR_REGIONS := [Rect2(122, 115, 560, 545), Rect2(822, 80, 560, 545), Rect2(1536, 48, 560, 545)]
# Wallrun: frames 2 a 6 de la hoja (el 1º es la postura agachada de arranque). Cada uno recortado
# alrededor de su cuerpo con la misma altura y los pies abajo, porque en la hoja van subiendo.
const WALLRUN_REGIONS := [Rect2(324, 241, 360, 454), Rect2(688, 164, 360, 454), Rect2(1050, 144, 360, 454), Rect2(1405, 74, 360, 454), Rect2(1795, 0, 360, 454)]

const CHARACTER_VISUAL_SCALE := 0.18
const CLAW_ARC_SEGMENTS := 14
const EFFECT_STROKE_COUNT := 3
const EFFECT_ARC_SEGMENTS := 16
# Capas de cada trazo de efecto: contorno, cuerpo y núcleo brillante.
const EFFECT_PALETTE_SILVER: Array[Color] = [Color(0.2, 0.22, 0.3), Color(0.74, 0.79, 0.88), Color(1.0, 1.0, 1.0)]
const EFFECT_PALETTE_GOLD: Array[Color] = [Color(0.32, 0.16, 0.03), Color(1.0, 0.7, 0.14), Color(1.0, 0.97, 0.72)]
# El fuego del giro (screw attack) toma el color del rango de estilo: borde oscuro, llama y núcleo claro
# (ver _style_fire_palette).
# Vueltas por segundo del sprite durante el giro.
const SCREW_SPIN_TURNS_PER_SECOND := 6.0
const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"
const ANIMATION_JUMP := &"jump"
const ANIMATION_SPIN := &"spin"
const ANIMATION_UPPERCUT := &"uppercut"
const ANIMATION_WALL_SLIDE := &"wall_slide"
const ANIMATION_WALL_JUMP := &"wall_jump"
const ANIMATION_CHARGE := &"charge"
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
# Rugido mantenido (tras los frames explosivos del parry).
const ANIMATION_ROAR_HOLD := &"roar_hold"
# Tras el giro del frontflip, hasta aterrizar.
const ANIMATION_AERIAL_STALL := &"aerial_stall"
# Intermedio al terminar de frenar, antes de quedarse quieto.
const ANIMATION_BRAKE_RECOVER := &"brake_recover"
# Rugido con onda al entrar en la pose orgullosa; luego un ciclo de la pose y, en bucle, sus 2 últimos frames.
const ANIMATION_PROUD_ROAR := &"proud_roar"
const ANIMATION_PROUD_LOOP := &"proud_loop"
# Aterrizaje del heavy aéreo: la bestia cierra las fauces, solo visual.
const ANIMATION_HEAVY_LANDING := &"heavy_landing"
const ANIMATION_RUBY_CHEW := &"ruby_chew"
const ANIMATION_LIQUID_LAUNCH := &"liquid_launch"
const LIQUID_BEAST_CANVAS_SIZE := 125.0
const LIQUID_SPIN_CANVAS_SIZE := 100.0
const LIQUID_BEAST_MOUTH := Vector2(0.36, 0.22)
# Cuánto dura esa pose (menos que la onda de impacto, que sigue igual).
const HEAVY_LANDING_POSE_TIME := 0.1
# Las fauces rozan el suelo al terminar el heavy, conservando el surco del deslizamiento.
const HEAVY_LANDING_CONTACT := Vector2(42.0, -2.0)
const ANIMATION_MANTLE := &"mantle"
const ANIMATION_WALLRIDE := &"wallride"
const ANIMATION_KNIFE_THROW := &"knife_throw"
# Pose orgullosa: tras unos segundos quieto (respira y sube el medidor de estilo).
const ANIMATION_PROUD := &"proud"
# Agachado justo al despegar de un salto desde el suelo.
const ANIMATION_JUMP_SQUAT := &"jump_squat"
const LIGHT_FINISHER_CENTER_OFFSET := Vector2(12.0, 0.0)

# Los sprites están dibujados a tamaños distintos; este factor los iguala al de idle/walk.
const ANIMATION_VISUAL_SCALES := {
	ANIMATION_IDLE: 0.854,
	ANIMATION_PROUD: 0.987,
	ANIMATION_PROUD_ROAR: 0.987,
	ANIMATION_PROUD_LOOP: 0.987,
	ANIMATION_WALK: 1.05,
	ANIMATION_JUMP: 0.65,
	ANIMATION_JUMP_SQUAT: 0.556,
	ANIMATION_SPIN: 0.3,
	ANIMATION_UPPERCUT: 0.39,
	ANIMATION_WALL_SLIDE: 0.38,
	ANIMATION_WALL_JUMP: 0.687,
	ANIMATION_LONG_JUMP: 0.687,
	ANIMATION_CHARGE: 0.336,
	ANIMATION_HEAVY_AERIAL: 0.39,
	ANIMATION_FALL: 0.65,
	ANIMATION_DASH: 0.64,
	ANIMATION_LIGHT_HIT: 1.25,
	ANIMATION_LIGHT_HIT_2: 1.25,
	ANIMATION_LIGHT_FINISHER: 1.25,
	ANIMATION_ROAR: 0.384,
	ANIMATION_ROAR_HOLD: 0.384,
	ANIMATION_AERIAL_STALL: 0.42,
	ANIMATION_MANTLE: 0.74,
	ANIMATION_WALLRIDE: 0.95,
	ANIMATION_KNIFE_THROW: 1.25,
	ANIMATION_GROUND_HEAVY: 0.65,
	ANIMATION_HEAVY_LANDING: 0.65,
	ANIMATION_SPRINT: 0.655,
	ANIMATION_BACKFLIP: 0.38,
	ANIMATION_FRONTFLIP: 0.3,
	ANIMATION_SPRINT_BRAKE: 0.514,
	ANIMATION_BRAKE_RECOVER: 0.514,
}

# Flips: el frontflip da la vuelta en todo el vuelo; el backflip, un poco más rápido (y luego aerial
# stall). Desde el 2º flip seguido, cada giro va más rápido. Al acabar la vuelta, aerial stall.
const FRONTFLIP_SPIN_FRACTION := 1.0
const BACKFLIP_SPIN_FRACTION := 0.85
const CHAINED_FLIP_SPIN := 0.65
# Rugido: el grito se ve al menos este tiempo antes de pasar a la guardia.
const ROAR_SHOUT_TIME := 0.3
# Intermedio al terminar de frenar y rugido al entrar en la pose orgullosa.
const BRAKE_RECOVER_TIME := 0.2
const PROUD_ROAR_TIME := 0.7
const PROUD_FPS := 4.0
const PROUD_WAVE_COLOR := Color(0.62, 0.95, 0.6)

# Uppercut: cuánto por delante de Viridy y como mínimo cuánto más arriba deja al enemigo, cuánto tarda
# en subir y cuánto flota.
const UPPERCUT_LAUNCH_AHEAD := 46.0
const UPPERCUT_LAUNCH_HEIGHT := 200.0
const UPPERCUT_LAUNCH_RISE := 0.42
const UPPERCUT_LAUNCH_HANG := 0.4

# Buffer de combate: un ataque pulsado cuando aún no puede salir se guarda este tiempo y sale en
# cuanto pueda (p. ej. el pesado durante el giro sale al abrirse su ventana de cancelación).
const COMBO_BUFFER_TIME := 0.3
# Tras el uppercut, en el aire, el pesado o el ataque lo cancelan sin esperar al enfriamiento.
const UPPERCUT_CHAIN_WINDOW := 0.45

const ATTACK_NONE := 0
const ATTACK_SLASH := 1
const ATTACK_GROUND_CHARGED := 2
const ATTACK_HEAVY := 3
const ATTACK_SPIN := 4
const ATTACK_LIGHT_CHARGED_AIR := 5
const ATTACK_HEAVY_GROUND := 6
const ATTACK_UPPERCUT := 7

const HEAVY_ARC := 0
const HEAVY_DIAGONAL := 1
const HEAVY_DIVE := 2

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
@export var charged_attack_cooldown := 0.5
# El ataque en carrera (dash attack) no se puede repetir hasta pasado este tiempo desde que empezó.
@export var running_attack_cooldown := 0.95
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
# Trayectoria del heavy aéreo según la dirección al empezarlo (después ya no se cambia):
# sin input, el arco de siempre; abajo + adelante, diagonal hacia adelante y abajo; solo abajo, en picado.
# Diagonal a 45°: velocidad por eje al empezar, aceleración y tope (cae más rápido que el arco).
@export var heavy_diagonal_start_speed := 900.0
@export var heavy_diagonal_acceleration := 4000.0
@export var heavy_diagonal_max_speed := 1500.0
@export var heavy_dive_speed := 2000.0
# Lo rápido que la velocidad se ajusta a la trayectoria elegida (px/s²).
@export var heavy_steer_acceleration := 9000.0
@export var charged_air_bounce_back_speed := 220.0
@export var heavy_bounce_vertical_ratio := 0.8
# El rebote del heavy en picado sube más.
@export var heavy_dive_bounce_ratio := 1.35
@export var light_hit_air_boost := -230.0
@export var light_combo_window := 0.3
@export var light_finisher_duration := 0.22
@export var light_finisher_cooldown := 0.38
@export var light_finisher_scale := 1.55
@export var light_hit_scale := 1.3
@export var spin_attack_duration := 0.34
@export var spin_launch_speed := 1240.0
@export var spin_launch_boost := 220.0
@export var spin_heavy_cancel_window := 0.12
@export var light_uppercut_duration := 0.24
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
# Cada aterrizaje encadenado suma velocidad hasta romper la cadena.
@export var bunnyhop_speed_gain := 60.0
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
# Riposte: tras un parry o devolver un proyectil, el siguiente heavy o cuchillo lanzado sale potenciado
# (doble daño y cura). Lo que se use primero consume la bonificación.
@export var riposte_duration := 1.5
# El riposte conserva su daño extra; la absorción de Ruby sustituye sus curaciones.
@export var roar_stall_duration := 1.0
@export var roar_lock_duration := 0.25
@export var roar_radius := 46.0
# Parry cuerpo a cuerpo con el radio del aura del rugido (igual que los proyectiles). En false, el parry
# solo ocurre si el golpe llega al cuerpo de Rengar (como era antes).
@export var parry_uses_aura_radius := true
# Quieto este tiempo, Rengar pasa a la pose orgullosa (y el medidor de estilo sube solo).
@export var proud_delay := 4.0
# Con false (Gauntlet) no se puede reiniciar desde el checkpoint con la tecla de reinicio.
@export var respawn_enabled := true
# Bloqueo: un golpe recibido en las frames latentes del shine (sin parry) se bloquea: no quita vida,
# gasta durabilidad y empuja a Rengar (el mismo knockback para todos los ataques, por ahora), sin
# apagar el shine. Durante el empuje solo se puede hacer dash (y correr) o shine; solo un parry lo
# cancela.
# El golpe del shine (frames explosivas) no interrumpe a los enemigos: los empuja y los electrocuta.
@export var shine_push_strength := 600.0
@export var block_knockback := Vector2(640.0, -280.0)
@export var block_stun_time := 0.32
@export var block_stun_friction := 1100.0
# Durabilidad del shine: bloquear y devolver proyectiles la gastan; parrear la recupera. Se recarga
# sola al no usar el shine; si se rompe, no hay shine hasta recargar el mínimo.
@export var shine_max_durability := 100.0
@export var shine_block_cost := 25.0
@export var shine_reflect_cost := 12.0
@export var shine_parry_restore := 20.0
@export var shine_regen_rate := 14.0
@export var shine_regen_delay := 0.9
@export var shine_min_to_use := 35.0
# Perfect devolución (en las frames del parry): no gasta durabilidad y sale con más fuerza.
@export var perfect_reflect_speed := 1.5
# Rango SS: los ataques fuertes (heavy aéreo y terrestre, giro del dash attack) curan al conectar.
@export var rank_heal := 8
const SS_RANK := 5
const SSS_RANK := 6
@export var roar_momentum_keep := 0.15
# En el aire: si el rugido se suelta (o se cancela saltando) dentro de esta ventana desde que empezó
# y se mantiene correr, se recupera la velocidad de carrera que se llevaba. Parrys sin frenar.
@export var roar_air_momentum_grace := 0.4
# El rugido golpea (impacto, destello, hitstop) pero no quita vida.
@export var roar_damage := 0
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
var bunnyhop_bonus := 0.0
var bunnyhop_chain := 0
var backflip_run_direction := 0
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
var knife_missing_cue: Node2D
var knife_throw_pose_timer := 0.0
var mantle_active := false
var mantle_elapsed := 0.0
var mantle_from := Vector2.ZERO
var mantle_height := 0.0
var mantle_dir := 1
var mantle_keep_sprint := false
var roar_active := false
var roar_elapsed := 0.0
var roar_saved_speed := 0.0
var roar_saved_direction := 0
var roar_saved_long_jump := false
var roar_explosive_timer := 0.0
var roar_stall_timer := 0.0
# El rugido solo hace flotar en el aire una vez: se recupera al tocar el suelo o una pared, o al rebotar
# en un enemigo con el heavy aéreo (sin esto se podía encadenar rugidos para volar sin fin).
var roar_air_stall_available := true
var roar_lock_timer := 0.0
var roar_aura_on := false
var step_fx_timer := 0.0
var still_time := 0.0
var jump_squat_timer := 0.0
var uppercut_pose_timer := 0.0
var proud_active := false
var proud_roar_timer := 0.0
var proud_cycle_timer := 0.0
var brake_recover_timer := 0.0
# Viene frenando la carrera sin pulsar dirección: mantiene la pose hasta pararse y luego el intermedio.
var brake_pending := false
# Flips seguidos (sin volver a quedarse en el suelo): a partir del 2º giran más rápido.
var flip_streak := 0
var roar_hit_targets: Array = []
var roar_aura: Node2D
var roar_aura_spin := 0.0
var hitstop_end_msec := 0
var riposte_timer := 0.0
var block_stun_timer := 0.0
var shine_durability := 100.0
var shine_broken := false
var shine_idle_time := 0.0
var shine_tint_ratio := -1.0
var rank_heal_done := false
# Rebotes del heavy aéreo encadenados sin tocar el suelo ("REBOTE x3").
var bounce_chain := 0
var dead := false
var mane_emitter: CPUParticles2D
var screw_embers: CPUParticles2D
var knife_scrape: Node2D
var death_spin := 0.0
var death_rest_angle := 0.0
var riposte_attack := false
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
var afterimage_unstoppable_material: ShaderMaterial
# Estado imparable de Ferocity y haciendo algo con afterimage: brilla como el speed booster.
var unstoppable_glow := false
var wall_jump_lock_timer := 0.0
var wall_jump_animation_timer := 0.0
var wall_contact_direction := 0
var wall_visual_direction := 0
var attack_mode := ATTACK_NONE
# Ataque pulsado durante el dash: sale al terminarlo.
var attack_buffered := false
var combo_buffer: StringName = &""
var combo_buffer_timer := 0.0
var uppercut_chain_timer := 0.0
# Tras el uppercut (y su pose de subida) o al acabar el giro en el aire queda en aerial stall hasta
# aterrizar o hacer otra cosa.
var aerial_stall_pose := false
var running_attack_cooldown_timer := 0.0
var air_uppercut_available := true
var heavy_air_speed := 0.0
var heavy_diagonal_speed := 0.0
var heavy_trajectory := HEAVY_ARC
var heavy_attack_visual_progress := 0.0
var heavy_ground_impact_wave_timer := 0.0
var heavy_landing_pose_timer := 0.0
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
	# Melena evanescente: detrás del sprite (se dibuja antes que él).
	mane_emitter = MANE_EMITTER_SCRIPT.new()
	add_child(mane_emitter)
	move_child(mane_emitter, animated_sprite.get_index())
	_create_screw_embers()
	knife_scrape = KNIFE_SCRAPE_SCRIPT.new()
	add_child(knife_scrape)
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
	charge_glow_material.set_shader_parameter("glow_amount", 0.0)
	_set_dash_visual_active(false)
	_set_impact_wave_active(false)
	_update_character_animation()
	shine_durability = shine_max_durability
	_emit_shine_changed.call_deferred()
	RunSession.attach_player.call_deferred(self)

func _physics_process(delta: float) -> void:
	if execution_core != null:
		_update_execution(delta)
		return
	if dead:
		_update_death(delta)
		return
	var was_on_floor: bool = is_on_floor()
	_update_wall_state()
	_update_timers(delta)
	var move_input: float = Input.get_axis("move_left", "move_right")
	_interrupt_execution_air_exit()

	if was_on_floor:
		coyote_timer = coyote_time
		air_jumps_remaining = max_air_jumps
		air_uppercut_available = true
	var air_jumps_before: int = air_jumps_remaining

	if Input.is_action_just_pressed("toggle_hitbox_visuals"):
		toggle_hitbox_debug()

	if Input.is_action_just_pressed("roar"):
		_start_roar()

	var stunned: bool = block_stun_timer > 0.0
	if Input.is_action_just_pressed("jump") and not stunned:
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
		if _in_uppercut_chain():
			_request_combat_action(&"attack")
		else:
			_on_attack_input()

	if Input.is_action_just_pressed("heavy_attack"):
		# Tras un parry, el pesado cancela el rugido para contraatacar al instante.
		if roar_active and riposte_timer > 0.0:
			_end_roar()
		if not _blocks_actions():
			_request_combat_action(&"uppercut" if Input.is_action_pressed("move_up") else &"heavy")

	if combo_buffer != &"" and not _blocks_actions() and _try_combat_action(combo_buffer):
		combo_buffer = &""

	if Input.is_action_just_pressed("throw_knife") and not stunned:
		_on_knife_input(move_input)

	if Input.is_action_just_pressed("respawn") and respawn_enabled:
		_respawn_player()
		return

	if Input.is_action_just_pressed("dash"):
		if roar_active and dash_cooldown_timer <= 0.0:
			# El bloqueo del rugido se cancela con salto o con dash.
			_end_roar()
		# El dash también saca del empuje de un bloqueo.
		if not roar_active and not mantle_active:
			_start_dash()

	if Input.is_action_just_released("dash") and dash_timer <= 0.0:
		_stop_sprint()

	if move_input != 0.0 and not _locks_facing() and not stunned:
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
				_resume_roar_momentum()
	_update_roar_aura()

	if mantle_active:
		_apply_mantle(delta)
	elif block_stun_timer > 0.0 and dash_timer <= 0.0:
		_apply_block_stun_movement(delta)
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

	_update_execution_air_exit()
	_update_attack_animation()
	_destroy_projectiles_with_attack()
	_update_riposte_visual()
	_update_dash_visual()
	_update_impact_wave_visual()
	var fall_speed: float = velocity.y
	move_and_slide()
	_update_wall_state()
	_refresh_attack_hits()
	if execution_core != null:
		return

	if attack_mode == ATTACK_HEAVY and is_on_floor():
		_land_heavy_attack_on_floor()
	elif attack_mode == ATTACK_HEAVY and is_on_wall():
		_embed_heavy_attack_in_wall()

	_try_start_mantle(move_input)

	# El ataque en carrera aéreo (y su giro) contra una pared, manteniendo correr, entra en el wallride
	# sin perder el flow.
	var attack_into_wall: bool = is_on_wall() and not is_on_floor() and Input.is_action_pressed("dash") and (attack_mode == ATTACK_LIGHT_CHARGED_AIR or attack_mode == ATTACK_SPIN or attack_mode == ATTACK_UPPERCUT) and int(sign(get_wall_normal().x)) == -facing
	if attack_into_wall:
		_cancel_attack_for_chain()
	if is_on_wall() and not is_on_floor() and (_uses_sprint_movement() or attack_into_wall):
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
		bounce_chain = 0
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
		if not backflip_active and backflip_chain_timer <= 0.0 and long_jump_chain_timer <= 0.0:
			flip_streak = 0

	if is_on_floor() and not long_jump_active and long_jump_chain_timer <= 0.0:
		bunnyhop_bonus = 0.0
		bunnyhop_chain = 0
	Ferocity.update_airtime(delta, is_on_floor(), is_on_wall() or wallride_active or wall_cling_timer > 0.0 or mantle_active or wall_embedded)
	_update_movement_fx(delta, was_on_floor, air_jumps_before, fall_speed)
	_update_proud(delta, move_input)
	_update_afterimages(delta)
	_update_character_animation()
	_update_hurt_visual()

func _update_proud(delta: float, move_input: float) -> void:
	# Quieto en el suelo un rato (sin moverse, atacar, rugir ni pulsar nada): pose orgullosa, y mientras
	# dura el medidor de estilo sube solo.
	var still: bool = is_on_floor() and velocity.length() < 5.0 and move_input == 0.0 and not _is_attack_active() \
		and not roar_active and not mantle_active and dash_timer <= 0.0 and block_stun_timer <= 0.0 \
		and hurt_lock_timer <= 0.0 and not Input.is_anything_pressed()
	still_time = still_time + delta if still else 0.0
	var was_proud: bool = proud_active
	proud_active = still_time >= proud_delay
	if proud_active and not was_proud:
		_start_proud_roar()
	if proud_active:
		Ferocity.add_pride(delta)

func _start_proud_roar() -> void:
	proud_roar_timer = PROUD_ROAR_TIME
	proud_cycle_timer = PROUD_ROAR_TIME + 3.0 / PROUD_FPS
	Fx.roar_wave(get_parent(), global_position + Vector2(facing * 6.0, -40.0), global_position, PROUD_WAVE_COLOR)

func _update_movement_fx(delta: float, was_on_floor: bool, air_jumps_before: int, fall_speed: float) -> void:
	var level := get_parent()
	var feet := global_position
	# Despegue desde el suelo.
	if was_on_floor and not is_on_floor() and velocity.y < -150.0:
		Fx.dust(level, feet, Vector2.UP, 7, 1.4, 1.4)
		Sfx.play("jump")
	# Salto aéreo (doble salto, frontflip, doble backflip...): anillo de aire.
	if not was_on_floor and air_jumps_remaining < air_jumps_before:
		Fx.air_ring(level, feet)
		Sfx.play("air_jump")
	# Aterrizaje desde cierta altura.
	if not was_on_floor and is_on_floor() and fall_speed > 380.0:
		Fx.dust(level, feet, Vector2.LEFT, 4, 1.4, 0.5)
		Fx.dust(level, feet, Vector2.RIGHT, 4, 1.4, 0.5)
		Sfx.play("land", clamp((fall_speed - 380.0) / 150.0, 0.0, 4.0))
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
		Sfx.play("step", 0.0, 1.15 if is_sprinting else 1.0)

func _spawn_walljump_fx(away_direction: int) -> void:
	var point := global_position + Vector2(-away_direction * 10.0, -12.0)
	Fx.dust(get_parent(), point, Vector2(away_direction, -0.3), 8, 1.3, 0.8)
	Sfx.play("wall_jump")

func _configure_character_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# De pie: 4 frames respirando (ida y vuelta). Orgulloso: 8 frames en 2 filas, también respirando.
	_add_grid_animation(frames, ANIMATION_IDLE, STANDING_SHEET, Vector2(543, 724), 616, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0)], 5.0, true)
	# Orgulloso (hoja normalizada de 768 px): el 1er frame es el rugido de entrada; los otros 3, respirando.
	_add_grid_animation(frames, ANIMATION_PROUD_ROAR, PROUD_SHEET, Vector2(768, 768), 704, [Vector2i(0, 0)], 1.0, false)
	_add_grid_animation(frames, ANIMATION_PROUD, PROUD_SHEET, Vector2(768, 768), 704, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], PROUD_FPS, false)
	_add_grid_animation(frames, ANIMATION_PROUD_LOOP, PROUD_SHEET, Vector2(768, 768), 704, [Vector2i(2, 0), Vector2i(3, 0)], PROUD_FPS, true)
	_add_padded_animation(frames, ANIMATION_WALK, WALKING_SHEET, Vector2(480, 440), [Rect2(18, 17, 426, 408), Rect2(465, 17, 397, 408), Rect2(925, 16, 376, 409), Rect2(1356, 16, 391, 409), Rect2(21, 458, 450, 402), Rect2(471, 458, 385, 402), Rect2(913, 458, 375, 410), Rect2(1354, 458, 401, 405)], 12.0, true)
	# Salto: el agachado al despegar (pose aparte, está dibujado a otra escala) y los 3 frames del aire.
	_add_region_animation(frames, ANIMATION_JUMP_SQUAT, JUMP_SQUAT_SHEET, [JUMP_SQUAT_REGION], 1.0, false)
	_add_region_animation(frames, ANIMATION_JUMP, JUMP_AIR_SHEET, JUMP_AIR_REGIONS, 10.0, false)
	# Giro compacto de materia líquida, compartido por el screw y la captura aérea del Ruby.
	var spin_cell := LIQUID_SPIN_SHEET.get_size() * 0.5
	_add_grid_animation(frames, ANIMATION_SPIN, LIQUID_SPIN_SHEET, spin_cell, spin_cell.y, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 16.0, true)
	# Enganchado a la pared (mira hacia una pared a la derecha; ver _update_character_orientation).
	_add_single_frame_animation(frames, ANIMATION_WALL_SLIDE, CLING_WALL_TEXTURE)
	# Salto de pared y salto largo/bunnyhop: el 2º frame de despegar de la pared.
	_add_region_animation(frames, ANIMATION_WALL_JUMP, JUMP_OFF_WALL_SHEET, [JUMP_OFF_WALL_REGION], 1.0, false)
	_add_sheet_animation(frames, ANIMATION_LIGHT_HIT, LIGHT_HITS_SHEET, 2, 12.5, false)
	_add_sheet_animation(frames, ANIMATION_LIGHT_HIT_2, LIGHT_HITS_SHEET, 2, 12.5, false, [1, 0])
	_add_sheet_animation(frames, ANIMATION_LIGHT_FINISHER, LIGHT_HITS_SHEET, 2, 9.0, false)
	_add_sheet_animation(frames, ANIMATION_KNIFE_THROW, LIGHT_HITS_SHEET, 2, 1.0, false, [1])
	# Rugido (shine): el grito durante los frames explosivos y la guardia mientras se mantiene.
	_add_single_frame_animation(frames, ANIMATION_ROAR, ROAR_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_ROAR_HOLD, ROAR_HOLD_TEXTURE)
	# Aerial stall: la pose tras el giro del frontflip.
	_add_region_animation(frames, ANIMATION_AERIAL_STALL, AERIAL_STALL_NEW, [AERIAL_STALL_REGION], 1.0, false)
	# Mantle: solo el tercer frame de la hoja de trepar, recortado 4 px por lado (centrado igual) para que
	# no se cuele el borde del cuarto frame.
	_add_region_animation(frames, ANIMATION_MANTLE, MANTLING_SHEET, [Rect2(1090, 0, 535, 600)], 1.0, false)
	# Wallride: Rengar corriendo pared arriba (dibujado de pie, mirando a la pared).
	_add_region_animation(frames, ANIMATION_WALLRIDE, WALLRUN_SHEET, WALLRUN_REGIONS, 14.0, true)
	var beast_cell := LIQUID_BEAST_SHEET.get_size() * 0.5
	_add_grid_animation(frames, ANIMATION_GROUND_HEAVY, LIQUID_BEAST_SHEET, beast_cell, 588.0, [Vector2i(0, 0), Vector2i(1, 0)], 14.0, false)
	_add_padded_animation(frames, ANIMATION_HEAVY_LANDING, LIQUID_LANDING_SHEET, Vector2(1000, 450), [Rect2(77, 454, 838, 255), Rect2(946, 343, 766, 364)], 20.0, false)
	_add_grid_animation(frames, ANIMATION_RUBY_CHEW, LIQUID_BEAST_SHEET, beast_cell, 446.0, [Vector2i(0, 1), Vector2i(1, 1)], 12.0, true)
	_add_grid_animation(frames, ANIMATION_UPPERCUT, LIQUID_BEAST_SHEET, beast_cell, 588.0, [Vector2i(0, 0), Vector2i(1, 0)], 14.0, false)
	_add_grid_animation(frames, ANIMATION_LIQUID_LAUNCH, LIQUID_BEAST_SHEET, beast_cell, 588.0, [Vector2i(0, 0), Vector2i(1, 0)], 14.0, false)
	# Primera zancada: brazo lejano delante. Segunda: brazo de la hombrera delante.
	_add_padded_animation(frames, ANIMATION_SPRINT, SPRINTING_NEW_SHEET, Vector2(550, 520), [Rect2(0, 0, 523, 512), Rect2(523, 0, 518, 512), Rect2(1041, 0, 495, 512)], 16.0, true)
	_add_padded_animation(frames, ANIMATION_SPRINT, SPRINTING_ALTERNATE_SHEET, Vector2(750, 709), [Rect2(0, 0, 724, 610), Rect2(724, 0, 724, 611), Rect2(1448, 0, 724, 620)], 16.0, true, true)
	_add_region_animation(frames, ANIMATION_LONG_JUMP, JUMP_OFF_WALL_SHEET, [JUMP_OFF_WALL_REGION], 1.0, false)
	_add_single_frame_animation(frames, ANIMATION_CHARGE, DASH_ATTACK_TEXTURE)
	_add_grid_animation(frames, ANIMATION_HEAVY_AERIAL, LIQUID_BEAST_SHEET, beast_cell, 588.0, [Vector2i(0, 0), Vector2i(1, 0)], 14.0, false)
	# Caída: el último frame del aire.
	_add_region_animation(frames, ANIMATION_FALL, JUMP_AIR_SHEET, [JUMP_AIR_REGIONS[2]], 1.0, false)
	_add_padded_animation(frames, ANIMATION_DASH, DASH_TEXTURE, Vector2(1000, 500), [Rect2(33, 306, 714, 336), Rect2(785, 306, 956, 330)], 18.0, true)
	_add_region_animation(frames, ANIMATION_BACKFLIP, BACKFLIP_NEW, [BACKFLIP_REGION], 1.0, false)
	# Frontflip: la pose encogida, que gira entera (ver _update_character_orientation).
	_add_single_frame_animation(frames, ANIMATION_FRONTFLIP, FRONTFLIP_TEXTURE)
	# Frenando la carrera, y el intermedio al acabar de frenar.
	_add_single_frame_animation(frames, ANIMATION_SPRINT_BRAKE, BRAKE_TEXTURE)
	_add_single_frame_animation(frames, ANIMATION_BRAKE_RECOVER, BRAKE_RECOVER_TEXTURE)
	animated_sprite.sprite_frames = frames
	animated_sprite.frame_changed.connect(_on_character_frame_changed)
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

func _add_grid_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, cell: Vector2, crop_height: float, cells: Array, fps: float, loops: bool) -> void:
	# Hoja en cuadrícula: cada frame es una celda (columna, fila) recortada abajo a la altura de los pies,
	# para que al alinear por la base del frame los pies queden en el suelo.
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for coords in cells:
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(cell.x * coords.x, cell.y * coords.y, cell.x, crop_height)
		atlas_frame.filter_clip = true
		frames.add_frame(animation_name, atlas_frame)

func _add_region_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, regions: Array, fps: float, loops: bool) -> void:
	# Frames con regiones a medida (todas de la misma altura, con los pies en el borde de abajo).
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for region in regions:
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = region
		atlas_frame.filter_clip = true
		frames.add_frame(animation_name, atlas_frame)

func _add_padded_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, canvas: Vector2, regions: Array, fps: float, loops: bool, append: bool = false) -> void:
	# Atlas con márgenes: celdas exportadas irregulares comparten escala y apoyo sin modificar el PNG.
	if not append:
		frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for region in regions:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = region
		frame.margin = Rect2(Vector2((canvas.x - region.size.x) * 0.5, canvas.y - region.size.y), canvas - region.size)
		frame.filter_clip = true
		frames.add_frame(animation_name, frame)

func _update_character_animation() -> void:
	var next_animation: StringName
	if not is_on_floor():
		brake_pending = false
	# El aerial stall del uppercut se corta al aterrizar o al pasar a cualquier otra cosa.
	if aerial_stall_pose and (is_on_floor() or roar_active or mantle_active or wallride_active or wall_cling_timer > 0.0 \
			or wall_embedded or dash_timer > 0.0 or frontflip_active or backflip_active or long_jump_active \
			or (attack_mode != ATTACK_NONE and attack_mode != ATTACK_UPPERCUT)):
		aerial_stall_pose = false
	if roar_active:
		# El grito durante los frames explosivos (y un mínimo para que se vea); luego la guardia.
		var shouting: bool = roar_explosive_timer > 0.0 or roar_elapsed < ROAR_SHOUT_TIME
		next_animation = ANIMATION_ROAR if shouting else ANIMATION_ROAR_HOLD
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
	elif execution_ground_exit_timer > 0.0 and is_on_floor():
		next_animation = ANIMATION_RUBY_CHEW
	elif backflip_active:
		next_animation = ANIMATION_BACKFLIP if backflip_elapsed < backflip_rotation_duration else ANIMATION_AERIAL_STALL
	elif frontflip_active:
		# Tras la vuelta, el aerial stall hasta aterrizar.
		if execution_air_exit == ExecutionAirExit.UPPERCUT_RISE:
			next_animation = ANIMATION_UPPERCUT
		elif execution_air_exit == ExecutionAirExit.LAUNCH:
			next_animation = ANIMATION_LIQUID_LAUNCH
		elif frontflip_elapsed < frontflip_rotation_duration:
			next_animation = ANIMATION_FRONTFLIP
		else:
			next_animation = ANIMATION_AERIAL_STALL
	elif wall_embedded:
		next_animation = ANIMATION_WALL_SLIDE
	elif wall_jump_animation_timer > 0.0 and not is_on_floor():
		next_animation = ANIMATION_WALL_JUMP
	elif _is_wall_sliding():
		next_animation = ANIMATION_WALL_SLIDE
	elif long_jump_squat_timer > 0.0 or long_jump_active:
		next_animation = ANIMATION_LONG_JUMP
	elif jump_squat_timer > 0.0:
		next_animation = ANIMATION_JUMP_SQUAT
	elif uppercut_pose_timer > 0.0 and not is_on_floor() and velocity.y < 0.0:
		# Tras el golpe del uppercut se mantiene la pose mientras sube.
		next_animation = ANIMATION_UPPERCUT
	elif aerial_stall_pose and attack_mode == ATTACK_NONE and not is_on_floor():
		next_animation = ANIMATION_AERIAL_STALL
	elif not is_on_floor():
		next_animation = ANIMATION_FALL if velocity.y > 0.0 else ANIMATION_JUMP
	elif heavy_landing_pose_timer > 0.0:
		# Al aterrizar el heavy aéreo, la bestia cierra la mordida un instante.
		next_animation = ANIMATION_HEAVY_LANDING
	elif backflip_run_direction != 0:
		next_animation = ANIMATION_SPRINT_BRAKE
	elif is_sprinting and sprint_turn_timer > 0.0:
		next_animation = ANIMATION_SPRINT_BRAKE
	elif is_sprinting:
		next_animation = ANIMATION_SPRINT
	elif _is_braking():
		brake_pending = true
		next_animation = ANIMATION_SPRINT_BRAKE
	elif abs(velocity.x) > 10.0:
		if brake_pending and Input.get_axis("move_left", "move_right") == 0.0:
			next_animation = ANIMATION_SPRINT_BRAKE
		else:
			brake_pending = false
			next_animation = ANIMATION_WALK
	else:
		# Al acabar de frenar, un intermedio antes de quedarse quieto.
		if brake_pending:
			brake_pending = false
			brake_recover_timer = BRAKE_RECOVER_TIME
		if brake_recover_timer > 0.0:
			next_animation = ANIMATION_BRAKE_RECOVER
		elif proud_active:
			if proud_roar_timer > 0.0:
				next_animation = ANIMATION_PROUD_ROAR
			elif proud_cycle_timer > 0.0:
				next_animation = ANIMATION_PROUD
			else:
				next_animation = ANIMATION_PROUD_LOOP
		else:
			next_animation = ANIMATION_IDLE

	if animated_sprite.animation != next_animation:
		_play_animation_sfx(next_animation)
		animated_sprite.play(next_animation)
	_align_character_animation(next_animation)
	_update_character_orientation(next_animation)
	var style_color: Color = Ferocity.style_color()
	mane_emitter.follow(animated_sprite, facing, not dead, style_color)
	screw_embers.emitting = attack_mode == ATTACK_SPIN and not dead
	if screw_embers.emitting:
		_set_screw_embers_color(style_color)
	screw_embers.position = animated_sprite.position
	# La mordida arrastra energía por el suelo durante el deslizamiento.
	var contact: Vector2 = global_position + Vector2(facing * HEAVY_LANDING_CONTACT.x, HEAVY_LANDING_CONTACT.y)
	if next_animation == ANIMATION_HEAVY_LANDING and not dead:
		if knife_scrape.active:
			knife_scrape.follow(contact)
		else:
			knife_scrape.begin(contact, facing, style_color)
	elif knife_scrape.active:
		knife_scrape.end()
	shadow.visible = is_on_floor()

func _create_screw_embers() -> void:
	# Brasas del giro: chispas de fuego verde que saltan del cuerpo y se quedan atrás (en el mundo).
	screw_embers = CPUParticles2D.new()
	screw_embers.emitting = false
	screw_embers.amount = 48
	screw_embers.lifetime = 0.35
	screw_embers.local_coords = false
	screw_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	screw_embers.emission_sphere_radius = 26.0
	screw_embers.direction = Vector2(0, -1)
	screw_embers.spread = 180.0
	screw_embers.gravity = Vector2(0, -90)
	screw_embers.initial_velocity_min = 20.0
	screw_embers.initial_velocity_max = 70.0
	screw_embers.scale_amount_min = 2.0
	screw_embers.scale_amount_max = 4.0
	screw_embers.z_index = 1
	_set_screw_embers_color(Ferocity.style_color())
	add_child(screw_embers)

func _style_fire_palette(color: Color) -> Array[Color]:
	return [color.darkened(0.78), color, color.lerp(Color.WHITE, 0.7)]

func _set_screw_embers_color(color: Color) -> void:
	if screw_embers.color_ramp and screw_embers.color_ramp.get_color(1).is_equal_approx(color):
		return
	var palette: Array[Color] = _style_fire_palette(color)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([palette[2], palette[1], Color(palette[0], 0.0)])
	screw_embers.color_ramp = ramp

func _play_animation_sfx(next_animation: StringName) -> void:
	# Sonidos que empiezan con una animación (en vez de repartirlos por cada mecánica).
	match next_animation:
		ANIMATION_SPRINT_BRAKE:
			Sfx.play("skid")
		ANIMATION_WALLRIDE:
			Sfx.play("wallride")
		ANIMATION_MANTLE, ANIMATION_WALL_SLIDE:
			Sfx.play("grab")
		ANIMATION_DASH:
			Sfx.play("dash")
		ANIMATION_HEAVY_LANDING:
			Sfx.play("heavy_land")
		ANIMATION_PROUD_ROAR:
			Sfx.play("growl")

func _is_braking() -> bool:
	# Frenando la carrera en el suelo: ya no corre pero aún va más rápido que andando.
	return is_on_floor() and not is_sprinting and abs(velocity.x) > max_speed + 15.0

func _update_character_orientation(animation_name: StringName) -> void:
	match animation_name:
		ANIMATION_UPPERCUT:
			animated_sprite.rotation = -facing * deg_to_rad(75.0)
		ANIMATION_LIQUID_LAUNCH:
			animated_sprite.rotation = facing * atan2(velocity.y, maxf(absf(velocity.x), 1.0))
		ANIMATION_HEAVY_AERIAL:
			var angle := atan2(maxf(velocity.y, 60.0), maxf(absf(velocity.x), 1.0))
			animated_sprite.rotation = facing * clampf(angle, 0.15, PI * 0.5)
		ANIMATION_BACKFLIP:
			animated_sprite.rotation = _get_flip_rotation(backflip_elapsed, backflip_rotation_duration, -facing)
		ANIMATION_FRONTFLIP:
			animated_sprite.rotation = _get_flip_rotation(frontflip_elapsed, frontflip_rotation_duration, facing)
		ANIMATION_SPIN:
			var spin_elapsed: float = spin_attack_duration - attack_timer if attack_mode == ATTACK_SPIN else 0.0
			animated_sprite.rotation = facing * spin_elapsed * TAU * SCREW_SPIN_TURNS_PER_SECOND
		_:
			animated_sprite.rotation = 0.0
	if animation_name == ANIMATION_WALL_SLIDE:
		# El sprite de enganche mira hacia una pared a la derecha (normal hacia la izquierda).
		animated_sprite.flip_h = wall_visual_direction > 0
		return
	if animation_name == ANIMATION_WALL_JUMP:
		# El frame del salto de pared sale desde una pared a la izquierda, en dirección contraria.
		animated_sprite.flip_h = wall_visual_direction < 0
		return
	animated_sprite.flip_h = facing < 0

func _on_character_frame_changed() -> void:
	# Las dos hojas de carrera tienen resoluciones diferentes: se normaliza al cambiar la pose.
	if animated_sprite.animation == ANIMATION_SPRINT:
		_align_character_animation(ANIMATION_SPRINT)

func _align_character_animation(animation_name: StringName) -> void:
	# La base del frame (sus pies) va en el origen de Rengar: se usa el alto del frame actual.
	var frame: int = animated_sprite.frame if animation_name == ANIMATION_SPRINT and animated_sprite.animation == animation_name else 0
	var texture := animated_sprite.sprite_frames.get_frame_texture(animation_name, frame)
	var texture_height: float = texture.get_height() if texture else 0.0
	var visual_scale: float = CHARACTER_VISUAL_SCALE * ANIMATION_VISUAL_SCALES.get(animation_name, 1.0)
	animated_sprite.scale = Vector2.ONE * visual_scale
	animated_sprite.position = Vector2(0.0, -texture_height * visual_scale * 0.5)
	if animation_name in [ANIMATION_GROUND_HEAVY, ANIMATION_HEAVY_AERIAL, ANIMATION_HEAVY_LANDING, ANIMATION_DASH, ANIMATION_RUBY_CHEW, ANIMATION_UPPERCUT, ANIMATION_LIQUID_LAUNCH]:
		animated_sprite.scale = Vector2.ONE * LIQUID_BEAST_CANVAS_SIZE / texture.get_width()
		animated_sprite.position = Vector2(0.0, -texture_height * animated_sprite.scale.y * 0.5)
	elif animation_name in [ANIMATION_WALK, ANIMATION_SPRINT]:
		animated_sprite.scale = Vector2.ONE * (0.175 if animation_name == ANIMATION_WALK else CHARACTER_VISUAL_SCALE * 550.0 / texture.get_width())
		animated_sprite.position = Vector2(0.0, -texture_height * animated_sprite.scale.y * 0.5)
	elif animation_name == ANIMATION_SPIN:
		animated_sprite.scale = Vector2.ONE * LIQUID_SPIN_CANVAS_SIZE / texture.get_width()
		animated_sprite.position = Vector2(0.0, -33.0)

func _update_timers(delta: float) -> void:
	execution_ground_exit_timer = maxf(execution_ground_exit_timer - delta, 0.0)
	if not frontflip_active:
		execution_air_exit = ExecutionAirExit.NONE
	if not is_on_floor():
		execution_ground_exit_timer = 0.0
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	running_attack_cooldown_timer = max(running_attack_cooldown_timer - delta, 0.0)
	ground_heavy_cooldown_timer = max(ground_heavy_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)
	wall_jump_animation_timer = max(wall_jump_animation_timer - delta, 0.0)
	wall_cling_timer = max(wall_cling_timer - delta, 0.0)
	invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	knife_throw_pose_timer = max(knife_throw_pose_timer - delta, 0.0)
	roar_explosive_timer = max(roar_explosive_timer - delta, 0.0)
	proud_roar_timer = max(proud_roar_timer - delta, 0.0)
	uppercut_chain_timer = max(uppercut_chain_timer - delta, 0.0)
	combo_buffer_timer = max(combo_buffer_timer - delta, 0.0)
	if combo_buffer_timer <= 0.0:
		combo_buffer = &""
	proud_cycle_timer = max(proud_cycle_timer - delta, 0.0)
	brake_recover_timer = max(brake_recover_timer - delta, 0.0)
	roar_stall_timer = max(roar_stall_timer - delta, 0.0)
	roar_lock_timer = max(roar_lock_timer - delta, 0.0)
	riposte_timer = max(riposte_timer - delta, 0.0)
	block_stun_timer = max(block_stun_timer - delta, 0.0)
	jump_squat_timer = max(jump_squat_timer - delta, 0.0)
	uppercut_pose_timer = max(uppercut_pose_timer - delta, 0.0)
	_update_shine_durability(delta)
	if light_combo_window_timer > 0.0:
		light_combo_window_timer = max(light_combo_window_timer - delta, 0.0)
		if light_combo_window_timer == 0.0 and attack_mode != ATTACK_SLASH:
			light_combo_step = 0
	hurt_lock_timer = max(hurt_lock_timer - delta, 0.0)
	heavy_ground_impact_wave_timer = max(heavy_ground_impact_wave_timer - delta, 0.0)
	heavy_landing_pose_timer = max(heavy_landing_pose_timer - delta, 0.0)
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
		jump_squat_timer = 0.07
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
	aerial_stall_pose = false
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
	if backflip_run_direction != 0:
		velocity.x = move_toward(velocity.x, 0.0, sprint_brake_deceleration * delta)
		return
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
	bunnyhop_bonus = 0.0
	bunnyhop_chain = 0
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
	velocity.x = sprint_direction * (long_jump_horizontal_speed + bunnyhop_bonus)
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
	bunnyhop_chain += 1
	bunnyhop_bonus += bunnyhop_speed_gain
	_launch_long_jump()
	Stats.add("bunnyhops")
	return true

func _start_backflip() -> void:
	backflip_run_direction = 0
	bunnyhop_bonus = 0.0
	bunnyhop_chain = 0
	Stats.add("backflips")
	# El backflip viaja en contra del facing; el personaje sigue mirando hacia delante.
	backflip_direction = -facing
	sprint_direction = facing
	long_jump_squat_timer = 0.0
	long_jump_active = false
	backflip_active = true
	backflip_elapsed = 0.0
	flip_streak += 1
	backflip_rotation_duration = _get_backflip_airtime() * BACKFLIP_SPIN_FRACTION * _flip_chain_factor()
	backflip_chain_timer = 0.0
	sprint_turn_timer = 0.0
	sprint_turn_direction = 0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.x = backflip_direction * backflip_horizontal_speed
	velocity.y = backflip_vertical_speed

func _flip_chain_factor() -> float:
	return CHAINED_FLIP_SPIN if flip_streak >= 2 else 1.0

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
	execution_air_exit = ExecutionAirExit.NONE
	air_jumps_remaining -= 1
	jump_origin_y = global_position.y
	frontflip_active = true
	Stats.add("frontflips")
	frontflip_elapsed = 0.0
	flip_streak += 1
	frontflip_rotation_duration = _get_flip_airtime(jump_velocity) * FRONTFLIP_SPIN_FRACTION * _flip_chain_factor()
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
	Ferocity.add("wallride", 9.0, "WALLRIDE")
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
	if execution_core != null:
		return
	if dead:
		return
	if _is_roar_invincible():
		# Frames explosivos del rugido: invencible, y un ataque cuerpo a cuerpo se desvía.
		if attacker and attacker.has_method("on_deflected"):
			attacker.on_deflected(self)
			Stats.add("parries")
			Sfx.play("parry")
			_apply_hitstop(hitstop_deflect)
			# Riposte: durante un instante el siguiente ataque fuerte hace el doble de daño.
			riposte_timer = riposte_duration
			# El parry no gasta durabilidad: la recupera, y saca del empuje de un bloqueo.
			block_stun_timer = 0.0
			_change_shine_durability(shine_parry_restore)
		return
	if _has_sss_iframes():
		return
	if invulnerability_timer > 0.0 or current_health <= 0:
		return
	if roar_active and attacker != null:
		_block_hit(source_position)
		return
	_end_roar()
	mantle_active = false

	current_health = max(current_health - amount, 0)
	Stats.add("damage_taken", amount)
	if current_health > 0:
		Sfx.play("hurt")
	if attacker and attacker.is_in_group(&"sun"):
		Stats.add("sun_hits_taken")
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		Stats.add("deaths")
		_start_death(source_position, amount)
		return

	invulnerability_timer = hurt_invulnerability_time
	_camera_kick(0.6)
	if Ferocity.player_hit():
		# Imparable: pierde vida y estilo, pero sigue con lo que estaba haciendo.
		Fx.impact(get_parent(), global_position + Vector2(0, -14), Fx.ROAR, 1.2)
		Fx.text(get_parent(), global_position + Vector2(0, -60), "¡IMPARABLE!", Ferocity.rank_info()["color"])
		return
	hurt_lock_timer = hurt_control_lock_time
	execution_ground_exit_timer = 0.0
	execution_air_exit = ExecutionAirExit.NONE
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
	if _is_attack_active():
		_cancel_attack_for_chain()
	var push_direction: float = sign(global_position.x - source_position.x)
	if push_direction == 0.0:
		push_direction = -facing
	velocity = Vector2(push_direction * hurt_knockback.x, hurt_knockback.y)

func return_to_checkpoint(amount: int) -> void:
	if execution_core != null:
		return
	# Espinas del plataformeo final: daño y de vuelta al último checkpoint (sin reiniciar el nivel).
	if dead:
		return
	var from := global_position
	take_damage(amount, global_position + Vector2(0.0, 40.0))
	if dead:
		return
	_cancel_all_states()
	hurt_lock_timer = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	Fx.puff(get_parent(), from + Vector2(0, -14), Color(0.55, 0.25, 0.55, 0.9))
	Fx.impact(get_parent(), global_position + Vector2(0, -14), Fx.ROAR, 1.0)

func begin_merge() -> void:
	# Final: Rengar deja de responder y queda flotando mientras se funde con el Ruby1.
	_cancel_all_states()
	velocity = Vector2.ZERO
	invulnerability_timer = 999.0
	set_physics_process(false)
	shadow.visible = false
	animated_sprite.rotation = 0.0
	animated_sprite.play(ANIMATION_FALL)
	_align_character_animation(ANIMATION_FALL)
	charge_glow_material.set_shader_parameter("glow_color", Color(1.0, 0.25, 0.3))

# ---------- Muerte

func _start_death(source_position: Vector2, amount: int) -> void:
	# Sale despedido por el golpe que lo mató: más lejos cuanto más fuerte fue.
	dead = true
	Sfx.play("death")
	mane_emitter.emitting = false
	Ferocity.reset()
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
	if Input.is_action_just_pressed("respawn") and respawn_enabled:
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
	execution_ground_exit_timer = 0.0
	execution_air_exit = ExecutionAirExit.NONE
	_end_roar()
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wallride_active = false
	wall_embedded = false
	mantle_active = false
	if dash_timer > 0.0:
		dash_timer = 0.0
		_set_dash_visual_active(false)
	if _is_attack_active():
		_cancel_attack_for_chain()
	combo_buffer = &""
	uppercut_chain_timer = 0.0

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
	return roar_active or mantle_active or block_stun_timer > 0.0

# ---------- Hitstop e impactos

func _apply_hitstop(duration: float) -> void:
	# Congela el juego un instante al conectar; si ya hay uno activo, se queda el más largo.
	var end_msec: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if end_msec <= hitstop_end_msec:
		return
	hitstop_end_msec = end_msec
	hitstop_token += 1
	Engine.time_scale = 0.05 * TimeControl.base_scale()
	# El temporizador ignora la escala de tiempo; solo el último hitstop restaura la velocidad (la base:
	# con la cámara lenta activada, vuelve a cámara lenta).
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hitstop.bind(hitstop_token))

func _end_hitstop(token: int) -> void:
	if token == hitstop_token:
		Engine.time_scale = TimeControl.base_scale()
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
	# Brillo rojo-dorado pulsante mientras el riposte está disponible.
	if riposte_timer > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 45.0)
		charge_glow_material.set_shader_parameter("glow_color", Color(1.0, 0.35, 0.12))
		charge_glow_material.set_shader_parameter("glow_amount", lerp(0.35, 0.8, pulse))
	elif unstoppable_glow:
		# Parpadeo rápido entre oro solar y menta, como el speed booster de Samus; las estelas llevan el color del rango.
		var flash: Dictionary = Ferocity.unstoppable_flash()
		charge_glow_material.set_shader_parameter("glow_color", flash["color"])
		charge_glow_material.set_shader_parameter("glow_amount", flash["amount"])
		afterimage_unstoppable_material.set_shader_parameter("glow_color", Ferocity.rank_info()["color"])
	else:
		charge_glow_material.set_shader_parameter("glow_amount", 0.0)

func _spawn_hit_feedback(area: Node2D) -> void:
	var heavy: bool = attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_HEAVY_GROUND
	var finisher: bool = attack_mode == ATTACK_SLASH and light_combo_step == 3
	var point: Vector2 = _get_target_center(area).lerp(global_position + Vector2(0.0, -14.0), 0.35)
	# El riposte vale con el heavy y con el dash attack (estocada y giro).
	if riposte_attack and attack_mode in [ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_GROUND_CHARGED, ATTACK_LIGHT_CHARGED_AIR, ATTACK_SPIN]:
		Fx.impact(get_parent(), point, Fx.GOLD, 2.2)
		Fx.impact(get_parent(), point, Fx.ROAR, 1.4)
		Fx.text(get_parent(), point + Vector2(0, -36), "¡RIPOSTE!", Color(1.0, 0.55, 0.25))
		_apply_hitstop(hitstop_deflect * Ferocity.impact_multiplier())
		_camera_kick(0.55, 0.06)
		return
	Fx.impact(get_parent(), point, Fx.GOLD if heavy else Fx.SILVER, 1.35 if heavy or finisher else 1.0)
	var impact: float = Ferocity.impact_multiplier()
	if heavy:
		_apply_hitstop(hitstop_heavy * impact)
		_camera_kick(0.32, 0.035)
	elif finisher:
		_apply_hitstop((hitstop_light + 0.03) * impact)
		_camera_kick(0.22, 0.02)
	else:
		_apply_hitstop(hitstop_light * impact)
		_camera_kick(0.1)

func _add_hit_style() -> void:
	# Estilo por golpe: más por los golpes fuertes y por pegar en el aire.
	match attack_mode:
		ATTACK_HEAVY, ATTACK_HEAVY_GROUND:
			if riposte_attack:
				Ferocity.add("riposte", 50.0, "RIPOSTE", Ferocity.BONUS_COLOR)
			else:
				Ferocity.add("heavy_hit", 18.0, "GOLPE PESADO")
		ATTACK_UPPERCUT:
			Ferocity.add("uppercut", 18.0, "UPPERCUT")
		ATTACK_GROUND_CHARGED, ATTACK_LIGHT_CHARGED_AIR:
			if riposte_attack:
				Ferocity.add("riposte", 50.0, "RIPOSTE", Ferocity.BONUS_COLOR)
			else:
				Ferocity.add("dash_attack", 12.0, "DASH ATTACK")
		ATTACK_SPIN:
			if riposte_attack:
				Ferocity.add("riposte", 50.0, "RIPOSTE", Ferocity.BONUS_COLOR)
			else:
				Ferocity.add("spin", 10.0, "GIRO")
		_:
			if light_combo_step == 3:
				Ferocity.add("finisher", 18.0, "REMATE")
			else:
				Ferocity.add("light_hit", 8.0)
	if not is_on_floor() and attack_mode != ATTACK_HEAVY:
		# El extra por pegar en el aire cuenta como débil si el golpe lo es (no sube de rango).
		var weak: bool = attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_LIGHT_CHARGED_AIR or (attack_mode == ATTACK_SLASH and light_combo_step != 3)
		Ferocity.add("air_hit_weak" if weak else "air_hit", 6.0, "AÉREO")

func _camera_kick(trauma: float, punch: float = 0.0) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(trauma)
		if punch > 0.0:
			camera.punch(punch)

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
	# Con el riposte disponible, lanzar el cuchillo cancela el rugido (igual que el heavy).
	if roar_active and riposte_timer > 0.0:
		_end_roar()
	if _blocks_actions() or wall_embedded or _is_attack_active() or dash_timer > 0.0 or hurt_lock_timer > 0.0:
		return
	var knife := KNIFE_SCRIPT.new()
	# Riposte: el cuchillo consume la bonificación y sale potenciado (y a velocidad de carrera).
	knife.empowered = riposte_timer > 0.0
	riposte_timer = 0.0
	get_parent().add_child(knife)
	var throw_velocity := _get_knife_throw_velocity(move_input, knife.empowered)
	var side: float = sign(throw_velocity.x) if throw_velocity.x != 0.0 else float(facing)
	knife.launch(self, global_position + Vector2(side * 12.0, -22.0), throw_velocity)
	thrown_knife = knife
	Stats.add("knife_throws")
	Sfx.play("knife_throw")
	has_knife = false
	knife_throw_pose_timer = 0.15
	knife_changed.emit(false)

func _get_knife_throw_velocity(move_input: float, empowered: bool = false) -> Vector2:
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
	# Hacia donde se aprieta, aunque Rengar mire o corra hacia el otro lado (se puede lanzar hacia atrás).
	var side: int = int(sign(move_input)) if sideways else facing
	var result := Vector2(throw_velocity.x * side, throw_velocity.y)
	var running_with_it: bool = (is_sprinting or long_jump_active) and side == int(sign(velocity.x))
	if running_with_it or empowered:
		# Corriendo hacia ese lado, Rengar alcanzaría su propio cuchillo: sale el doble de rápido (y el del
		# riposte, siempre).
		result.x *= knife_running_multiplier
	return result

func on_knife_hit(point: Vector2) -> void:
	Fx.impact(get_parent(), point, Fx.GOLD, 1.1)
	Sfx.play("knife_hit")
	_apply_hitstop(hitstop_light + 0.01)

func on_knife_caught(knife: Node = null) -> void:
	Sfx.play("knife_catch")
	has_knife = true
	thrown_knife = null
	knife_changed.emit(true)

func _show_knife_missing() -> void:
	# Aviso sobre Rengar (cuchillo tachado + flecha hacia él + tecla de recall), el cuchillo resaltado
	# donde quedó y el icono del HUD.
	if is_instance_valid(knife_missing_cue):
		knife_missing_cue.restart()
	else:
		knife_missing_cue = KNIFE_MISSING_CUE_SCRIPT.new()
		knife_missing_cue.player = self
		add_child(knife_missing_cue)
	if is_instance_valid(thrown_knife):
		thrown_knife.highlight()
	knife_missing.emit()

func on_riposte_knife_pulled() -> void:
	# Cuchillo del riposte: conserva el feedback; la curación viene ahora de ejecutar un Ruby.
	Fx.impact(get_parent(), global_position + Vector2(0, -16), Fx.ROAR, 1.2)

func on_knife_shined(knife: Node) -> void:
	# Shine knife: el cuchillo que volvía sale disparado otra vez contra el enemigo.
	_apply_hitstop(0.05)
	Stats.add("knife_shines")
	Ferocity.add("shine_knife", 22.0, "SHINE KNIFE", Ferocity.BONUS_COLOR, "shine_knife", knife.player_shines)

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
	if roar_active or mantle_active or hurt_lock_timer > 0.0 or current_health <= 0 or shine_broken:
		return
	var stunned: bool = block_stun_timer > 0.0
	# En el aire se recuerda la velocidad de carrera para poder recuperarla al soltar a tiempo.
	roar_elapsed = 0.0
	roar_saved_direction = 0
	if not is_on_floor() and abs(velocity.x) >= sprint_speed - 1.0:
		roar_saved_speed = abs(velocity.x)
		roar_saved_direction = 1 if velocity.x > 0.0 else -1
		roar_saved_long_jump = long_jump_active
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
	if _is_attack_active():
		_cancel_attack_for_chain()
	jump_cut_available = false
	# Frena casi todo el impulso de golpe (no en seco); en el empuje de un bloqueo no lo toca.
	if not stunned:
		velocity *= roar_momentum_keep
	roar_active = true
	Sfx.play("shine")
	Sfx.play("roar_parry")
	Sfx.start_loop("shine_hold")
	Stats.add("roars")
	roar_explosive_timer = roar_explosive_duration
	roar_lock_timer = roar_lock_duration
	roar_aura_on = true
	var air_stall: bool = not is_on_floor() and not stunned and roar_air_stall_available
	roar_stall_timer = roar_stall_duration if air_stall else 0.0
	if air_stall:
		roar_air_stall_available = false
	shine_idle_time = 0.0
	roar_hit_targets.clear()
	Fx.impact(get_parent(), get_roar_center(), Fx.ROAR, 2.0)
	Fx.parry_wave(get_parent(), get_roar_center(), roar_radius, roar_explosive_duration)
	_roar_explosive_hits()

func _end_roar() -> void:
	Sfx.stop_loop("shine_hold")
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
		jump_squat_timer = 0.07
	else:
		air_jumps_remaining -= 1
	velocity.y = jump_velocity
	jump_cut_available = true
	animated_sprite.play(ANIMATION_JUMP)
	_resume_roar_momentum()

func _resume_roar_momentum() -> void:
	# Soltar el rugido a tiempo en el aire manteniendo correr: vuelve a la carrera que se llevaba.
	if roar_saved_direction == 0 or roar_elapsed > roar_air_momentum_grace or is_on_floor():
		return
	if not Input.is_action_pressed("dash"):
		return
	_start_sprint(roar_saved_direction)
	velocity.x = roar_saved_direction * max(roar_saved_speed, sprint_speed)
	# Si iba en salto largo, lo retoma (misma velocidad y se puede encadenar el bunnyhop al caer).
	long_jump_active = roar_saved_long_jump
	roar_saved_direction = 0

func _apply_roar_movement(delta: float) -> void:
	roar_elapsed += delta
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
		# No interrumpe lo que esté haciendo el enemigo: lo empuja y lo electrocuta.
		if target.has_method("on_shine_hit"):
			target.on_shine_hit(direction, shine_push_strength)
		else:
			target.take_hit(get_roar_center(), direction, roar_damage)
		Fx.impact(get_parent(), _get_target_center(target), Fx.ROAR, 1.0)
		_electrocute(target)
		hit_any = true
	if hit_any:
		_apply_hitstop(hitstop_light)

func _electrocute(target: Node2D) -> void:
	Sfx.play("zap")
	var zap: Node2D = ELECTRIC_FX_SCRIPT.new()
	zap.target = target
	var offset = target.get("impact_offset")
	zap.center_offset = offset if offset is Vector2 else Vector2.ZERO
	var size = target.get("body_size")
	zap.radius = clamp((size.y * 0.35) if size is Vector2 else 34.0, 30.0, 70.0)
	get_parent().add_child(zap)

func on_enemy_shine(point: Vector2) -> void:
	# Un enemigo devolvió algo con un shine: un stop largo y golpe de cámara, para que se note bien.
	_apply_hitstop(hitstop_deflect * 1.2)
	_camera_kick(0.4, 0.035)
	Fx.impact(get_parent(), point, [Color(0.35, 0.02, 0.12), Color(1.0, 0.3, 0.55), Color(1.0, 0.92, 0.96)], 1.6)

func is_perfect_shine() -> bool:
	# Las frames del parry: devolver aquí es una perfect devolución.
	return _is_roar_invincible()

func on_projectile_reflected(perfect: bool = false) -> void:
	_apply_hitstop(0.07 if perfect else 0.04)
	# Devolver un proyectil abre el riposte, igual que un parry (no saca del empuje de un bloqueo).
	riposte_timer = riposte_duration
	Sfx.play("parry" if perfect else "block")
	if perfect:
		Fx.text(get_parent(), global_position + Vector2(0, -62), "¡PERFECTO!", Color(1.0, 0.95, 0.6))
		_camera_kick(0.25, 0.02)
	else:
		# Los proyectiles gastan durabilidad (salvo en la perfect devolución).
		_change_shine_durability(-shine_reflect_cost)

# ---------- Bloqueo y durabilidad del shine

func _block_hit(source_position: Vector2) -> void:
	# Golpe en las frames latentes del shine: no quita vida, gasta durabilidad y empuja.
	var push: float = sign(global_position.x - source_position.x)
	if push == 0.0:
		push = -facing
	# El shine sigue activo: se puede seguir bloqueando o parrear durante el empuje.
	_stop_sprint()
	long_jump_active = false
	frontflip_active = false
	backflip_active = false
	wall_cling_timer = 0.0
	wallride_active = false
	if _is_attack_active():
		_cancel_attack_for_chain()
	velocity = Vector2(push * block_knockback.x, 0.0 if is_on_floor() else block_knockback.y)
	block_stun_timer = block_stun_time
	Stats.add("blocks")
	Sfx.play("block")
	Fx.impact(get_parent(), get_roar_center() + Vector2(-push * 20.0, 0), Fx.ROAR, 1.3)
	Fx.text(get_parent(), global_position + Vector2(0, -62), "¡BLOQUEO!", Color(1.0, 0.85, 0.45))
	_apply_hitstop(hitstop_light + 0.03)
	_camera_kick(0.3, 0.02)
	_change_shine_durability(-shine_block_cost)

func _apply_block_stun_movement(delta: float) -> void:
	# Empujado: frena poco a poco (frame de frenado), sin control horizontal.
	velocity.x = move_toward(velocity.x, 0.0, block_stun_friction * delta)
	_apply_gravity(delta)

func _change_shine_durability(amount: float) -> void:
	shine_durability = clamp(shine_durability + amount, 0.0, shine_max_durability)
	if amount < 0.0:
		shine_idle_time = 0.0
	if shine_durability <= 0.0 and not shine_broken:
		_break_shine()
	_emit_shine_changed()

func _break_shine() -> void:
	# Se rompe: el Metatrón estalla y no hay shine hasta recargar el mínimo.
	shine_broken = true
	Sfx.play("shine_break")
	Fx.shatter(get_parent(), get_roar_center(), Color(1.0, 0.2, 0.15), roar_radius)
	Fx.text(get_parent(), global_position + Vector2(0, -70), "¡SHINE ROTO!", Color(1.0, 0.3, 0.25))
	_end_roar()
	_camera_kick(0.5, 0.04)
	_apply_hitstop(hitstop_heavy)

func _update_shine_durability(delta: float) -> void:
	# Se recarga sola un rato después de dejar de usar el shine.
	if roar_active:
		shine_idle_time = 0.0
		return
	shine_idle_time += delta
	if shine_idle_time < shine_regen_delay or (shine_durability >= shine_max_durability and not shine_broken):
		return
	shine_durability = min(shine_durability + shine_regen_rate * delta, shine_max_durability)
	if shine_broken and shine_durability >= shine_min_to_use:
		shine_broken = false
	_emit_shine_changed()

func _emit_shine_changed() -> void:
	shine_changed.emit(shine_durability, shine_max_durability, shine_broken)
	# El Metatrón se va enrojeciendo con menos durabilidad.
	var ratio: float = shine_durability / max(shine_max_durability, 1.0)
	if abs(ratio - shine_tint_ratio) >= 0.02:
		shine_tint_ratio = ratio
		# El sprite dorado se tiñe de rojo con el desgaste.
		roar_aura.set_wear(1.0 - ratio)

func _has_sss_iframes() -> bool:
	# SSS: el heavy aéreo y el giro del dash attack son invulnerables hasta que terminan.
	return Ferocity.rank >= SSS_RANK and (attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_SPIN)

func _destroy_projectiles_with_attack() -> void:
	# SSS: los ataques fuertes (heavy terrestre y aéreo, giro) destruyen proyectiles que tocan.
	if Ferocity.rank < SSS_RANK or not attack_mode in [ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_SPIN]:
		return
	var center: Vector2 = hitbox_shape.global_position
	for projectile in get_tree().get_nodes_in_group(&"projectiles"):
		if projectile.get("reflected") == true:
			continue
		if projectile.global_position.distance_to(center) <= 64.0 and projectile.has_method("_destroy"):
			Fx.impact(get_parent(), projectile.global_position, Fx.GOLD, 1.1)
			projectile._destroy()

func parry_reaches(from: Vector2, to: Vector2) -> bool:
	# Los enemigos cuerpo a cuerpo preguntan si su arma (segmento en coordenadas globales) toca el aura
	# durante los frames explosivos del rugido: si es así, su golpe se trata como si llegara (y se desvía).
	if not parry_uses_aura_radius or not _is_roar_invincible():
		return false
	var center := get_roar_center()
	return Geometry2D.get_closest_point_to_segment(center, from, to).distance_to(center) <= roar_radius

func is_roar_aura_active() -> bool:
	return roar_active and (roar_explosive_timer > 0.0 or roar_aura_on)

func get_roar_center() -> Vector2:
	return global_position + Vector2(0.0, -14.0)

func _is_roar_invincible() -> bool:
	return roar_active and roar_explosive_timer > 0.0

func _create_roar_aura() -> void:
	# El aura del rugido es un Cubo de Metatrón dorado.
	roar_aura = METATRON_SCRIPT.new()
	roar_aura.texture = preload("res://assets/sprites/player/metatronNEW.png")
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
		# Algo transparente para que el sprite no se vea plano (con el destello de brillo al aparecer).
		roar_aura.modulate = Color(1.0, 1.0, 1.0, 0.8).lerp(Color(1.3, 1.2, 1.05, 0.8), 1.0 - progress)
		roar_aura_spin = 0.0
	else:
		# Aura latente (manteniendo): empieza a girar despacio y pulsa; solo devuelve proyectiles.
		var pulse: float = sin(Time.get_ticks_msec() / 110.0)
		roar_aura.scale = Vector2.ONE * (1.0 + 0.035 * pulse)
		roar_aura.modulate = Color(1.0, 1.0, 1.0, 0.6 + 0.1 * pulse)
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
	afterimage_unstoppable_material = ShaderMaterial.new()
	afterimage_unstoppable_material.shader = CHARGE_GLOW_SHADER
	afterimage_unstoppable_material.set_shader_parameter("glow_amount", 0.85)

func _attach_afterimage_container() -> void:
	# Vive en el nivel, justo antes del jugador: las sombras se quedan donde se crearon
	# y se dibujan detrás de Rengar pero delante del escenario.
	var level := get_parent()
	level.add_child(afterimage_container)
	level.move_child(afterimage_container, get_index())

func _exit_tree() -> void:
	_cancel_execution()
	Engine.time_scale = TimeControl.base_scale()
	Sfx.stop_loop("shine_hold")
	if is_instance_valid(afterimage_container):
		afterimage_container.queue_free()

func _update_afterimages(delta: float) -> void:
	afterimage_timer = max(afterimage_timer - delta, 0.0)
	# Sombras estilo Alucard a partir de la velocidad de carrera; el backflip es la excepción.
	var fast_enough: bool = abs(velocity.x) >= sprint_speed - 1.0 or backflip_active or wallride_active
	if fast_enough and not dead:
		Ferocity.add_running(delta)
		Ferocity.add_speed(delta, absf(velocity.x), sprint_speed)
	# El heavy aéreo también deja sombras, aunque baje en picado sin velocidad horizontal.
	fast_enough = fast_enough or (attack_mode == ATTACK_HEAVY and velocity.length() >= sprint_speed)
	unstoppable_glow = fast_enough and Ferocity.is_unstoppable() and not dead
	if not fast_enough or afterimage_timer > 0.0 or not afterimage_container.is_inside_tree():
		return
	afterimage_timer = afterimage_interval
	_spawn_afterimage()

func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.flip_h = animated_sprite.flip_h
	ghost.material = afterimage_unstoppable_material if unstoppable_glow else afterimage_material
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
	if Input.is_action_pressed("dash") and int(sign(move_input)) == -facing:
		backflip_run_direction = -facing
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
	if backflip_run_direction != 0:
		if not Input.is_action_pressed("dash") or int(sign(move_input)) != backflip_run_direction or not is_on_floor() or _is_attack_active():
			backflip_run_direction = 0
		elif backflip_chain_timer <= 0.0:
			var direction := backflip_run_direction
			backflip_run_direction = 0
			brake_pending = false
			brake_recover_timer = 0.0
			_start_sprint(direction)
			velocity.x = direction * sprint_speed
			return
		else:
			return
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
		velocity.x = sprint_direction * (long_jump_horizontal_speed + bunnyhop_bonus)
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

	velocity.x = sprint_direction * (long_jump_horizontal_speed + bunnyhop_bonus) if long_jump_chain_timer > 0.0 and bunnyhop_bonus > 0.0 else sprint_direction * sprint_speed
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
	backflip_run_direction = 0
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
	# El arco se puede cerrar en plena caída con abajo (o abajo + adelante); soltando vuelve al arco normal.
	var steer: float = heavy_steer_acceleration * delta
	match heavy_trajectory:
		HEAVY_DIVE:
			# En picado: recto hacia abajo y muy rápido.
			velocity.x = move_toward(velocity.x, 0.0, steer)
			velocity.y = move_toward(velocity.y, heavy_dive_speed, steer)
		HEAVY_DIAGONAL:
			heavy_diagonal_speed = min(heavy_diagonal_speed + heavy_diagonal_acceleration * delta, heavy_diagonal_max_speed)
			velocity.x = move_toward(velocity.x, facing * heavy_diagonal_speed, steer)
			velocity.y = move_toward(velocity.y, heavy_diagonal_speed, steer)
		_:
			velocity.x = move_toward(velocity.x, facing * heavy_air_speed, steer)
			_apply_gravity(delta)

func _heavy_trajectory() -> int:
	# Solo abajo cuenta: adelante solo, atrás o nada dejan el arco de siempre (correr con la dirección
	# apretada no lo cambia). Se decide al empezar el heavy, cuando Rengar ya mira hacia el input.
	if not Input.is_action_pressed("move_down"):
		return HEAVY_ARC
	var forward: bool = int(sign(Input.get_axis("move_left", "move_right"))) == facing
	return HEAVY_DIAGONAL if forward else HEAVY_DIVE

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

# ---------- Buffer de combos

func _request_combat_action(kind: StringName) -> void:
	if not _try_combat_action(kind):
		combo_buffer = kind
		# Durante el uppercut el buffer cubre lo que falta para la ventana de combo, sin depender del flip.
		combo_buffer_timer = COMBO_BUFFER_TIME + (uppercut_pose_timer if _in_uppercut_chain() else 0.0)

func _try_combat_action(kind: StringName) -> bool:
	# Devuelve si la acción salió (o se descartó con aviso); si no, se queda en el buffer.
	match kind:
		&"uppercut":
			if attack_mode == ATTACK_SPIN and not is_on_floor() and attack_timer <= spin_heavy_cancel_window:
				# Giro -> uppercut.
				if not _can_start_air_uppercut():
					return false
				_cancel_attack_for_chain()
				_start_uppercut_attack(true)
				return true
			var was_uppercut: bool = attack_mode == ATTACK_UPPERCUT
			_try_heavy_uppercut()
			return attack_mode == ATTACK_UPPERCUT and not was_uppercut
		&"heavy":
			if not has_knife:
				_show_knife_missing()
				return true
			if _in_uppercut_chain():
				# Uppercut -> heavy aéreo.
				if not _uppercut_can_be_cancelled():
					return false
				_cancel_attack_for_chain()
				attack_cooldown_timer = 0.0
			var mode_before: int = attack_mode
			_start_heavy_attack(false)
			return attack_mode != mode_before and (attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_HEAVY_GROUND)
		&"attack":
			if _in_uppercut_chain():
				# Uppercut -> dash attack aéreo (y de ahí, saltando, el giro).
				if not _uppercut_can_be_cancelled():
					return false
				_cancel_attack_for_chain()
				_start_light_charged_air_attack()
				return true
			_on_attack_input()
			return true
	return true

func _in_uppercut_chain() -> bool:
	return not is_on_floor() and uppercut_chain_timer > 0.0 and (attack_mode == ATTACK_UPPERCUT or not _is_attack_active())

func _uppercut_can_be_cancelled() -> bool:
	# Recuperación original: 0,35 s desde el inicio. El flip es visual y se puede interrumpir.
	return attack_mode != ATTACK_UPPERCUT and uppercut_pose_timer <= 0.0

func _on_attack_input() -> void:
	# Sin carga: corriendo sale el ataque en carrera (estocada que avanza); si no, el combo ligero.
	if dash_timer > 0.0:
		attack_buffered = true
		return
	if _can_running_attack():
		_start_running_attack()
		return
	if attack_mode == ATTACK_SLASH:
		# Pulsado durante un golpe del combo: el siguiente sale en cuanto termine este.
		if light_combo_step < 3:
			light_combo_queued = true
		return
	var combo_open: bool = light_combo_window_timer > 0.0 and light_combo_step < 3
	if _is_attack_active() or (attack_cooldown_timer > 0.0 and not combo_open):
		return
	_start_attack()

func _can_running_attack() -> bool:
	# Corriendo (también frenando para girar), en salto largo, en backflip (también encadenados) o
	# corriendo por la pared.
	return is_sprinting or long_jump_active or backflip_active or wallride_active or wall_cling_timer > 0.0

func _start_running_attack() -> void:
	if _is_attack_active() or attack_cooldown_timer > 0.0 or running_attack_cooldown_timer > 0.0:
		return
	running_attack_cooldown_timer = running_attack_cooldown
	if wallride_active or wall_cling_timer > 0.0:
		# Desde la pared: el giro que despega de ella.
		wallride_active = false
		wall_cling_timer = 0.0
		_start_wall_spin_attack()
		return
	if sprint_turn_timer > 0.0 and sprint_turn_direction != 0:
		# Frenando para girar: la estocada sale ya hacia el nuevo lado y la carrera sigue por ahí.
		facing = sprint_turn_direction
		_update_facing_visual()
	if is_on_floor():
		_start_ground_charged_attack()
	else:
		_start_light_charged_air_attack()

func _start_attack() -> void:
	# El combo ligero (zarpazos) también se puede hacer sin el cuchillo.
	if _is_attack_active() or dash_timer > 0.0:
		return

	if light_combo_window_timer > 0.0 and light_combo_step > 0 and light_combo_step < 3:
		light_combo_step += 1
	else:
		light_combo_step = 1
	light_combo_window_timer = 0.0
	light_combo_queued = false

	attack_mode = ATTACK_SLASH
	attack_targets_hit.clear()
	Sfx.play("swing_light", 0.0, [1.0, 1.0, 1.12, 0.88][light_combo_step])
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
	Sfx.play("dash_attack")
	_consume_riposte()
	attack_timer = charged_ground_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	velocity.x = facing * charged_ground_lunge_speed
	velocity.y = 0.0
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_heavy_attack(allow_uppercut: bool = true) -> void:
	if allow_uppercut and Input.is_action_pressed("move_up"):
		_try_heavy_uppercut()
		return
	var canceling_from_spin: bool = attack_mode == ATTACK_SPIN and not is_on_floor() and attack_timer <= spin_heavy_cancel_window
	# Los ataques pesados son del cuchillo: sin él no se pueden hacer.
	if dash_timer > 0.0:
		return
	if not has_knife:
		_show_knife_missing()
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
	Sfx.play("swing_heavy", 0.0, 0.92)
	_consume_riposte()
	attack_timer = 0.0
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	heavy_attack_visual_progress = 0.0
	heavy_air_speed = max(abs(velocity.x + facing * charged_air_forward_speed), ground_heavy_speed)
	heavy_diagonal_speed = heavy_diagonal_start_speed
	heavy_trajectory = _heavy_trajectory()
	match heavy_trajectory:
		HEAVY_DIVE:
			velocity = Vector2(0.0, max(velocity.y, heavy_dive_speed * 0.6))
		HEAVY_DIAGONAL:
			velocity = Vector2(facing * heavy_diagonal_speed, max(velocity.y, heavy_diagonal_speed))
		_:
			velocity.x = facing * heavy_air_speed
			velocity.y = max(velocity.y, 60.0)
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _try_heavy_uppercut() -> void:
	# Pesado + arriba: uppercut sin cargar. Es la excepción que se puede hacer sin el cuchillo.
	if dash_timer > 0.0 or _is_attack_active() or attack_cooldown_timer > 0.0:
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

	# Hacia donde se aprieta (p. ej. el riposte justo tras un parry de espaldas).
	_face_attack_input()
	attack_mode = ATTACK_HEAVY_GROUND
	Sfx.play("swing_heavy")
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
	Sfx.play("dash_attack")
	_consume_riposte()
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
	Sfx.play("uppercut")
	attack_timer = light_uppercut_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	if from_air:
		air_uppercut_available = false
	jump_cut_available = false
	# Sale del suelo por el uppercut: no hay coyote time que convierta el siguiente salto en uno de suelo.
	coyote_timer = 0.0
	uppercut_pose_timer = 0.35
	uppercut_chain_timer = light_uppercut_duration + UPPERCUT_CHAIN_WINDOW
	aerial_stall_pose = true
	jump_squat_timer = 0.0
	velocity.x = facing * max(abs(velocity.x), light_uppercut_forward_speed)
	velocity.y = light_uppercut_velocity
	_set_attack_active(true)
	_update_attack_animation()
	_refresh_attack_hits()

func _start_spin_attack() -> void:
	if attack_mode != ATTACK_GROUND_CHARGED and attack_mode != ATTACK_LIGHT_CHARGED_AIR:
		return

	attack_mode = ATTACK_SPIN
	Sfx.play("spin")
	attack_timer = spin_attack_duration
	attack_targets_hit.clear()
	velocity.x = maxf(absf(velocity.x) + spin_launch_boost, spin_launch_speed) * facing
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
	Sfx.play("spin")
	attack_timer = spin_attack_duration
	attack_cooldown_timer = charged_attack_cooldown
	attack_targets_hit.clear()
	air_jumps_remaining = max_air_jumps
	air_uppercut_available = true
	facing = wall_contact_direction
	velocity.x = maxf(absf(velocity.x) + spin_launch_boost, spin_launch_speed) * facing
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
	elif ending_mode == ATTACK_UPPERCUT and not is_on_floor():
		frontflip_active = true
		frontflip_elapsed = 0.0
		execution_air_exit = ExecutionAirExit.UPPERCUT_RISE
	elif ending_mode == ATTACK_SPIN and not is_on_floor():
		# Conserva el lanzamiento y abre el bunnyhop al aterrizar, manteniendo correr.
		aerial_stall_pose = true
		if Input.is_action_pressed("dash"):
			long_jump_active = true
			frontflip_active = true
			frontflip_elapsed = frontflip_rotation_duration
			sprint_direction = facing
			bunnyhop_bonus = maxf(absf(velocity.x) - long_jump_horizontal_speed, 0.0)
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
		execution_ground_exit_timer = 0.0
		execution_air_exit = ExecutionAirExit.NONE
		frontflip_active = false
		wall_embedded = false
		wallride_active = false
		rank_heal_done = false
	else:
		riposte_attack = false
	claw_hitbox_shape.disabled = true
	_update_hitbox_visual_visibility()
	slash_visual.color = slash_base_color if active else Color(slash_base_color.r, slash_base_color.g, slash_base_color.b, 0.0)
	slash_area_visual.color = slash_area_base_color if active else Color(slash_area_base_color.r, slash_area_base_color.g, slash_area_base_color.b, 0.0)
	slash_outline.default_color = slash_outline_base_color if active else Color(slash_outline_base_color.r, slash_outline_base_color.g, slash_outline_base_color.b, 0.0)

func toggle_hitbox_debug() -> void:
	# H: las hitboxes de los ataques de Rengar y, además, las formas de colisión de todo (hurtboxes de
	# enemigos, escenario...). Funciona también con la pausa de frame (P).
	show_hitbox_debug = not show_hitbox_debug
	_update_hitbox_visual_visibility()
	get_tree().debug_collisions_hint = show_hitbox_debug
	for node in get_tree().root.find_children("*", "CollisionShape2D", true, false):
		node.queue_redraw()
	for node in get_tree().root.find_children("*", "CollisionPolygon2D", true, false):
		node.queue_redraw()

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
		ATTACK_SPIN:
			_effect_spin()
		ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_UPPERCUT:
			_effect_liquid_bite()

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

func _effect_spin() -> void:
	# Tres brazos de espiral: el radio crece a medida que el viento envuelve el ouroboros.
	var fire: Array[Color] = _style_fire_palette(Ferocity.style_color())
	var progress: float = 1.0 - (attack_timer / spin_attack_duration)
	var elapsed: float = spin_attack_duration - attack_timer
	var head: float = elapsed * TAU * SCREW_SPIN_TURNS_PER_SECOND * 1.35
	var alpha: float = _effect_fade(progress, 0.8)
	for index in range(3):
		var points := PackedVector2Array()
		for step in range(33):
			var t := step / 32.0
			var angle := head + index * TAU / 3.0 + t * TAU * 1.1
			var radius := 9.0 + t * 45.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.82 + 2.0))
		_set_effect_stroke(index, points, 7.0 - index, fire, alpha)

# Tajo del heavy de suelo: el cuchillo baja desde encima y detrás de la cabeza hasta el suelo delante.
const GROUND_CHOP_CENTER := Vector2(6.0, -22.0)
const GROUND_CHOP_START := -1.95
const GROUND_CHOP_END := 1.0

func _ground_chop_sweep(progress: float) -> float:
	return 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 2.2)

func _effect_liquid_bite() -> void:
	# Estelas líquidas detrás de la melena; las fauces del sprite dibujan el ataque.
	var direction := Vector2.RIGHT
	if attack_mode == ATTACK_UPPERCUT:
		direction = Vector2(light_uppercut_forward_speed, light_uppercut_velocity).normalized()
	elif attack_mode == ATTACK_HEAVY:
		direction = Vector2(absf(velocity.x), maxf(velocity.y, 60.0)).normalized()
	var side := direction.orthogonal()
	var palette: Array[Color] = [Color(0.015, 0.12, 0.08), Color(0.20, 0.65, 0.35), Color(0.78, 0.95, 0.45)]
	for index in range(3):
		var points := PackedVector2Array()
		for step in range(7):
			var t := step / 6.0
			var ripple := sin(t * PI * 2.0 + Time.get_ticks_msec() * 0.025 + index) * 2.0
			points.append(Vector2(0, -12) - direction * (62.0 - t * 38.0) + side * ((index - 1) * 9.0 + ripple))
		_set_effect_stroke(index, points, 4.0, palette, 0.65)

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
	if heavy_trajectory == HEAVY_DIVE:
		_animate_heavy_dive()
		return
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

func _animate_heavy_dive() -> void:
	# En picado se cae desde arriba: la hitbox cubre los pies por delante y por detrás, y baja un poco
	# más que ellos para golpear antes de que el cuerpo de Rengar toque al enemigo.
	hitbox_shape.position = Vector2(0.0, 2.0)
	hitbox_shape.scale = Vector2(3.6, 3.0)
	hitbox.rotation = 0.0
	for visual in [slash_visual, slash_area_visual, slash_outline]:
		visual.position = Vector2(0.0, 2.0)
		visual.rotation = 0.0
	slash_visual.scale = Vector2(3.4, 2.8)
	slash_area_visual.scale = Vector2(3.6, 3.0)
	slash_outline.scale = slash_area_visual.scale
	slash_visual.color = Color(0.88, 0.96, 1.0, 0.96)
	slash_area_visual.color = Color(0.35, 0.86, 1.0, 0.38)
	slash_outline.default_color = Color(0.7, 0.97, 1.0, 0.9)

func _animate_ground_heavy_attack() -> void:
	# La hitbox va siempre delante del cuerpo (el heavy avanza muy rápido y no debe atravesar a nadie) y
	# baja del pecho a los pies siguiendo el tajo.
	var progress: float = 1.0 - (attack_timer / ground_heavy_duration)
	var sweep: float = _ground_chop_sweep(progress)
	var arc_offset := Vector2(22.0, lerp(-40.0, -4.0, sweep))
	var blade_rotation: float = 0.0
	var stretch: float = lerp(1.2, 1.0, progress)

	hitbox_shape.position = arc_offset
	hitbox_shape.scale = Vector2(2.0, 3.0)
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
	# Barre desde los pies hasta por encima de la cabeza, algo por delante: fácil de conectar.
	var vertical_offset: float = lerp(12.0, -48.0, progress)
	var pulse: float = 1.0 + 0.1 * sin(progress * PI * 3.6)

	hitbox_shape.position = Vector2(18.0, vertical_offset)
	hitbox_shape.scale = Vector2(2.2, 3.4)
	slash_visual.position = Vector2(18.0, vertical_offset - 2.0)
	slash_area_visual.position = Vector2(20.0, vertical_offset - 2.0)
	slash_outline.position = Vector2(20.0, vertical_offset - 2.0)
	hitbox.rotation = arc_angle
	slash_visual.rotation = arc_angle
	slash_area_visual.rotation = arc_angle
	slash_outline.rotation = arc_angle
	slash_visual.scale = Vector2(1.8 * pulse, 2.9 * pulse)
	slash_area_visual.scale = Vector2(2.2, 3.35)
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
	if execution_core != null or not _is_attack_active():
		return

	if area in attack_targets_hit:
		return

	attack_targets_hit.append(area)
	if attack_mode in [ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_UPPERCUT]:
		var core: Node2D = area.get_node_or_null("RubyCore")
		if core != null and core.claim(self):
			_queue_execution(core)
			return

	if attack_mode == ATTACK_SLASH and area.has_method("try_block") and area.try_block(global_position):
		Sfx.play("block")
		_on_attack_blocked(area)
		return

	if area.has_method("take_hit"):
		area.take_hit(global_position, facing, int(round(_get_attack_damage() * Ferocity.damage_multiplier())))
		var heavy_hit: bool = attack_mode in [ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_SPIN, ATTACK_UPPERCUT]
		Sfx.play("hit_heavy" if heavy_hit else "hit_light")
		# Más estilo, más impacto: los perseguidores salen despedidos más lejos.
		if area.get("knock_velocity") != null:
			area.knock_velocity *= Ferocity.impact_multiplier()
		if attack_mode == ATTACK_UPPERCUT and area.has_method("launch_to"):
			# El uppercut lo levanta: queda en el aire delante de donde estará Viridy al subir, listo para
			# seguir el combo (al menos UPPERCUT_LAUNCH_HEIGHT por encima de donde le pegó).
			var t: float = UPPERCUT_LAUNCH_RISE
			var ahead: Vector2 = global_position + Vector2(velocity.x * t, velocity.y * t + 0.5 * gravity * t * t)
			var target := Vector2(ahead.x + facing * UPPERCUT_LAUNCH_AHEAD, min(ahead.y, global_position.y - UPPERCUT_LAUNCH_HEIGHT))
			area.launch_to(target, UPPERCUT_LAUNCH_RISE, UPPERCUT_LAUNCH_HANG)
		_spawn_hit_feedback(area)
		_add_hit_style()
		if Ferocity.rank >= SS_RANK and not rank_heal_done and attack_mode in [ATTACK_HEAVY, ATTACK_HEAVY_GROUND, ATTACK_SPIN]:
			# SS y SSS: los ataques fuertes curan (una vez por ataque).
			rank_heal_done = true
			heal(rank_heal)

	if attack_mode == ATTACK_HEAVY:
		# Diferido: puede venir de la señal de colisión, donde no se puede desactivar la hitbox.
		_bounce_after_hit.call_deferred()
	elif attack_mode == ATTACK_SLASH and not is_on_floor():
		_apply_light_hit_air_boost()

func _bounce_after_hit() -> void:
	if execution_core == null:
		_bounce_out_of_heavy_attack(true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	_hit_area(area)

func _start_dash() -> void:
	if dash_timer > 0.0 or dash_cooldown_timer > 0.0 or _is_attack_active():
		return
	execution_ground_exit_timer = 0.0
	execution_air_exit = ExecutionAirExit.NONE
	block_stun_timer = 0.0

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
	if attack_buffered:
		attack_buffered = false
		_end_dash_into_attack.call_deferred()
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

func _end_dash_into_attack() -> void:
	# El ataque pulsado durante el dash sale ahora (en carrera si se sigue corriendo).
	if not _blocks_actions() and dash_timer <= 0.0 and not dead:
		_on_attack_input()

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
	return backflip_run_direction != 0 or dash_timer > 0.0 or _uses_sprint_movement() or backflip_chain_timer > 0.0 or wall_cling_timer > 0.0 or wallride_active or wall_embedded or roar_active or mantle_active or attack_mode == ATTACK_GROUND_CHARGED or attack_mode == ATTACK_HEAVY or attack_mode == ATTACK_SPIN or attack_mode == ATTACK_LIGHT_CHARGED_AIR or attack_mode == ATTACK_HEAVY_GROUND or attack_mode == ATTACK_UPPERCUT

func _update_wall_state() -> void:
	if is_on_floor():
		wall_contact_direction = 0
		roar_air_stall_available = true
		return

	if is_on_wall():
		roar_air_stall_available = true
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
	execution_air_exit = ExecutionAirExit.NONE

	if hit_enemy:
		# Rebotar en un enemigo devuelve un salto aéreo (sin acumular más del máximo) y el uppercut del aire.
		air_jumps_remaining = min(air_jumps_remaining + 1, max_air_jumps)
		air_uppercut_available = true
		roar_air_stall_available = true

	_cancel_attack_for_chain()
	long_jump_active = false
	# Sin ir corriendo, mantener correr al golpear convierte el rebote en uno de carrera: sale lanzado
	# hacia delante a velocidad de sprint y sigue corriendo (gana impulso en vez de quedarse en el sitio).
	if hit_enemy:
		# Cadena de rebotes: se cuenta hasta tocar el suelo.
		bounce_chain += 1
		Sfx.play("bounce", 0.0, 1.0 + 0.06 * min(bounce_chain - 1, 5))
	if hit_enemy and not is_sprinting and Input.is_action_pressed("dash"):
		_start_sprint(facing)
		Stats.add("running_bounces")
		Ferocity.add("running_bounce", 30.0, "REBOTE EN CARRERA", Ferocity.GOOD_COLOR, "bounce", bounce_chain)
	elif hit_enemy:
		Ferocity.add("bounce", 18.0, "REBOTE", Ferocity.GOOD_COLOR, "bounce", bounce_chain)
	velocity.x = -facing * charged_air_bounce_back_speed
	velocity.y = jump_velocity * (heavy_dive_bounce_ratio if heavy_trajectory == HEAVY_DIVE else heavy_bounce_vertical_ratio)
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
	heavy_landing_pose_timer = HEAVY_LANDING_POSE_TIME
	_set_impact_wave_active(true)
	_update_impact_wave_visual()

func _apply_light_hit_air_boost() -> void:
	# Cada golpe ligero que conecta en el aire da un pequeño impulso hacia arriba.
	velocity.y = min(velocity.y, light_hit_air_boost)

func _get_attack_damage() -> int:
	var multiplier := 2 if riposte_attack else 1
	match attack_mode:
		ATTACK_GROUND_CHARGED:
			return DAMAGE_GROUND_CHARGED * multiplier
		ATTACK_HEAVY:
			return DAMAGE_HEAVY * multiplier
		ATTACK_HEAVY_GROUND:
			return DAMAGE_HEAVY_GROUND * multiplier
		ATTACK_SPIN:
			return DAMAGE_SPIN * multiplier
		ATTACK_LIGHT_CHARGED_AIR:
			return DAMAGE_LIGHT_CHARGED_AIR * multiplier
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
	_cancel_execution()
	bunnyhop_bonus = 0.0
	bunnyhop_chain = 0
	backflip_run_direction = 0
	dead = false
	Ferocity.reset()
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
	Engine.time_scale = TimeControl.base_scale()
	current_health = max_health
	light_combo_step = 0
	light_combo_window_timer = 0.0
	light_combo_queued = false
	jump_cut_available = false
	riposte_timer = 0.0
	running_attack_cooldown_timer = 0.0
	still_time = 0.0
	proud_active = false
	proud_roar_timer = 0.0
	proud_cycle_timer = 0.0
	brake_recover_timer = 0.0
	brake_pending = false
	aerial_stall_pose = false
	roar_air_stall_available = true
	flip_streak = 0
	jump_squat_timer = 0.0
	uppercut_pose_timer = 0.0
	block_stun_timer = 0.0
	shine_broken = false
	shine_durability = shine_max_durability
	shine_idle_time = 0.0
	_emit_shine_changed()
	bounce_chain = 0
	attack_buffered = false
	combo_buffer = &""
	uppercut_chain_timer = 0.0
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
	air_uppercut_available = true
	heavy_attack_visual_progress = 0.0
	attack_targets_hit.clear()
	_set_attack_active(false)
	charge_glow_material.set_shader_parameter("glow_amount", 0.0)
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


# ---------- Ejecución del Ruby: bloqueo local breve, sin pausar el resto del combate.

func _queue_execution(core: Node2D) -> void:
	execution_core = core
	execution_previous_z = z_index
	execution_started = false
	execution_elapsed = 0.0
	# El uppercut captura ascendiendo y usa la salida aérea, aunque haya partido desde el suelo.
	execution_aerial = attack_mode != ATTACK_HEAVY_GROUND
	execution_direction = facing
	execution_keep_sprint = is_sprinting or long_jump_active or Input.is_action_pressed("dash")
	execution_speed = absf(velocity.x)
	execution_bonus = bunnyhop_bonus
	execution_trajectory = HEAVY_ARC if attack_mode == ATTACK_UPPERCUT else heavy_trajectory
	execution_jump_buffered = false
	execution_action = &""
	# La colisión puede estar emitiendo area_entered: modificar hitboxes se hace después.
	_begin_execution.call_deferred()

func _begin_execution() -> void:
	if not is_instance_valid(execution_core) or not execution_core.claimed_by(self) or dead:
		_cancel_execution()
		return
	_cancel_all_states()
	_cancel_attack_for_chain()
	z_index = 12
	combo_buffer = &""
	velocity = Vector2.ZERO
	if execution_aerial:
		# La física detiene el acercamiento si hay suelo o una pared, evitando atravesarlos.
		var target: Vector2 = execution_core.global_position + Vector2(0, 30)
		move_and_collide(target - global_position)
	# En aire se enrolla sobre sí misma; en suelo mantiene las fauces cerradas sobre el Ruby.
	animated_sprite.play(ANIMATION_SPIN if execution_aerial else ANIMATION_RUBY_CHEW)
	_align_character_animation(animated_sprite.animation)
	animated_sprite.flip_h = execution_direction < 0
	animated_sprite.rotation = 0.0
	_align_execution_beast()
	Sfx.play("shine", -3.0, 1.25)
	execution_started = true

func _update_execution(delta: float) -> void:
	if not is_instance_valid(execution_core) or not execution_core.claimed_by(self):
		_cancel_execution()
		return
	if not execution_started:
		return
	execution_elapsed += delta
	if Input.is_action_just_pressed("jump"):
		execution_jump_buffered = true
	if Input.is_action_just_pressed("attack"):
		execution_action = &"attack"
	if Input.is_action_just_pressed("heavy_attack"):
		execution_action = &"uppercut" if Input.is_action_pressed("move_up") else &"heavy"
	velocity = Vector2.ZERO
	var progress := clampf(execution_elapsed / maxf(execution_duration, 0.01), 0.0, 1.0)
	if execution_aerial:
		animated_sprite.rotation = execution_direction * TAU * smoothstep(0.0, 1.0, progress)
	_align_execution_beast()
	mane_emitter.follow(animated_sprite, execution_direction, not dead, Ferocity.style_color())
	# El contador mide el tiempo que realmente pasa en el aire, también durante el flip.
	Ferocity.update_airtime(delta, not execution_aerial, false)
	if progress >= 1.0:
		_finish_execution()

func _align_execution_beast() -> void:
	if execution_aerial:
		# El centro permanece en el núcleo; gira sobre sí misma en vez de orbitar con la cabeza larga.
		animated_sprite.position = to_local(execution_core.global_position)
		return
	var mouth := LIQUID_BEAST_MOUTH * LIQUID_BEAST_CANVAS_SIZE
	mouth.x *= execution_direction
	animated_sprite.position = to_local(execution_core.global_position) - mouth.rotated(animated_sprite.rotation)

func _finish_execution() -> void:
	var core := execution_core
	var boss: bool = core.boss
	var final: bool = not boss or core.final_open
	core.complete(self)
	z_index = execution_previous_z
	execution_core = null
	execution_started = false
	attack_cooldown_timer = 0.0
	ground_heavy_cooldown_timer = 0.0
	animated_sprite.rotation = 0.0
	heal((boss_execution_heal if boss else execution_heal) if final else critical_heal)
	Ferocity.add("ruby_execution" if final else "ruby_critical", 50.0 if final else 35.0, "RUBY ABSORBIDO" if final else "NÚCLEO DAÑADO", Color(1.0, 0.25, 0.3))
	_camera_kick(0.3, 0.025)
	facing = execution_direction
	bunnyhop_bonus = execution_bonus
	var keep_running := execution_keep_sprint or Input.is_action_pressed("dash")
	if execution_aerial:
		# La captura ya pagó su tiempo: no se arrastran recuperaciones al rebote libre.
		running_attack_cooldown_timer = 0.0
		dash_cooldown_timer = 0.0
		uppercut_pose_timer = 0.0
		coyote_timer = 0.0
		attack_mode = ATTACK_HEAVY
		heavy_trajectory = execution_trajectory
		_bounce_out_of_heavy_attack(true)
		execution_air_exit = ExecutionAirExit.BOUNCE_FLIP
		if keep_running:
			_start_sprint(execution_direction)
			long_jump_active = true
			bunnyhop_bonus = maxf(execution_bonus, execution_speed - long_jump_horizontal_speed)
			velocity.x = execution_direction * (long_jump_horizontal_speed + bunnyhop_bonus)
			execution_air_exit = ExecutionAirExit.LAUNCH
	else:
		if keep_running:
			_start_sprint(execution_direction)
			bunnyhop_bonus = maxf(execution_bonus, execution_speed - long_jump_horizontal_speed)
			long_jump_chain_timer = long_jump_chain_window
			velocity.x = execution_direction * maxf(execution_speed, sprint_speed)
		else:
			velocity.x = execution_direction * minf(execution_speed, max_speed)
		velocity.x = execution_direction * maxf(absf(velocity.x), execution_ground_exit_speed)
		execution_ground_exit_timer = execution_ground_exit_duration
	# El input dado durante el breve instante puede enlazar al salir de la ejecución.
	if execution_jump_buffered:
		jump_buffer_timer = jump_buffer_time
	if execution_action != &"":
		combo_buffer = execution_action
		combo_buffer_timer = COMBO_BUFFER_TIME
	execution_action = &""
	execution_jump_buffered = false
	_update_facing_visual()
	_update_character_animation()

func _interrupt_execution_air_exit() -> void:
	if execution_air_exit not in [ExecutionAirExit.BOUNCE_FLIP, ExecutionAirExit.LAUNCH, ExecutionAirExit.APEX_FLIP]:
		return
	var action_requested := jump_buffer_timer > 0.0 or combo_buffer != &""
	for action in [&"jump", &"attack", &"heavy_attack", &"dash", &"roar", &"throw_knife"]:
		action_requested = action_requested or Input.is_action_just_pressed(action)
	if action_requested:
		# Solo cancela la presentación. El salto o ataque conserva sus reglas y recursos normales.
		frontflip_active = false
		execution_air_exit = ExecutionAirExit.NONE
		if jump_buffer_timer > 0.0 and not Input.is_action_just_pressed("jump"):
			# El salto guardado durante la captura también sale desde el lanzamiento en carrera.
			_try_start_frontflip(Input.get_axis("move_left", "move_right"))

func _update_execution_air_exit() -> void:
	if not frontflip_active or _is_attack_active() or roar_active or dash_timer > 0.0:
		execution_air_exit = ExecutionAirExit.NONE
		return
	if execution_air_exit == ExecutionAirExit.UPPERCUT_RISE and velocity.y >= -gravity * uppercut_flip_lead_time:
		# Se transforma de vuelta antes del ápice: el flip cruza la subida y la caída con gravedad normal.
		execution_air_exit = ExecutionAirExit.UPPERCUT_FLIP
		frontflip_elapsed = 0.0
		frontflip_rotation_duration = maxf(uppercut_flip_duration, 0.01)
	if execution_air_exit == ExecutionAirExit.UPPERCUT_FLIP:
		if frontflip_elapsed >= frontflip_rotation_duration and velocity.y >= 0.0:
			frontflip_active = false
			aerial_stall_pose = true
			execution_air_exit = ExecutionAirExit.NONE
		return
	if execution_air_exit == ExecutionAirExit.LAUNCH and velocity.y >= 0.0:
		execution_air_exit = ExecutionAirExit.APEX_FLIP
		frontflip_elapsed = 0.0
		frontflip_rotation_duration = maxf(execution_apex_flip_duration, 0.01)
	if execution_air_exit == ExecutionAirExit.APEX_FLIP:
		if frontflip_elapsed < frontflip_rotation_duration:
			velocity.y = 0.0
		else:
			execution_air_exit = ExecutionAirExit.NONE

func _cancel_execution() -> void:
	execution_ground_exit_timer = 0.0
	execution_air_exit = ExecutionAirExit.NONE
	if execution_started:
		z_index = execution_previous_z
	if is_instance_valid(execution_core):
		execution_core.release_claim(self)
	execution_core = null
	execution_started = false
	execution_elapsed = 0.0
	execution_action = &""
	execution_jump_buffered = false
	if is_instance_valid(animated_sprite):
		animated_sprite.rotation = 0.0
