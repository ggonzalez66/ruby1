extends "res://boss_base.gd"

# Guardián mecha: máquina de guerra pesada con un puño enorme y lanzamisiles en los hombros.
# - Puñetazo: echa el puño atrás (brilla), y se lanza hacia delante dando un puñetazo que recorre varios
#   metros. Se parrea con el rugido.
# - Martillazo: levanta el puño y golpea el suelo delante; la onda corre por el suelo (se salta).
# - Salva de misiles: avisa, y lanza misiles que suben y caen sobre los puntos marcados alrededor de
#   Viridy. El rugido los devuelve contra el mecha.
# - Camina despacio hacia Viridy; de lejos prefiere los misiles.

@export var walk_speed := 60.0
@export var punch_windup := 0.6
@export var punch_speed := 1250.0
@export var punch_travel := 360.0
@export var punch_damage := 24
@export var slam_windup := 0.8
@export var slam_damage := 26
@export var slam_radius := 150.0
@export var wave_speed := 480.0
@export var wave_damage := 18
@export var missile_windup := 0.7
@export var missile_count := 5
@export var missile_gap := 0.14
@export var missile_damage := 14
@export var missile_cooldown_time := 6.0
@export var recover_time := 1.0

const SHOCKWAVE_SCRIPT := preload("res://shockwave.gd")
const MISSILE_SCRIPT := preload("res://missile.gd")
const ENEMY_SKIN := preload("res://enemy_skin.gd")
const ARMOR := Color(0.3, 0.31, 0.34)
const FIST_GLOW := Color(1.0, 0.35, 0.15)
const POD_GLOW := Color(1.0, 0.2, 0.15)
# Puño (coordenadas del visual mirando a +x) y hombro de los misiles.
const FIST_REST := Vector2(77, -121)
const POD := Vector2(-31, -174)

enum State { IDLE, WALK, PUNCH_WINDUP, PUNCH, SLAM_WINDUP, SLAM, MISSILE_WINDUP, MISSILES, RECOVER, STAGGER }

var state := State.IDLE
var state_timer := 0.8
var decision_timer := 0.0
var missile_cooldown := 2.0
var missiles_left := 0
var missile_timer := 0.0
var punch_left := 0.0
var hit_done := false
var fist_glow: Polygon2D
var pod_glow: Polygon2D
var body_poly: Polygon2D

func _configure() -> void:
	body_size = Vector2(110, 175)
	impact_offset = Vector2(0, -95)

func _build_body() -> void:
	body_poly = _add_flash_poly(_poly([Vector2(-50, 0), Vector2(50, 0), Vector2(46, -150), Vector2(20, -175), Vector2(-30, -175), Vector2(-50, -150)], ARMOR))
	visual.add_child(body_poly)
	var fist := _poly([Vector2(40, -100), Vector2(92, -100), Vector2(98, -40), Vector2(40, -40)], ARMOR.darkened(0.2))
	visual.add_child(fist)
	var skin: Sprite2D = ENEMY_SKIN.new().dress(visual, body_poly, "mecha", [body_poly, fist])
	# El sprite trae el puño extendido: el torso queda sobre el origen.
	skin.position = Vector2(20.0, 6.0)
	# Brillo del puño al cargar y de los lanzamisiles al avisar la salva.
	fist_glow = _poly(_circle_points(30.0), Color(FIST_GLOW, 0.0))
	fist_glow.position = FIST_REST
	visual.add_child(fist_glow)
	pod_glow = _poly(_circle_points(18.0), Color(POD_GLOW, 0.0))
	pod_glow.position = POD
	visual.add_child(pod_glow)

func _circle_points(radius: float) -> Array:
	var points := []
	for index in range(16):
		points.append(Vector2.from_angle(TAU * index / 16.0) * radius)
	return points

func is_warning() -> bool:
	return state in [State.PUNCH_WINDUP, State.SLAM_WINDUP, State.MISSILE_WINDUP]

