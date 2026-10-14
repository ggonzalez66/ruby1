extends "res://boss_base.gd"

# Guardián pesado: dummy gigante con una espada enorme.
# - Combo de 3 golpes (barrido, tajo vertical y golpe al suelo con ondas de choque que hay que saltar).
# - Estocada en carrera si Rengar está lejos.
# - El rugido en sus frames explosivos desvía el golpe; a veces resiste y sigue el combo.

@export var walk_speed := 70.0
@export var attack_range := 260.0
@export var recover_time := 0.9
@export var lunge_min_distance := 380.0
@export var lunge_chance := 0.55
@export var lunge_cooldown_time := 3.5
@export var lunge_windup_time := 0.65
@export var lunge_speed := 950.0
@export var lunge_max_travel := 520.0
@export var lunge_damage := 22

const SHOCKWAVE_SCRIPT := preload("res://shockwave.gd")
const BODY_COLOR := Color(0.45, 0.2, 0.17)
const BAND_COLOR := Color(0.25, 0.1, 0.08)
const EYE_COLOR := Color(1.0, 0.85, 0.3)
const BLADE_COLOR := Color(0.78, 0.82, 0.9)
const HILT_COLOR := Color(0.85, 0.62, 0.18)
const IDLE_ANGLE := 0.9
const LUNGE_ANGLE := 0.38
const BLADE_LENGTH := 231.0
# Ángulos con la espada apuntando a +x en 0. Todos terminan apuntando hacia abajo para que
# el arco cubra también la zona pegada al guardián.
const SWING_END := 1.6
const COMBO := [
	{"name": "Barrido", "from": -2.6, "to": SWING_END, "telegraph": 0.75, "swing": 0.12, "damage": 25, "shockwave": false},
	{"name": "Tajo vertical", "from": -1.75, "to": SWING_END, "telegraph": 0.42, "swing": 0.11, "damage": 25, "shockwave": false},
	{"name": "Golpe al suelo", "from": -2.3, "to": SWING_END, "telegraph": 0.5, "swing": 0.11, "damage": 30, "shockwave": true},
]

enum State { IDLE, WALK, TELEGRAPH, SWING, RECOVER, STAGGER, LUNGE_WINDUP, LUNGE }

var state := State.IDLE
var state_timer := 0.8
var combo_step := 0
var current_attack: Dictionary = COMBO[0]
var swing_hit_done := false
var angle_from := IDLE_ANGLE
var lunge_cooldown := 0.0
var decision_timer := 0.0
var last_swing_angle := 0.0
var guard_timer := 0.0

var sword_pivot: Node2D
var blade: Polygon2D
var sword_area: Area2D
var trail: Line2D

func _configure() -> void:
	body_size = Vector2(70, 150)
	impact_offset = Vector2(0, -80)

func _build_body() -> void:
	var half := body_size.x * 0.5
	visual.add_child(_poly([Vector2(-60, 0), Vector2(60, 0), Vector2(42, 22), Vector2(-42, 22)], BAND_COLOR))
	visual.add_child(_add_flash_poly(_poly([Vector2(-half, 0), Vector2(half, 0), Vector2(half, -body_size.y), Vector2(-half, -body_size.y)], BODY_COLOR)))
	visual.add_child(_poly([Vector2(-half, -118), Vector2(half, -118), Vector2(half, -104), Vector2(-half, -104)], BAND_COLOR))
	visual.add_child(_poly([Vector2(6, -136), Vector2(20, -136), Vector2(20, -128), Vector2(6, -128)], EYE_COLOR))
	visual.add_child(_poly([Vector2(24, -136), Vector2(32, -136), Vector2(32, -128), Vector2(24, -128)], EYE_COLOR))
	# Espada: pivota en el hombro y apunta a +x con rotación 0.
	sword_pivot = Node2D.new()
	sword_pivot.position = Vector2(26, -108)
	sword_pivot.rotation = IDLE_ANGLE
	visual.add_child(sword_pivot)
	sword_pivot.add_child(_poly([Vector2(-6, -16), Vector2(8, -16), Vector2(8, 16), Vector2(-6, 16)], HILT_COLOR))
	var shoulder := BLADE_LENGTH - 36.0
	blade = _poly([Vector2(8, -12), Vector2(shoulder, -10), Vector2(BLADE_LENGTH, 0), Vector2(shoulder, 10), Vector2(8, 12)], BLADE_COLOR)
	sword_pivot.add_child(blade)
	sword_area = Area2D.new()
	sword_area.collision_layer = 0
	sword_area.collision_mask = 1
	sword_area.monitorable = false
	var sword_shape := CollisionShape2D.new()
	var sword_rect := RectangleShape2D.new()
	sword_rect.size = Vector2(BLADE_LENGTH - 2.0, 30)
	sword_shape.shape = sword_rect
	sword_shape.position = Vector2(BLADE_LENGTH * 0.5 + 4.0, 0)
	sword_area.add_child(sword_shape)
	sword_pivot.add_child(sword_area)
	trail = _make_trail()

