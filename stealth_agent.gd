extends Node2D

# Sigilo de un enemigo del Gauntlet. Mientras no descubre a Viridy su IA propia queda suspendida y este
# agente lo mueve:
# - UNAWARE: patrulla. Visión larga y corta hacia donde mira (los voladores, en círculo hacia abajo).
# - SUSPICIOUS: Viridy entró en la visión larga. Se queda quieto, "?".
# - INVESTIGATE: va al punto donde la vio, mira un rato y vuelve a patrullar.
# - ENGAGED: Viridy entró en la visión corta, "!". Corre su IA normal y carga la alarma.
# - HUNT: perdió de vista a Viridy (o salta la alarma sin verla): va a la última posición conocida.
# Sin estar en ENGAGED ni en alarma global, un pesado lo ejecuta (ruby_core.is_executable).

enum Mode { UNAWARE, SUSPICIOUS, INVESTIGATE, ENGAGED, HUNT }
enum Mover { WALK, FLY, FIXED }

const LONG_RANGE := 460.0
const SHORT_RANGE := 210.0
const LONG_HEIGHT := 170.0
const SHORT_HEIGHT := 120.0
# Por la espalda solo nota a Viridy si la tiene pegada.
const BACK_RANGE := 46.0
const FLY_LONG_RANGE := 430.0
const FLY_SHORT_RANGE := 190.0
# Ya en alerta mira a todos lados.
const ALERT_RANGE := 640.0
const SUSPECT_TIME := 1.1
const LOOK_TIME := 2.2
const LOST_TIME := 2.0
const HIT_PAUSE := 1.5
const PATROL_REACH := 150.0
const PATROL_WAIT := 1.3
const PATROL_SPEED := 70.0
const FLY_PATROL_REACH := 240.0
const FLY_PATROL_SPEED := 100.0
const FLY_HUNT_SPEED := 240.0
const FLY_HEIGHT := 170.0
const TURRET_TURN_TIME := 3.5
const MARK_TIME := 0.8
const DRAW_DISTANCE := 1100.0
const LONG_COLOR := Color(1.0, 0.9, 0.4, 0.06)
const SHORT_COLOR := Color(1.0, 0.45, 0.2, 0.11)
const SUSPECT_COLOR := Color(1.0, 0.85, 0.3)
const SPOTTED_COLOR := Color(1.0, 0.2, 0.15)

var director: Node
var enemy: Node2D
var core: Node
var mover := Mover.FIXED
var mode := Mode.UNAWARE
var look := 1
var point := Vector2.ZERO
var home := Vector2.ZERO
var patrol_direction := 1.0
var timer := 0.0
var lost_time := 0.0
var hit_pause := 0.0
var last_health := -1
var seeing := false
var mark: Label
var mark_left := 0.0

func _ready() -> void:
	name = "StealthAgent"
	add_to_group(&"stealth_agents")
	z_index = 6
	mark = Label.new()
	mark.add_theme_font_size_override("font_size", 30)
	mark.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02))
	mark.add_theme_constant_override("outline_size", 7)
	mark.visible = false
	add_child(mark)

func _bind() -> bool:
	director = get_tree().get_first_node_in_group(&"stealth_director")
	enemy = get_parent()
	core = enemy.get_node_or_null("RubyCore")
	if director == null or core == null:
		return false
	mark.position = enemy.impact_offset + Vector2(-8, -74)
	home = enemy.global_position
	last_health = enemy.current_health
	look = 1 if randf() < 0.5 else -1
	timer = randf_range(0.0, PATROL_WAIT)
	if enemy.has_method("_move_horizontally"):
		mover = Mover.WALK
	elif enemy.get("home") != null:
		mover = Mover.FLY
	if mover != Mover.FIXED:
		enemy.facing = look
	_show_facing()
	return true

# ---------- Consultas

func is_aware() -> bool:
	return mode in [Mode.ENGAGED, Mode.HUNT]

func can_be_assassinated() -> bool:
	if director == null:
		return false
	return director.cloak_strike() or (mode != Mode.ENGAGED and not director.alarm_active())

func _counts() -> bool:
	return is_instance_valid(enemy) and enemy.visible and mode == Mode.ENGAGED and core != null and not core.dying and not core.locked

func charging() -> bool:
	return _counts() and hit_pause <= 0.0 and not core.holds_actor()

func paused() -> bool:
	return _counts() and not charging()

func call_down(at: Vector2) -> void:
	# Últimos voladores de la oleada: bajan a buscarla para que no quede ninguno fuera de alcance.
	if mode != Mode.ENGAGED:
		director.last_known = at
		if mode != Mode.HUNT:
			_hunt()

func on_attacked() -> void:
	hit_pause = HIT_PAUSE
	if director != null and mode != Mode.ENGAGED:
		_discover()

# ---------- Lógica