func _boss_process(delta: float, player: Node2D) -> void:
	state_timer -= delta
	missile_cooldown = maxf(missile_cooldown - delta, 0.0)
	match state:
		State.IDLE:
			fist_glow.color.a = maxf(fist_glow.color.a - 3.0 * delta, 0.0)
			_face(player)
			if state_timer <= 0.0 and combat_started and _player_engaged(player):
				_decide(player)
		State.WALK:
			_face(player)
			decision_timer -= delta
			position.x = clampf(position.x + facing * walk_speed * delta, min_x, max_x)
			visual.position.y = -absf(sin(Time.get_ticks_msec() * 0.006)) * 4.0
			if decision_timer <= 0.0 or (player and _distance_to(player) < 260.0):
				visual.position.y = 0.0
				_decide(player)
		State.PUNCH_WINDUP:
			var progress: float = 1.0 - state_timer / punch_windup
			visual.rotation = lerpf(visual.rotation, -0.14 * facing, 8.0 * delta)
			visual.position.x = lerpf(visual.position.x, -facing * 18.0, 8.0 * delta)
			fist_glow.color = Color(FIST_GLOW, 0.25 + 0.5 * progress * absf(sin(progress * 30.0)))
			if state_timer <= 0.0:
				_start_punch(player)
		State.PUNCH:
			var step: float = minf(punch_speed * delta, punch_left)
			punch_left -= step
			position.x = clampf(position.x + facing * step, min_x, max_x)
			_check_fist(player, punch_damage)
			if punch_left <= 0.0:
				_recover(recover_time)
		State.SLAM_WINDUP:
			var progress: float = 1.0 - state_timer / slam_windup
			# El puño sube por encima de la cabeza.
			visual.rotation = lerpf(visual.rotation, 0.1 * facing, 6.0 * delta)
			fist_glow.position = FIST_REST.lerp(Vector2(40, -210), ease(progress, 0.5))
			fist_glow.color = Color(FIST_GLOW, 0.3 + 0.5 * absf(sin(progress * 25.0)))
			if state_timer <= 0.0:
				_slam(player)
		State.SLAM:
			fist_glow.position = fist_glow.position.lerp(FIST_REST, 10.0 * delta)
			if state_timer <= 0.0:
				_recover(recover_time + 0.3)
		State.MISSILE_WINDUP:
			var progress: float = 1.0 - state_timer / missile_windup
			pod_glow.color = Color(POD_GLOW, 0.3 + 0.6 * absf(sin(progress * 28.0)))
			if state_timer <= 0.0:
				state = State.MISSILES
				missiles_left = missile_count
				missile_timer = 0.0
				warning_label.visible = false
		State.MISSILES:
			missile_timer -= delta
			if missile_timer <= 0.0 and missiles_left > 0:
				_launch_missile(player, missile_count - missiles_left)
				missiles_left -= 1
				missile_timer = missile_gap
			if missiles_left <= 0:
				pod_glow.color.a = 0.0
				_recover(recover_time + 0.4)
		State.RECOVER, State.STAGGER:
			visual.rotation = lerpf(visual.rotation, 0.0, 5.0 * delta)
			visual.position = visual.position.lerp(Vector2.ZERO, 6.0 * delta)
			fist_glow.color.a = maxf(fist_glow.color.a - 3.0 * delta, 0.0)
			fist_glow.position = fist_glow.position.lerp(FIST_REST, 8.0 * delta)
			if state_timer <= 0.0:
				state = State.IDLE
				state_timer = 0.35

func _decide(player: Node2D) -> void:
	if player == null:
		state = State.IDLE
		state_timer = 0.5
		return
	var distance := _distance_to(player)
	var above: bool = player.global_position.y < global_position.y - 120.0
	if missile_cooldown <= 0.0 and (distance > 420.0 or above or randf() < 0.25):
		_start_windup(State.MISSILE_WINDUP, missile_windup, "¡MISILES!")
	elif distance < 210.0:
		if randf() < 0.5:
			_start_windup(State.SLAM_WINDUP, slam_windup, "")
		else:
			_start_windup(State.PUNCH_WINDUP, punch_windup, "")
	elif distance < 520.0:
		_start_windup(State.PUNCH_WINDUP, punch_windup, "")
	else:
		state = State.WALK
		decision_timer = 1.2

func _start_windup(next: State, duration: float, callout: String) -> void:
	_face(get_tree().get_first_node_in_group(&"player") as Node2D)
	state = next
	state_timer = duration
	warning_label.visible = true
	if next == State.MISSILE_WINDUP:
		missile_cooldown = missile_cooldown_time
		Sfx.play("boss_charge", 0.0, 1.2)
	if callout != "":
		Fx.text(get_parent(), global_position + Vector2(0, -body_size.y - 60.0), callout, POD_GLOW.lightened(0.3))

