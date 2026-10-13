extends Area2D

# Guardián de la torre: dummy gigante con una espada enorme.
# - Combo de 3 golpes (barrido, tajo vertical y golpe al suelo con ondas de choque que hay que saltar).
# - Estocada en carrera si Rengar está lejos.
# - Cada ataque se avisa (la espada parpadea en rojo y aparece "!").
# - El rugido en sus frames explosivos desvía el golpe; con un 30% de probabilidad resiste y sigue el combo.

@export var max_health := 150
@export var min_x := 1700.0
@export var max_x := 4300.0
@export var walk_speed := 70.0
@export var attack_range := 260.0
@export var engage_distance := 750.0
@export var recover_time := 0.9
@export var stagger_time := 1.6
@export var resist_chance := 0.3
@export var lunge_min_distance := 380.0
@export var lunge_chance := 0.55
@export var lunge_cooldown_time := 3.5
@export var lunge_windup_time := 0.65
@export var lunge_speed := 950.0
@export var lunge_max_travel := 520.0
@export var lunge_damage := 22

const SHOCKWAVE_SCRIPT := preload("res://shockwave.gd")
const BODY_SIZE := Vector2(70, 150)
const BODY_COLOR := Color(0.45, 0.2, 0.17)
const BODY_HIT_COLOR := Color(1.0, 0.45, 0.4)
const BAND_COLOR := Color(0.25, 0.1, 0.08)
const EYE_COLOR := Color(1.0, 0.85, 0.3)
const BLADE_COLOR := Color(0.78, 0.82, 0.9)
const BLADE_WARNING := Color(1.0, 0.25, 0.2)
const HILT_COLOR := Color(0.85, 0.62, 0.18)
const IDLE_ANGLE := 0.9
# Estocada: la espada apunta hacia delante y algo hacia abajo para que la punta llegue al cuerpo de Rengar.
const LUNGE_ANGLE := 0.38
# Espada un 30% más larga que la original (178 px).
const BLADE_LENGTH := 231.0
# Ángulos con la espada apuntando a +x en 0. El "to" del golpe al suelo deja la punta en el suelo.
const COMBO := [
	{"name": "Barrido", "from": -2.6, "to": 0.5, "telegraph": 0.75, "swing": 0.11, "damage": 25, "shockwave": false},
	{"name": "Tajo vertical", "from": -1.75, "to": 0.9, "telegraph": 0.42, "swing": 0.1, "damage": 25, "shockwave": false},
	{"name": "Golpe al suelo", "from": -2.3, "to": 0.49, "telegraph": 0.5, "swing": 0.1, "damage": 30, "shockwave": true},
]

enum State { IDLE, WALK, TELEGRAPH, SWING, RECOVER, STAGGER, DEFEATED, LUNGE_WINDUP, LUNGE }

var impact_offset := Vector2(0, -80)
var state := State.IDLE
var state_timer := 0.8
var current_health := 0
var facing := -1
var combo_step := 0
var current_attack: Dictionary = COMBO[0]
var swing_hit_done := false
var angle_from := IDLE_ANGLE
var spawn_position := Vector2.ZERO
var flash_timer := 0.0
var lunge_cooldown := 0.0
var decision_timer := 0.0
# Se activa la primera vez que Rengar entra en su rango; lo usa el indicador fuera de pantalla.
var combat_started := false

var visual: Node2D
var body_poly: Polygon2D
var sword_pivot: Node2D
var blade: Polygon2D
var sword_area: Area2D
var warning_label: Label
var health_fill: Polygon2D
var trail: Line2D

func _ready() -> void:
	add_to_group(&"training_dummies")
	add_to_group(&"boss")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	spawn_position = position
	current_health = max_health
	_build()
	_update_health_bar()

func _build() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y * 0.5)
	add_child(shape)

	visual = Node2D.new()
	add_child(visual)
	var half := BODY_SIZE.x * 0.5
	visual.add_child(_poly([Vector2(-60, 0), Vector2(60, 0), Vector2(42, 22), Vector2(-42, 22)], BAND_COLOR))
	body_poly = _poly([Vector2(-half, 0), Vector2(half, 0), Vector2(half, -BODY_SIZE.y), Vector2(-half, -BODY_SIZE.y)], BODY_COLOR)
	visual.add_child(body_poly)
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

	# Estela del tajo: gruesa en la punta reciente y transparente en la cola.
	trail = Line2D.new()
	trail.width = 18.0
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(1.0, 0.35, 0.25, 0.0))
	trail_gradient.set_color(1, Color(1.0, 0.92, 0.85, 0.8))
	trail.gradient = trail_gradient
	var trail_width := Curve.new()
	trail_width.add_point(Vector2(0.0, 0.1))
	trail_width.add_point(Vector2(1.0, 1.0))
	trail.width_curve = trail_width
	trail.top_level = true
	add_child(trail)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 40)
	warning_label.add_theme_color_override("font_color", BLADE_WARNING)
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 8)
	warning_label.position = Vector2(-8, -230)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -180)
	add_child(bar)
	bar.add_child(_poly([Vector2(-92, -7), Vector2(92, -7), Vector2(92, 7), Vector2(-92, 7)], Color(0.08, 0.04, 0.04, 0.9)))
	health_fill = _poly([], Color(0.9, 0.3, 0.22))
	bar.add_child(health_fill)
	var name_label := Label.new()
	name_label.text = "GUARDIÁN DE LA TORRE"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.position = Vector2(-82, -30)
	bar.add_child(name_label)

