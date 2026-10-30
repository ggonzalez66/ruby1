extends "res://chaser_dummy.gd"

# Centinela: arácnido pequeño que patrulla su plataforma. Al ver a Viridy se planta y carga la alarma
# (sirena roja, "!!"); si termina, despierta a los enemigos cercanos (la ven desde mucho más lejos) y la
# primera vez llama refuerzos. Golpearlo mientras carga corta la alarma. No ataca y es frágil: es el
# objetivo prioritario.

@export var patrol_width := 150.0
@export var patrol_speed := 55.0
@export var alarm_time := 0.9
@export var alarm_radius := 1100.0
@export var alert_duration := 8.0
@export var alarm_cooldown := 6.0
@export var reinforcements := 2

const SHELL_COLOR := Color(0.3, 0.32, 0.36)
const SIREN_COLOR := Color(1.0, 0.15, 0.12)
const HOUND_SCRIPT := preload("res://hound.gd")

var patrol_direction := 1.0
var called_reinforcements := false
var siren: Polygon2D
var alarm_ring: Line2D

func _init() -> void:
	max_health = 5
	speed = patrol_speed
	detect_range = 600.0
	attack_damage = 0
	telegraph_time = alarm_time
	recover_time = alarm_cooldown
	impact_offset = Vector2(0, -18)

func _build() -> void:
	body_color = SHELL_COLOR
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 30)
	collision_shape.shape = rect
	collision_shape.position = Vector2(0, -15)
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	body_poly = _poly([Vector2(-16, -14), Vector2(-8, -28), Vector2(8, -28), Vector2(16, -14), Vector2(8, -8), Vector2(-8, -8)], SHELL_COLOR)
	visual.add_child(body_poly)
	var legs := _poly([Vector2(-14, -12), Vector2(-28, 0), Vector2(-24, 0), Vector2(-8, -10), Vector2(8, -10), Vector2(24, 0), Vector2(28, 0), Vector2(14, -12)], SHELL_COLOR.darkened(0.35))
	visual.add_child(legs)
	ENEMY_SKIN.new().dress(visual, body_poly, "sentinel", [body_poly, legs])
	# Sirena encima del caparazón: parpadea al cargar la alarma.
	siren = _poly([Vector2(-3, -43), Vector2(3, -43), Vector2(4, -38), Vector2(-4, -38)], SIREN_COLOR.darkened(0.5))
	visual.add_child(siren)
	alarm_ring = Line2D.new()
	var points := PackedVector2Array()
	for index in range(25):
		points.append(Vector2.from_angle(TAU * index / 24.0) * 40.0)
	alarm_ring.points = points
	alarm_ring.width = 3.0
	alarm_ring.default_color = Color(SIREN_COLOR, 0.0)
	alarm_ring.position = Vector2(0, -22)
	add_child(alarm_ring)
	arm = Node2D.new()
	visual.add_child(arm)

	warning_label = Label.new()
	warning_label.text = "!!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", SIREN_COLOR)
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-10, -78)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -46)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	called_reinforcements = false
	super.reset_dummy()

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor() or state == State.DEAD:
		return
	flash_timer = max(flash_timer - delta, 0.0)
	state_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if launched:
		_update_launch(delta)
		return
	var grounded := _apply_gravity(delta)
	if state == State.DEAD:
		return
	if abs(knock_velocity) > 1.0:
		_move_horizontally(knock_velocity * delta, false)
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)
	match state:
		State.IDLE, State.CHASE:
			if player and grounded and _sees(player):
				_face(player)
				_start_telegraph()
			elif grounded:
				# Patrulla de lado a lado; se da la vuelta en los bordes y paredes.
				if absf(global_position.x - spawn_position.x) > patrol_width and signf(global_position.x - spawn_position.x) == patrol_direction:
					patrol_direction = -patrol_direction
				var before := global_position.x
				_move_horizontally(patrol_direction * patrol_speed * delta, true)
				if is_equal_approx(before, global_position.x):
					patrol_direction = -patrol_direction
				facing = 1 if patrol_direction > 0.0 else -1
				visual.scale.x = facing
		State.TELEGRAPH:
			var progress: float = 1.0 - state_timer / alarm_time
			alarm_ring.scale = Vector2.ONE * (0.4 + progress)
			alarm_ring.default_color = Color(SIREN_COLOR, 0.8 * (1.0 - progress * 0.5))
			if state_timer <= 0.0:
				_sound_alarm(player)
		State.RECOVER, State.STAGGER:
			alarm_ring.default_color.a = maxf(alarm_ring.default_color.a - 2.0 * delta, 0.0)
			if state_timer <= 0.0:
				state = State.IDLE
	var on: bool = state == State.TELEGRAPH and int(state_timer * 14.0) % 2 == 0
	siren.color = SIREN_COLOR if on else SIREN_COLOR.darkened(0.5)
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else body_color

func _sees(player: Node2D) -> bool:
	if not _can_see(player):
		return false
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -24), player.global_position + Vector2(0, -26), 2)).is_empty()

func _start_telegraph() -> void:
	Sfx.play("enemy_alert", 2.0, 0.7)
	state = State.TELEGRAPH
	state_timer = alarm_time
	warning_label.visible = true

func _sound_alarm(player: Node2D) -> void:
	warning_label.visible = false
	state = State.RECOVER
	state_timer = alarm_cooldown
	Sfx.play("boss_alert", 0.0, 1.4)
	Fx.text(get_parent(), global_position + Vector2(0, -70), "¡ALARMA!", SIREN_COLOR.lightened(0.3))
	Fx.parry_wave(get_parent(), global_position + Vector2(0, -30), 160.0, 0.5)
	for enemy in get_tree().get_nodes_in_group(&"training_dummies"):
		if enemy != self and enemy.has_method("alert") and enemy.global_position.distance_to(global_position) <= alarm_radius:
			enemy.alert(alert_duration)
	if not called_reinforcements and player != null:
		called_reinforcements = true
		_call_reinforcements(player)

func _call_reinforcements(player: Node2D) -> void:
	# Llegan por los lados de Viridy, en el suelo de este centinela.
	for index in range(reinforcements):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var enemy: Area2D = HOUND_SCRIPT.new() if index % 2 == 0 else load("res://chaser_dummy.gd").new()
		var x: float = player.global_position.x + side * 420.0
		enemy.position = Vector2(x, global_position.y - 40.0)
		enemy.alert(alert_duration)
		var director := get_tree().get_first_node_in_group(&"gauntlet_director")
		if director != null and director.has_method("add_reinforcement"):
			director.add_reinforcement(enemy)
		else:
			get_parent().add_child.call_deferred(enemy)
		Fx.puff(get_parent(), enemy.position + Vector2(0, -20), Color(1.0, 0.3, 0.25, 0.9))

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	var alarming := state == State.TELEGRAPH
	super.take_hit(source_position, direction, damage)
	if alarming and state != State.TELEGRAPH:
		# El golpe corta la alarma.
		alarm_ring.default_color.a = 0.0
		Fx.text(get_parent(), global_position + Vector2(0, -60), "¡SILENCIADO!", Color(0.8, 1.0, 0.7))

func on_deflected(_by: Node) -> void:
	pass