func _start_punch(player: Node2D) -> void:
	parry_serial += 1
	warning_label.visible = false
	state = State.PUNCH
	hit_done = false
	punch_left = punch_travel
	if player:
		punch_left = clampf(_distance_to(player) - 40.0, 140.0, punch_travel)
	# Se inclina hacia delante: el puño baja a la altura de Viridy.
	visual.rotation = 0.3 * facing
	fist_glow.color = Color(FIST_GLOW, 0.9)
	Sfx.play("boss_dash", 0.0, 0.8)

func _fist_segment() -> Array:
	var base: Vector2 = visual.to_global(Vector2(20, -110))
	var tip: Vector2 = visual.to_global(FIST_REST + Vector2(32, 0))
	return [base, tip]

func _check_fist(player: Node2D, damage: int) -> void:
	if hit_done or player == null:
		return
	var segment := _fist_segment()
	# El puño y el frente del cuerpo que embiste detrás de él.
	var front_top: Vector2 = visual.to_global(Vector2(58, -150))
	var front_bottom: Vector2 = visual.to_global(Vector2(58, -8))
	if _segment_hits_player(player, segment[0], segment[1], 44.0) or _segment_hits_player(player, front_top, front_bottom, 26.0):
		hit_done = true
		_hit_player(player, damage)

func _slam(player: Node2D) -> void:
	parry_serial += 1
	warning_label.visible = false
	state = State.SLAM
	state_timer = 0.35
	visual.rotation = 0.0
	var impact: Vector2 = global_position + Vector2(facing * 95.0, 0)
	Sfx.play("shockwave", 2.0, 0.8)
	Sfx.play("heavy_land", 2.0, 0.6)
	Fx.impact(get_parent(), impact + Vector2(0, -12), [Color(0.3, 0.1, 0.05), FIST_GLOW, Color(1.0, 0.9, 0.7)], 2.4)
	Fx.dust(get_parent(), impact, Vector2.UP, 12, 2.2, 1.4)
	if player != null:
		if player.has_method("parry_reaches") and player.parry_reaches(visual.to_global(Vector2(40, -210)), impact):
			_hit_player(player, slam_damage)
		elif (player.global_position - impact).length() <= slam_radius and player.global_position.y > impact.y - 90.0:
			_hit_player(player, slam_damage)
	var wave := SHOCKWAVE_SCRIPT.new()
	wave.shooter = self
	wave.parry_token = parry_serial
	wave.direction = facing
	wave.speed = wave_speed
	wave.damage = wave_damage
	wave.height = 70.0
	wave.distance_left = 900.0
	get_parent().add_child(wave)
	wave.global_position = impact

func _launch_missile(player: Node2D, index: int) -> void:
	var missile: Area2D = MISSILE_SCRIPT.new()
	var center: Vector2 = player.global_position if player != null else global_position + Vector2(facing * 300.0, 0)
	# Repartidos alrededor de Viridy; el del medio, justo donde está.
	var spread: float = (index - (missile_count - 1) * 0.5) * 95.0
	missile.target = Vector2(center.x + spread + randf_range(-20.0, 20.0), center.y - 6.0)
	missile.velocity = Vector2(-facing * randf_range(60.0, 140.0), -560.0)
	missile.damage = missile_damage
	missile.shooter = self
	missile.parry_token = parry_serial
	get_parent().add_child(missile)
	missile.global_position = visual.to_global(POD)
	Sfx.play("arrow_shot", 0.0, 0.7)
	Fx.puff(get_parent(), missile.global_position, Color(1.0, 0.6, 0.3, 0.8))

func _recover(duration: float) -> void:
	state = State.RECOVER
	state_timer = duration
	warning_label.visible = false

func on_deflected(by: Node) -> void:
	super.on_deflected(by)
	# Un puñetazo parreado lo desequilibra.
	if state == State.PUNCH:
		hit_done = true
		punch_left = 0.0
		state = State.STAGGER
		state_timer = 0.9
		visual.rotation = -0.2 * facing

func _on_posture_broken() -> void:
	super._on_posture_broken()
	state = State.STAGGER
	fist_glow.color.a = 0.0
	pod_glow.color.a = 0.0
	missiles_left = 0

func _on_reset() -> void:
	state = State.IDLE
	state_timer = 0.8
	missile_cooldown = 2.0
	missiles_left = 0
	visual.position = Vector2.ZERO
	if fist_glow != null:
		fist_glow.color.a = 0.0
		fist_glow.position = FIST_REST
		pod_glow.color.a = 0.0
