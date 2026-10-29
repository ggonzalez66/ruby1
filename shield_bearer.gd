extends "res://chaser_dummy.gd"

# Escudero: perseguidor acorazado con un escudo grande delante. Los golpes ligeros por delante rebotan
# en el escudo (¡BLOQUEO!); por detrás le entra todo. Lo que le llega de frente sin ser un ligero (pesado,
# uppercut, giro, cuchillo, rugido...) le rompe la guardia y lo deja abierto un momento. Se gira despacio,
# así que saltarle por encima o pasarle con el dash lo deja de espaldas. Su ataque es un golpe de maza
# avisado (como el perseguidor, se puede parrear); al terminarlo baja el escudo un rato.

@export var turn_delay := 0.55
@export var guard_break_time := 1.2
@export var armor_knockback := 0.45

const SHIELD_COLOR := Color(0.42, 0.47, 0.55)
const SHIELD_RIM := Color(0.75, 0.66, 0.38)
const ARMOR_COLOR := Color(0.27, 0.3, 0.38)

var shield: Node2D
var turn_timer := 0.0

func _init() -> void:
	max_health = 14
	speed = 85.0
	attack_range = 170.0
	attack_reach = 96.0
	strike_distance = 62.0
	max_lunge = 130.0
	attack_damage = 16
	telegraph_time = 0.6
	recover_time = 1.0
	impact_offset = Vector2(0, -30)

func _build() -> void:
	body_color = ARMOR_COLOR
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 60)
	collision_shape.shape = rect
	collision_shape.position = Vector2(0, -30)
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	body_poly = _poly([Vector2(-17, 0), Vector2(17, 0), Vector2(15, -58), Vector2(-15, -58)], ARMOR_COLOR)
	visual.add_child(body_poly)
	# Yelmo con visera y cinturón.
	var helmet := _poly([Vector2(-14, -58), Vector2(14, -58), Vector2(10, -70), Vector2(-10, -70)], ARMOR_COLOR.lightened(0.15))
	visual.add_child(helmet)
	var visor := _poly([Vector2(2, -64), Vector2(13, -64), Vector2(13, -60), Vector2(2, -60)], WARNING_COLOR)
	visual.add_child(visor)
	var belt := _poly([Vector2(-16, -26), Vector2(16, -26), Vector2(16, -20), Vector2(-16, -20)], SHIELD_RIM.darkened(0.4))
	visual.add_child(belt)
	ENEMY_SKIN.new().dress(visual, body_poly, "shield_bearer", [body_poly, helmet, visor, belt])
	# Maza: pivota en el hombro (el perseguidor anima "arm" al avisar y al golpear).
	arm = Node2D.new()
	arm.position = Vector2(-4, -44)
	arm.rotation = 0.9
	visual.add_child(arm)
	# La maza va girada hacia arriba respecto al brazo para que al bajar no se meta en el suelo.
	var mace := Node2D.new()
	mace.rotation = -0.75
	arm.add_child(mace)
	mace.add_child(_poly([Vector2(0, -3), Vector2(52, -3), Vector2(52, 3), Vector2(0, 3)], BAND_COLOR))
	mace.add_child(_poly([Vector2(48, -10), Vector2(68, -10), Vector2(74, 0), Vector2(68, 10), Vector2(48, 10)], BLADE_COLOR.darkened(0.2)))
	# Escudo delante (encima de todo).
	shield = Node2D.new()
	shield.position = Vector2(20, -30)
	visual.add_child(shield)
	shield.add_child(_poly([Vector2(-6, -32), Vector2(6, -34), Vector2(9, 0), Vector2(6, 30), Vector2(-6, 28), Vector2(-8, 0)], SHIELD_RIM))
	shield.add_child(_poly([Vector2(-3, -28), Vector2(4, -30), Vector2(6, 0), Vector2(4, 26), Vector2(-3, 24), Vector2(-5, 0)], SHIELD_COLOR))

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -112)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -82)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	# Con la guardia baja el escudo cae a un lado.
	var lowered: bool = not guard_up()
	shield.rotation = lerp(shield.rotation, 1.1 if lowered else 0.0, 10.0 * delta)
	shield.position = shield.position.lerp(Vector2(14, -14) if lowered else Vector2(20, -30), 10.0 * delta)

func guard_up() -> bool:
	return state in [State.IDLE, State.CHASE, State.TELEGRAPH] and not launched

func _in_front(point_x: float) -> bool:
	return (point_x - global_position.x) * facing > -6.0

func _face(player: Node2D) -> void:
	# Se gira despacio: hay un momento en que Viridy queda a su espalda.
	var wanted: int = 1 if player.global_position.x >= global_position.x else -1
	if wanted == facing:
		turn_timer = 0.0
		return
	turn_timer += get_physics_process_delta_time()
	if turn_timer >= turn_delay:
		turn_timer = 0.0
		facing = wanted
		visual.scale.x = facing

func _start_telegraph() -> void:
	# No empieza el golpe de espaldas: primero termina de girarse.
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player and not _in_front(player.global_position.x):
		return
	super._start_telegraph()

func try_block(source_position: Vector2) -> bool:
	# Los ligeros de frente rebotan en el escudo.
	if state == State.DEAD or not guard_up() or not _in_front(source_position.x) or (ruby_core != null and ruby_core.dying):
		return false
	flash_timer = 0.06
	knock_velocity = -facing * 60.0
	return true

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if state == State.DEAD:
		return
	if ruby_core != null and ruby_core.dying:
		super.take_hit(source_position, direction, damage)
		return
	# Llega de frente (empuja hacia atrás) con la guardia alta: se la rompe.
	var breaks_guard: bool = guard_up() and direction == -facing
	super.take_hit(source_position, direction, damage)
	knock_velocity *= armor_knockback
	if state == State.DEAD or not breaks_guard:
		return
	state = State.STAGGER
	state_timer = guard_break_time
	warning_label.visible = false
	Sfx.play("guard_break")
	Fx.text(get_parent(), global_position + Vector2(0, -96), "¡GUARDIA ROTA!", Color(1.0, 0.85, 0.45))

func reset_dummy() -> void:
	super.reset_dummy()
	turn_timer = 0.0
	if shield:
		shield.rotation = 0.0
		shield.position = Vector2(20, -30)