func _boss_process(delta: float, player: Node2D) -> void:
	if guard_timer > 0.0:
		guard_timer -= delta
		# Pose de guardia: la espada cruzada delante del cuerpo.
		sword_pivot.rotation = lerp_angle(sword_pivot.rotation, -1.35, 20.0 * delta)
	state_timer -= delta
	lunge_cooldown = max(lunge_cooldown - delta, 0.0)
	match state:
		State.IDLE:
			_face(player)
			if state_timer <= 0.0 and _player_engaged(player):
				_decide(player, true)
		State.WALK:
			_face(player)
			decision_timer -= delta
			if not _player_engaged(player):
				state = State.IDLE
			elif _distance_to(player) <= attack_range:
				_start_combo()
			elif decision_timer <= 0.0:
				_decide(player, false)
			if state == State.WALK:
				position.x = clamp(position.x + facing * walk_speed * delta, min_x, max_x)
		State.TELEGRAPH:
			var progress: float = 1.0 - state_timer / float(current_attack.telegraph)
			sword_pivot.rotation = lerp(angle_from, float(current_attack.from), ease(clamp(progress * 1.4, 0.0, 1.0), 0.5))
			_blink_blade(progress)
			if state_timer <= 0.0:
				_start_swing()
		State.SWING:
			var progress: float = clamp(1.0 - state_timer / float(current_attack.swing), 0.0, 1.0)
			var angle: float = lerp(float(current_attack.from), float(current_attack.to), ease(progress, 0.4))
			sword_pivot.rotation = angle
			_update_trail()
			_check_sweep_hit(player, last_swing_angle, angle, int(current_attack.damage))
			last_swing_angle = angle
			_check_sword_hit(int(current_attack.damage))
			if state_timer <= 0.0 and state == State.SWING:
				_end_swing()
		State.LUNGE_WINDUP:
			# Echa la espada hacia atrás y se inclina: va a lanzarse.
			var progress: float = 1.0 - state_timer / lunge_windup_time
			sword_pivot.rotation = lerp_angle(sword_pivot.rotation, PI * 0.97, 8.0 * delta)
			visual.rotation = lerp(visual.rotation, -0.18 * facing, 6.0 * delta)
			_blink_blade(progress)
			if state_timer <= 0.0:
				_start_lunge(player)
		State.LUNGE:
			position.x = clamp(position.x + facing * lunge_speed * delta, min_x, max_x)
			_update_trail()
			_check_sword_hit(lunge_damage)
			if state_timer <= 0.0:
				_enter_recover(recover_time)
		State.RECOVER, State.STAGGER:
			sword_pivot.rotation = lerp_angle(sword_pivot.rotation, IDLE_ANGLE, 3.0 * delta)
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			trail.modulate.a = max(trail.modulate.a - 3.0 * delta, 0.0)
			if state_timer <= 0.0:
				state = State.IDLE
				state_timer = 0.5
				blade.color = BLADE_COLOR

func _decide(player: Node2D, from_idle: bool) -> void:
	var distance := _distance_to(player)
	if distance > lunge_min_distance and lunge_cooldown <= 0.0 and randf() < lunge_chance:
		_start_lunge_windup(player)
	elif distance > attack_range:
		state = State.WALK
		decision_timer = 0.8
	elif from_idle:
		_start_combo()

func is_warning() -> bool:
	return state == State.TELEGRAPH or state == State.LUNGE_WINDUP

func _start_combo() -> void:
	combo_step = 0
	_start_telegraph(COMBO[0])

func _start_telegraph(attack: Dictionary) -> void:
	_face(get_tree().get_first_node_in_group(&"player") as Node2D)
	current_attack = attack
	state = State.TELEGRAPH
	state_timer = float(attack.telegraph)
	angle_from = sword_pivot.rotation
	warning_label.visible = true

func _start_swing() -> void:
	last_swing_angle = float(current_attack.from)
	state = State.SWING
	state_timer = float(current_attack.swing)
	swing_hit_done = false
	warning_label.visible = false
	blade.color = BLADE_COLOR.lerp(WARNING_COLOR, 0.35)
	trail.clear_points()
	trail.modulate.a = 1.0