func _physics_process(delta: float) -> void:
	if enemy == null and not _bind():
		enemy = null
		return
	_update_mark(delta)
	if not enemy.visible or core.dying or core.locked:
		seeing = false
		return
	var health: int = enemy.current_health
	if health < last_health:
		on_attacked()
	last_health = health
	hit_pause = maxf(hit_pause - delta, 0.0)
	# Aturdido, congelado o inmovilizado no se mueve ni ve; ralentizado va a medio ritmo.
	if core.holds_actor():
		seeing = false
		return
	if core.slow_skip:
		return
	if director.alarm_active() and not is_aware():
		_hunt()
	var level := _perceive()
	seeing = level > 0
	match mode:
		Mode.UNAWARE:
			if not _react(level):
				_patrol(delta)
		Mode.SUSPICIOUS:
			if not _react(level):
				timer -= delta
				_face_point()
				_idle(delta)
				if timer <= 0.0:
					mode = Mode.INVESTIGATE
					timer = 0.0
		Mode.INVESTIGATE:
			if level == 1:
				point = director.player.global_position
			if level < 2 and _arrive(point, delta):
				timer += delta
				if timer >= LOOK_TIME:
					_calm_down()
			elif level == 2:
				_discover()
		Mode.ENGAGED:
			_update_engaged(delta)
		Mode.HUNT:
			if level > 0:
				_discover()
			elif _arrive(director.last_known, delta):
				timer += delta
				if timer >= LOOK_TIME and not director.alarm_active():
					_calm_down()
	_update_sleep()
	queue_redraw()

func _react(level: int) -> bool:
	if level == 2:
		_discover()
		return true
	if level == 1:
		if mode == Mode.UNAWARE:
			mode = Mode.SUSPICIOUS
			timer = SUSPECT_TIME
			_set_mark("?", SUSPECT_COLOR, SUSPECT_TIME + 0.4)
			Sfx.play("enemy_alert", -6.0, 1.5)
		point = director.player.global_position
	return false

func _update_engaged(delta: float) -> void:
	if director.player_cloaked():
		_hunt()
		return
	if seeing:
		lost_time = 0.0
		if enemy.has_method("alert"):
			enemy.alert(1.0)
		return
	lost_time += delta
	if lost_time >= LOST_TIME:
		_hunt()

func _discover() -> void:
	var was_alarm: bool = director.alarm_active()
	mode = Mode.ENGAGED
	lost_time = 0.0
	if enemy.has_method("alert"):
		enemy.alert(1.0)
	_set_mark("!", SPOTTED_COLOR, MARK_TIME)
	if not was_alarm:
		Sfx.play("stealth_spot")
	director.on_discovered()

func _hunt() -> void:
	mode = Mode.HUNT
	timer = 0.0
	lost_time = 0.0

func _calm_down() -> void:
	mode = Mode.UNAWARE
	timer = 0.0
	home = enemy.global_position

func _update_sleep() -> void:
	# Una vez en el aire por un uppercut, su propia física lo baja.
	var sleep: bool = mode != Mode.ENGAGED and enemy.get("launched") != true
	if sleep == core.ai_suspended:
		return
	core.ai_suspended = sleep
	if not sleep:
		if mover == Mover.FLY:
			enemy.home.x = enemy.global_position.x
		return
	if enemy.get("state") != null and enemy.state != enemy.State.DEAD:
		enemy.state = 0
	if enemy.get("warning_label") != null:
		enemy.warning_label.hide()
	if enemy.has_method("on_ai_sleep"):
		enemy.on_ai_sleep()

# ---------- Visión

func _perceive() -> int:
	var player: Node2D = director.player
	if player == null or player.current_health <= 0 or director.player_cloaked():
		return 0
	var eye: Vector2 = enemy.global_position + enemy.impact_offset
	var target: Vector2 = player.global_position + Vector2(0, -26)
	var offset := target - eye
	var level := 0
	if is_aware():
		level = 2 if offset.length() <= ALERT_RANGE else 0
	elif mover == Mover.FLY:
		var reach: float = director.vision_scale()
		if offset.y > -40.0:
			level = 2 if offset.length() <= FLY_SHORT_RANGE * reach else (1 if offset.length() <= FLY_LONG_RANGE * reach else 0)
	else:
		level = _wedge_level(offset)
	if level == 0:
		return 0
	var ray := PhysicsRayQueryParameters2D.create(eye, target, 2)
	return level if get_world_2d().direct_space_state.intersect_ray(ray).is_empty() else 0

func _wedge_level(offset: Vector2) -> int:
	if offset.length() <= BACK_RANGE:
		return 2
	var ahead: float = offset.x * _look()
	if ahead <= 0.0:
		return 0
	var reach: float = director.vision_scale()
	if ahead <= SHORT_RANGE * reach and absf(offset.y) <= _band(SHORT_HEIGHT, ahead / (SHORT_RANGE * reach)):
		return 2
	if ahead <= LONG_RANGE * reach and absf(offset.y) <= _band(LONG_HEIGHT, ahead / (LONG_RANGE * reach)):
		return 1
	return 0

func _band(height: float, progress: float) -> float:
	return height * (0.3 + 0.7 * progress)

func _look() -> int:
	return look if mover == Mover.FIXED else enemy.facing

# ---------- Movimiento