func _physics_process(delta: float) -> void:
	flash_timer = max(flash_timer - delta, 0.0)
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else BODY_COLOR
	if state == State.DEFEATED:
		return

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if not combat_started and _player_engaged(player):
		combat_started = true
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
			sword_pivot.rotation = lerp(float(current_attack.from), float(current_attack.to), ease(progress, 0.4))
			_update_trail()
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
				_start_lunge()
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
		_start_lunge_windup()
	elif distance > attack_range:
		state = State.WALK
		decision_timer = 0.8
	elif from_idle:
		_start_combo()

func is_warning() -> bool:
	return state == State.TELEGRAPH or state == State.LUNGE_WINDUP

func is_defeated() -> bool:
	return state == State.DEFEATED

func _distance_to(player: Node2D) -> float:
	return abs(player.global_position.x - global_position.x)

func _player_engaged(player: Node2D) -> bool:
	if player == null:
		return false
	var offset := player.global_position - global_position
	return abs(offset.x) < engage_distance and abs(offset.y) < 260.0

func _face(player: Node2D) -> void:
	if player == null:
		return
	facing = 1 if player.global_position.x >= global_position.x else -1
	visual.scale.x = facing

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
	state = State.SWING
	state_timer = float(current_attack.swing)
	swing_hit_done = false
	warning_label.visible = false
	blade.color = BLADE_COLOR.lerp(BLADE_WARNING, 0.35)
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
	# La espada golpea el suelo: dos ondas salen en direcciones opuestas.
	var tip := sword_pivot.to_global(Vector2(BLADE_LENGTH, 0))
	var ground := Vector2(tip.x, global_position.y)
	Fx.impact(get_parent(), ground + Vector2(0, -8), Fx.GOLD, 2.0)
	for direction in [-1, 1]:
		var wave := SHOCKWAVE_SCRIPT.new()
		wave.direction = direction
		get_parent().add_child(wave)
		wave.global_position = ground

func _start_lunge_windup() -> void:
	_face(get_tree().get_first_node_in_group(&"player") as Node2D)
	state = State.LUNGE_WINDUP
	state_timer = lunge_windup_time
	warning_label.visible = true

func _start_lunge() -> void:
	# Se lanza hasta quedar a distancia de estocada de Rengar (con un máximo).
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
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
	blade.color = BLADE_COLOR.lerp(BLADE_WARNING, 0.35)
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
	blade.color = BLADE_COLOR.lerp(BLADE_WARNING, blink)

func _update_trail() -> void:
	var tip := sword_pivot.to_global(Vector2(BLADE_LENGTH, 0))
	trail.add_point(tip)
	if trail.get_point_count() > 12:
		trail.remove_point(0)

func _check_sword_hit(damage: int) -> void:
	if swing_hit_done:
		return
	for body in sword_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			swing_hit_done = true
			body.take_damage(damage, global_position + Vector2(0, -60), self)
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

func take_hit(_source_position: Vector2, _direction: int = 1, damage: int = 1) -> void:
	if state == State.DEFEATED:
		return
	current_health = max(current_health - max(damage, 1), 0)
	flash_timer = 0.08
	_update_health_bar()
	if current_health == 0:
		_defeat()

func _defeat() -> void:
	state = State.DEFEATED
	warning_label.visible = false
	trail.clear_points()
	set_deferred("monitorable", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation", 1.4 * -facing, 0.6)
	tween.tween_property(visual, "modulate:a", 0.25, 0.8)
	Fx.text(get_parent(), global_position + Vector2(0, -220), "¡VICTORIA!", Color(1.0, 0.92, 0.5))

func reset_dummy() -> void:
	position = spawn_position
	current_health = max_health
	state = State.IDLE
	state_timer = 0.8
	combo_step = 0
	lunge_cooldown = 0.0
	combat_started = false
	visual.rotation = 0.0
	visual.modulate.a = 1.0
	sword_pivot.rotation = IDLE_ANGLE
	blade.color = BLADE_COLOR
	warning_label.visible = false
	trail.clear_points()
	set_deferred("monitorable", true)
	_update_health_bar()

func _update_health_bar() -> void:
	var ratio: float = float(current_health) / float(max(max_health, 1))
	var right: float = -90.0 + 180.0 * ratio
	health_fill.polygon = PackedVector2Array([Vector2(-90, -5), Vector2(right, -5), Vector2(right, 5), Vector2(-90, 5)])

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