func _end_swing() -> void:
	if current_attack.shockwave:
		_spawn_shockwaves()
	if combo_step < COMBO.size() - 1:
		combo_step += 1
		_start_telegraph(COMBO[combo_step])
	else:
		_enter_recover(recover_time + 0.3)

func _spawn_shockwaves() -> void:
	# Golpe al suelo: dos ondas rápidas salen desde los pies del guardián en direcciones opuestas.
	var ground := global_position
	Fx.impact(get_parent(), ground + Vector2(0, -8), Fx.GOLD, 2.0)
	for direction in [-1, 1]:
		var wave := SHOCKWAVE_SCRIPT.new()
		wave.direction = direction
		wave.speed = 860.0
		wave.distance_left = 900.0
		get_parent().add_child(wave)
		wave.global_position = ground

func _start_lunge_windup(player: Node2D) -> void:
	_face(player)
	state = State.LUNGE_WINDUP
	state_timer = lunge_windup_time
	warning_label.visible = true

func _start_lunge(player: Node2D) -> void:
	# Se lanza hasta quedar a distancia de estocada de Rengar (con un máximo).
	var travel: float = lunge_max_travel
	if player:
		travel = clamp(_distance_to(player) - 150.0, 160.0, lunge_max_travel)
	state = State.LUNGE
	state_timer = travel / lunge_speed
	swing_hit_done = false
	warning_label.visible = false
	lunge_cooldown = lunge_cooldown_time
	sword_pivot.rotation = LUNGE_ANGLE
	visual.rotation = 0.08 * facing
	blade.color = BLADE_COLOR.lerp(WARNING_COLOR, 0.35)
	trail.clear_points()
	trail.modulate.a = 1.0

func _enter_recover(duration: float) -> void:
	state = State.RECOVER
	state_timer = duration
	blade.color = BLADE_COLOR
	warning_label.visible = false

func _blink_blade(progress: float) -> void:
	# El arma parpadea en rojo cada vez más rápido.
	var blink: float = 0.5 + 0.5 * sin(progress * progress * 40.0)
	blade.color = BLADE_COLOR.lerp(WARNING_COLOR, blink)

func _update_trail() -> void:
	trail.add_point(sword_pivot.to_global(Vector2(BLADE_LENGTH, 0)))
	if trail.get_point_count() > 12:
		trail.remove_point(0)

func _check_sword_hit(damage: int) -> void:
	if swing_hit_done:
		return
	for body in sword_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			swing_hit_done = true
			_hit_player(body, damage)
			return

func _check_sweep_hit(player: Node2D, from_angle: float, to_angle: float, damage: int) -> void:
	# El tajo es tan rápido que la hoja puede "saltar" por encima de Rengar entre frames:
	# se comprueba todo el sector barrido desde el frame anterior.
	if swing_hit_done or player == null:
		return
	var low: float = min(from_angle, to_angle) - 0.05
	var high: float = max(from_angle, to_angle) + 0.05
	for offset in [Vector2(0, -4), Vector2(0, -14), Vector2(0, -26)]:
		var local: Vector2 = visual.to_local(player.global_position + offset) - sword_pivot.position
		if local.length() > BLADE_LENGTH + 12.0:
			continue
		var point_angle: float = local.angle()
		if point_angle >= low and point_angle <= high:
			swing_hit_done = true
			_hit_player(player, damage)
			return

func on_deflected(_by: Node) -> void:
	if state != State.SWING and state != State.LUNGE:
		return
	swing_hit_done = true
	Fx.deflect(get_parent(), sword_pivot.to_global(Vector2(BLADE_LENGTH * 0.7, 0)))
	flash_timer = 0.12
	if randf() < resist_chance:
		# Resiste el desvío: este golpe ya no daña, pero el combo continúa.
		Fx.text(get_parent(), global_position + Vector2(0, -250), "¡RESISTE!", Color(1.0, 0.55, 0.4))
		return
	state = State.STAGGER
	state_timer = stagger_time
	warning_label.visible = false
	blade.color = BLADE_COLOR
	sword_pivot.rotation = -2.9
	visual.rotation = -0.12 * facing
	Fx.text(get_parent(), global_position + Vector2(0, -210), "¡ATURDIDO!", Color(1.0, 0.85, 0.5))

func _can_block() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.RECOVER

func _on_block() -> void:
	guard_timer = 0.3

func _on_defeat() -> void:
	trail.clear_points()

func _on_reset() -> void:
	state = State.IDLE
	state_timer = 0.8
	combo_step = 0
	lunge_cooldown = 0.0
	guard_timer = 0.0
	sword_pivot.rotation = IDLE_ANGLE
	blade.color = BLADE_COLOR
	trail.clear_points()