func _face_point() -> void:
	_turn(1 if point.x >= enemy.global_position.x else -1)

func _turn(direction: int) -> void:
	look = direction
	if mover != Mover.FIXED:
		enemy.facing = direction
	_show_facing()

func _show_facing() -> void:
	if mover == Mover.WALK:
		enemy.visual.scale.x = enemy.facing

func _idle(delta: float) -> void:
	match mover:
		Mover.WALK:
			enemy._apply_gravity(delta)
			if absf(enemy.knock_velocity) > 1.0:
				enemy._move_horizontally(enemy.knock_velocity * delta, false)
				enemy.knock_velocity = move_toward(enemy.knock_velocity, 0.0, 900.0 * delta)
		Mover.FLY:
			enemy.flight_time += delta
			enemy._update_visual(delta)

func _patrol(delta: float) -> void:
	_idle(delta)
	if mover == Mover.FIXED:
		timer -= delta
		if timer <= -TURRET_TURN_TIME:
			timer = 0.0
			_turn(-look)
		return
	if timer > 0.0:
		timer -= delta
		return
	var reach: float = PATROL_REACH if mover == Mover.WALK else FLY_PATROL_REACH
	var speed: float = minf(enemy.get("speed") if enemy.get("speed") != null else FLY_PATROL_SPEED, PATROL_SPEED if mover == Mover.WALK else FLY_PATROL_SPEED)
	var goal: float = home.x + patrol_direction * reach
	var before: float = enemy.global_position.x
	if mover == Mover.WALK:
		enemy._move_horizontally(signf(goal - before) * speed * delta, true)
	else:
		enemy.FLIGHT_MOTION.move_to(enemy, enemy.collision_shape, Vector2(move_toward(before, goal, speed * delta), enemy.global_position.y))
	_turn(1 if goal >= before else -1)
	if absf(goal - enemy.global_position.x) < 4.0 or is_equal_approx(before, enemy.global_position.x):
		patrol_direction = -patrol_direction
		timer = PATROL_WAIT

func _arrive(target: Vector2, delta: float) -> bool:
	# Avanza hacia el punto; true al llegar o si no puede acercarse más.
	_idle(delta)
	var position_now := enemy.global_position
	match mover:
		Mover.WALK:
			var dx: float = target.x - position_now.x
			if absf(dx) < 26.0:
				return true
			_turn(1 if dx > 0.0 else -1)
			enemy._move_horizontally(signf(dx) * enemy.speed * delta, true)
			return is_equal_approx(position_now.x, enemy.global_position.x)
		Mover.FLY:
			var goal := target + Vector2(0, -FLY_HEIGHT)
			if position_now.distance_to(goal) < 30.0:
				return true
			_turn(1 if goal.x >= position_now.x else -1)
			var step := position_now.move_toward(goal, FLY_HUNT_SPEED * delta)
			enemy.FLIGHT_MOTION.move_to(enemy, enemy.collision_shape, Vector2(step.x, position_now.y))
			enemy.FLIGHT_MOTION.move_to(enemy, enemy.collision_shape, Vector2(enemy.global_position.x, step.y))
			return false
	_turn(1 if target.x >= position_now.x else -1)
	return true

# ---------- Aspecto

func _set_mark(text: String, color: Color, time: float) -> void:
	mark.text = text
	mark.add_theme_color_override("font_color", color)
	mark.visible = true
	mark_left = time

func _update_mark(delta: float) -> void:
	if mark_left > 0.0:
		mark_left -= delta
		mark.visible = mark_left > 0.0 and enemy.visible
	elif mode == Mode.INVESTIGATE and enemy.visible:
		mark.visible = true

func _draw() -> void:
	# Los conos solo se ven con las hitboxes activadas (H).
	if enemy == null or not enemy.visible or is_aware() or director.player == null or director.alarm_active() or not director.player.show_hitbox_debug:
		return
	if director.player.global_position.distance_to(enemy.global_position) > DRAW_DISTANCE:
		return
	var origin: Vector2 = enemy.impact_offset
	var reach: float = director.vision_scale()
	if mover == Mover.FLY:
		draw_circle(origin, FLY_LONG_RANGE * reach, LONG_COLOR)
		draw_circle(origin, FLY_SHORT_RANGE * reach, SHORT_COLOR)
		return
	var side: int = _look()
	draw_colored_polygon(_wedge(origin, side, LONG_RANGE * reach, LONG_HEIGHT), LONG_COLOR)
	draw_colored_polygon(_wedge(origin, side, SHORT_RANGE * reach, SHORT_HEIGHT), SHORT_COLOR)

func _wedge(origin: Vector2, side: int, length: float, height: float) -> PackedVector2Array:
	var start: float = _band(height, 0.0)
	# Solo por encima del suelo que pisa.
	var floor_y: float = 0.0
	var low: float = minf(origin.y + height, floor_y)
	return PackedVector2Array([origin + Vector2(0, -start), origin + Vector2(side * length, -height), Vector2(origin.x + side * length, low), Vector2(origin.x, minf(origin.y + start, floor_y))])
