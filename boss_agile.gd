extends "res://boss_base.gd"

# Guardián ágil: esgrimista con estoque y daga.
# - Combo de 3 estocadas rápidas con el estoque, avanzando en cada una.
# - Tajo de daga rápido cuando Rengar está pegado.
# - Embestida (dash) con el estoque si Rengar está lejos.
# - Lanza su daga como una rueda que barre el suelo y vuelve a su mano. El rugido se la devuelve;
#   él a veces la para con un parry y la manda de vuelta (cada vez pega más).
# - Tras atacar, a veces salta hacia atrás. Bloquea golpes ligeros con la daga.
# - Todos sus ataques se pueden parrear con el rugido.

@export var walk_speed := 150.0
@export var thrust_range := 230.0
@export var dagger_range := 90.0
@export var dash_min_distance := 360.0
@export var dash_speed := 1150.0
@export var dash_max_travel := 620.0
@export var thrust_damage := 14
@export var dagger_damage := 12
@export var dash_damage := 20
@export var throw_damage := 14
# Daño que le hace su propia daga devuelta (antes de los niveles de shine).
@export var throw_reflected_damage := 8
@export var dagger_parry_chance := 0.35
@export var throw_chance := 0.5

const BODY_COLOR := Color(0.16, 0.36, 0.42)
const CAPE_COLOR := Color(0.1, 0.22, 0.27)
const TRIM_COLOR := Color(0.85, 0.72, 0.35)
const SKIN_COLOR := Color(0.8, 0.86, 0.9)
const BLADE_COLOR := Color(0.86, 0.9, 0.97)
const RAPIER_LENGTH := 205.0
const DAGGER_LENGTH := 58.0
const RAPIER_IDLE := 0.75
const RAPIER_READY := -0.25
const RAPIER_THRUST := 0.1
const SPINNING_DAGGER_SCRIPT := preload("res://spinning_dagger.gd")
const THROW_WINDUP_TIME := 0.5

enum State { IDLE, WALK, THRUST_WINDUP, THRUST, DAGGER_WINDUP, DAGGER, DASH_WINDUP, DASH, BACKSTEP, RECOVER, STAGGER, THROW_WINDUP, THROW_WAIT }

var state := State.IDLE
var state_timer := 0.6
var thrust_count := 0
var hit_done := false
var move_left := 0.0
var dash_cooldown := 0.0
var throw_cooldown := 1.5
var thrown_dagger: Node2D
var guard_timer := 0.0
var backstep_from := Vector2.ZERO
var backstep_to := Vector2.ZERO

var rapier_pivot: Node2D
var rapier: Polygon2D
var dagger_pivot: Node2D
var dagger: Polygon2D
var trail: Line2D

func _configure() -> void:
	body_size = Vector2(46, 136)
	impact_offset = Vector2(0, -72)

func _build_body() -> void:
	# Capa, cuerpo esbelto, cabeza con visor y adornos dorados.
	visual.add_child(_poly([Vector2(-26, -112), Vector2(-6, -118), Vector2(-14, 0), Vector2(-40, -6)], CAPE_COLOR))
	visual.add_child(_add_flash_poly(_poly([Vector2(-20, 0), Vector2(20, 0), Vector2(16, -112), Vector2(-16, -112)], BODY_COLOR)))
	visual.add_child(_poly([Vector2(-17, -70), Vector2(17, -70), Vector2(17, -64), Vector2(-17, -64)], TRIM_COLOR))
	visual.add_child(_poly([Vector2(-13, -136), Vector2(13, -136), Vector2(15, -112), Vector2(-15, -112)], SKIN_COLOR))
	visual.add_child(_poly([Vector2(2, -127), Vector2(14, -127), Vector2(14, -122), Vector2(2, -122)], Color(0.1, 0.12, 0.16)))
	visual.add_child(_poly([Vector2(-15, -140), Vector2(15, -140), Vector2(10, -150), Vector2(-10, -150)], TRIM_COLOR))
	# Estoque en la mano derecha (delante) y daga en la izquierda (atrás).
	rapier_pivot = Node2D.new()
	rapier_pivot.position = Vector2(14, -86)
	rapier_pivot.rotation = RAPIER_IDLE
	visual.add_child(rapier_pivot)
	rapier_pivot.add_child(_poly([Vector2(-4, -9), Vector2(6, -9), Vector2(6, 9), Vector2(-4, 9)], TRIM_COLOR))
	rapier = _poly([Vector2(6, -2.5), Vector2(RAPIER_LENGTH - 14.0, -1.2), Vector2(RAPIER_LENGTH, 0), Vector2(RAPIER_LENGTH - 14.0, 1.2), Vector2(6, 2.5)], BLADE_COLOR)
	rapier_pivot.add_child(rapier)
	dagger_pivot = Node2D.new()
	dagger_pivot.position = Vector2(-8, -82)
	dagger_pivot.rotation = 1.2
	visual.add_child(dagger_pivot)
	dagger_pivot.add_child(_poly([Vector2(-3, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-3, 5)], TRIM_COLOR))
	dagger = _poly([Vector2(5, -5), Vector2(DAGGER_LENGTH - 10.0, -3), Vector2(DAGGER_LENGTH, 0), Vector2(DAGGER_LENGTH - 10.0, 3), Vector2(5, 5)], BLADE_COLOR)
	dagger_pivot.add_child(dagger)
	trail = _make_trail()
	trail.width = 10.0

func _boss_process(delta: float, player: Node2D) -> void:
	state_timer -= delta
	dash_cooldown = max(dash_cooldown - delta, 0.0)
	throw_cooldown = max(throw_cooldown - delta, 0.0)
	if guard_timer > 0.0:
		guard_timer -= delta
		# Guardia con la daga cruzada delante.
		dagger_pivot.rotation = lerp_angle(dagger_pivot.rotation, -1.3, 20.0 * delta)
	trail.modulate.a = max(trail.modulate.a - 2.5 * delta, 0.0)
	match state:
		State.IDLE, State.WALK:
			_face(player)
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, RAPIER_IDLE, 6.0 * delta)
			if not _player_engaged(player) or state_timer > 0.0:
				return
			var distance := _distance_to(player)
			if distance <= dagger_range:
				_start(State.DAGGER_WINDUP, 0.28)
			elif distance <= thrust_range:
				thrust_count = 0
				_start(State.THRUST_WINDUP, 0.38)
			elif throw_cooldown <= 0.0 and _roll_throw():
				_start(State.THROW_WINDUP, THROW_WINDUP_TIME)
			elif distance > dash_min_distance and dash_cooldown <= 0.0:
				_start(State.DASH_WINDUP, 0.45)
			else:
				state = State.WALK
				_move(facing * walk_speed * delta)
		State.THRUST_WINDUP:
			var progress: float = 1.0 - state_timer / (0.38 if thrust_count == 0 else 0.2)
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, RAPIER_READY, 14.0 * delta)
			rapier_pivot.position.x = lerp(14.0, 0.0, clamp(progress, 0.0, 1.0))
			_blink(rapier, progress)
			if state_timer <= 0.0:
				hit_done = false
				move_left = 60.0
				rapier_pivot.rotation = _rapier_aim(player)
				_start(State.THRUST, 0.1, false)
		State.THRUST:
			# Estocada: el estoque sale hacia delante y avanza un paso.
			var step: float = min(move_left, 600.0 * delta)
			move_left -= step
			_move(facing * step)
			rapier_pivot.position.x = lerp(rapier_pivot.position.x, 24.0, 30.0 * delta)
			_trail_point(rapier_pivot.to_global(Vector2(RAPIER_LENGTH, 0)))
			_check_blade(player, rapier_pivot, RAPIER_LENGTH, thrust_damage)
			if state_timer <= 0.0:
				thrust_count += 1
				rapier.color = BLADE_COLOR
				if thrust_count < 3:
					_face(player)
					_start(State.THRUST_WINDUP, 0.2)
				else:
					_after_attack(player)
		State.DAGGER_WINDUP:
			var progress: float = 1.0 - state_timer / 0.28
			dagger_pivot.rotation = lerp_angle(dagger_pivot.rotation, -1.5, 14.0 * delta)
			_blink(dagger, progress)
			if state_timer <= 0.0:
				hit_done = false
				dagger_pivot.z_index = 1
				_start(State.DAGGER, 0.1, false)
		State.DAGGER:
			# Tajo rápido de daga en arco delante del cuerpo.
			var progress: float = clamp(1.0 - state_timer / 0.1, 0.0, 1.0)
			dagger_pivot.rotation = lerp(-1.5, 1.4, progress)
			_trail_point(dagger_pivot.to_global(Vector2(DAGGER_LENGTH, 0)))
			_check_blade(player, dagger_pivot, DAGGER_LENGTH + 18.0, dagger_damage)
			if state_timer <= 0.0:
				dagger.color = BLADE_COLOR
				_after_attack(player)
		State.DASH_WINDUP:
			var progress: float = 1.0 - state_timer / 0.45
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, PI * 0.9, 10.0 * delta)
			visual.rotation = lerp(visual.rotation, -0.2 * facing, 6.0 * delta)
			_blink(rapier, progress)
			if state_timer <= 0.0:
				hit_done = false
				move_left = clamp(_distance_to(player) - 70.0, 200.0, dash_max_travel) if player else 300.0
				rapier_pivot.rotation = _rapier_aim(player)
				visual.rotation = 0.1 * facing
				dash_cooldown = 3.0
				_start(State.DASH, move_left / dash_speed, false)
		State.DASH:
			var step: float = min(move_left, dash_speed * delta)
			move_left -= step
			_move(facing * step)
			# La embestida va baja, siguiendo a Rengar (que es mucho más bajo que el guardián).
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, _rapier_aim(player), 12.0 * delta)
			_trail_point(rapier_pivot.to_global(Vector2(RAPIER_LENGTH, 0)))
			_check_blade(player, rapier_pivot, RAPIER_LENGTH, dash_damage)
			if state_timer <= 0.0 or move_left <= 0.0:
				rapier.color = BLADE_COLOR
				_start(State.RECOVER, 0.7)
		State.BACKSTEP:
			# Salto hacia atrás en arco.
			var progress: float = clamp(1.0 - state_timer / 0.35, 0.0, 1.0)
			var target: Vector2 = backstep_from.lerp(backstep_to, progress)
			position = Vector2(clamp(target.x, min_x, max_x), backstep_from.y - sin(progress * PI) * 60.0)
			visual.rotation = -0.3 * facing * sin(progress * PI)
			if state_timer <= 0.0:
				position.y = backstep_from.y
				visual.rotation = 0.0
				_start(State.IDLE, 0.25)
		State.THROW_WINDUP:
			# Echa la daga atrás por encima del hombro, parpadeando.
			var progress: float = 1.0 - state_timer / THROW_WINDUP_TIME
			_face(player)
			dagger_pivot.rotation = lerp_angle(dagger_pivot.rotation, -2.5, 12.0 * delta)
			_blink(dagger, progress)
			if state_timer <= 0.0:
				_throw_dagger(player)
		State.THROW_WAIT:
			# Espera a que vuelva la daga con el estoque en guardia (con un límite por si acaso).
			_face(player)
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, RAPIER_READY, 6.0 * delta)
			dagger_pivot.rotation = lerp_angle(dagger_pivot.rotation, 0.6, 8.0 * delta)
			if not is_instance_valid(thrown_dagger) or state_timer <= 0.0:
				_recover_dagger()
				_start(State.RECOVER, 0.35, false)
		State.RECOVER, State.STAGGER:
			rapier_pivot.rotation = lerp_angle(rapier_pivot.rotation, RAPIER_IDLE, 5.0 * delta)
			rapier_pivot.position = rapier_pivot.position.lerp(Vector2(14, -86), 8.0 * delta)
			dagger_pivot.rotation = lerp_angle(dagger_pivot.rotation, 1.2, 5.0 * delta)
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			if state_timer <= 0.0:
				_start(State.IDLE, 0.3)

func _start(new_state: State, duration: float, warn: bool = true) -> void:
	if new_state in [State.THRUST_WINDUP, State.DAGGER_WINDUP, State.DASH_WINDUP, State.THROW_WINDUP]:
		parry_serial += 1
	state = new_state
	match new_state:
		State.THRUST:
			Sfx.play("rapier")
		State.DAGGER:
			Sfx.play("rapier", 0.0, 0.8)
		State.DASH:
			Sfx.play("boss_dash", 0.0, 1.2)
		State.BACKSTEP:
			Sfx.play("dash", 0.0, 0.85)
	state_timer = duration
	warning_label.visible = warn and new_state in [State.THRUST_WINDUP, State.DAGGER_WINDUP, State.DASH_WINDUP, State.THROW_WINDUP]

func _after_attack(player: Node2D) -> void:
	# A veces se aleja de un salto para volver a atacar desde otra distancia.
	if randf() < 0.45 and player:
		var away: float = -1.0 if player.global_position.x >= global_position.x else 1.0
		backstep_from = position
		backstep_to = position + Vector2(away * 190.0, 0)
		_start(State.BACKSTEP, 0.35, false)
	else:
		_start(State.RECOVER, 0.55, false)

func _roll_throw() -> bool:
	# Se decide de vez en cuando (no en cada frame) si lanza la daga.
	throw_cooldown = 1.5
	return randf() < throw_chance

func _throw_dagger(player: Node2D) -> void:
	# La rueda pasa de largo a Rengar y vuelve, sin salirse de la arena.
	var distance: float = clamp(_distance_to(player) + 260.0, 450.0, 950.0) if player else 600.0
	var offset_x: float = get_parent().global_position.x
	var limit: float = (max_x + offset_x - global_position.x) if facing > 0 else (global_position.x - min_x - offset_x)
	distance = clamp(distance, 200.0, max(limit, 200.0))
	var spinning := SPINNING_DAGGER_SCRIPT.new()
	spinning.damage = throw_damage
	spinning.reflected_damage = throw_reflected_damage
	get_parent().add_child(spinning)
	spinning.launch(self, global_position + Vector2(facing * 30.0, 0), facing, distance, global_position.y)
	thrown_dagger = spinning
	Sfx.play("dagger_throw")
	dagger.visible = false
	dagger.color = BLADE_COLOR
	throw_cooldown = 7.0
	Fx.dust(get_parent(), global_position + Vector2(facing * 20.0, 0), Vector2(facing, -0.3), 6, 1.2)
	_start(State.THROW_WAIT, 6.0, false)

func _recover_dagger() -> void:
	if is_instance_valid(thrown_dagger):
		thrown_dagger.queue_free()
	thrown_dagger = null
	dagger.visible = true

func on_dagger_caught(_spinning: Node) -> void:
	thrown_dagger = null
	dagger.visible = true
	dagger_pivot.rotation = -1.3
	if state == State.THROW_WAIT:
		_start(State.RECOVER, 0.35, false)

func try_parry_dagger(spinning: Node2D) -> bool:
	# Su parry: el estoque golpea la daga y la manda de vuelta contra Rengar.
	if ruby_core.holds_actor() or state == State.STAGGER or randf() >= dagger_parry_chance:
		return false
	rapier_pivot.rotation = -1.4
	flash_timer = 0.0
	Fx.impact(get_parent(), spinning.global_position, Fx.SILVER, 2.0)
	Fx.impact(get_parent(), spinning.global_position, Fx.GOLD, 1.2)
	Fx.text(get_parent(), global_position + Vector2(0, -200), "¡PARRY!", Color(0.8, 0.95, 1.0))
	Shine.enemy_feedback(get_tree(), spinning.global_position)
	return true

func on_dagger_hit(spinning: Node2D, damage: int) -> void:
	# Su propia daga le da: daño, aturdido, y la recupera.
	var direction: int = 1 if spinning.global_position.x <= global_position.x else -1
	thrown_dagger = null
	dagger.visible = true
	Fx.impact(get_parent(), spinning.global_position, Fx.ROAR, 1.6)
	Ferocity.add("dagger_return", 30.0, "SU PROPIA DAGA", Ferocity.BONUS_COLOR)
	take_hit(spinning.global_position, direction, damage)
	if defeated:
		return
	_start(State.STAGGER, 0.9, false)
	visual.rotation = -0.15 * facing
	Fx.text(get_parent(), global_position + Vector2(0, -190), "¡ATURDIDO!", Color(1.0, 0.85, 0.5))

func _rapier_aim(player: Node2D) -> float:
	# Ángulo del estoque hacia el cuerpo de Rengar; si está lejos o no hay jugador, estocada recta.
	if player == null:
		return RAPIER_THRUST
	var target: Vector2 = visual.to_local(player.global_position + Vector2(0, -14)) - rapier_pivot.position
	if target.x < 20.0:
		return 0.9
	return clamp(target.angle(), -0.5, 0.9)

func _move(amount: float) -> void:
	position.x = clamp(position.x + amount, min_x, max_x)

func _blink(blade_poly: Polygon2D, progress: float) -> void:
	var blink: float = 0.5 + 0.5 * sin(clamp(progress, 0.0, 1.0) * clamp(progress, 0.0, 1.0) * 40.0)
	blade_poly.color = BLADE_COLOR.lerp(WARNING_COLOR, blink)

func _trail_point(point: Vector2) -> void:
	trail.modulate.a = 1.0
	trail.add_point(point)
	if trail.get_point_count() > 8:
		trail.remove_point(0)

func _check_blade(player: Node2D, pivot: Node2D, length: float, damage: int) -> void:
	if hit_done or player == null:
		return
	var from := pivot.global_position
	var to := pivot.to_global(Vector2(length, 0))
	if _segment_hits_player(player, from, to, 16.0):
		hit_done = true
		_hit_player(player, damage)

func is_warning() -> bool:
	return state in [State.THRUST_WINDUP, State.DAGGER_WINDUP, State.DASH_WINDUP, State.THROW_WINDUP]

func on_deflected(_by: Node) -> void:
	if not state in [State.THRUST, State.DAGGER, State.DASH]:
		return
	hit_done = true
	Fx.deflect(get_parent(), rapier_pivot.to_global(Vector2(RAPIER_LENGTH * 0.5, 0)))
	flash_timer = 0.12
	ruby_core.register_parry(parry_serial)

func _on_posture_broken() -> void:
	_recover_dagger()
	_start(State.STAGGER, 2.5, false)
	rapier.color = BLADE_COLOR
	dagger.color = BLADE_COLOR
	rapier_pivot.rotation = -2.6
	visual.rotation = -0.15 * facing
	trail.clear_points()

func _can_block() -> bool:
	return state in [State.IDLE, State.WALK, State.RECOVER]

func _on_block() -> void:
	guard_timer = 0.3

func _on_defeat() -> void:
	trail.clear_points()
	_recover_dagger()

func _on_reset() -> void:
	_start(State.IDLE, 0.6, false)
	dash_cooldown = 0.0
	throw_cooldown = 1.5
	_recover_dagger()
	guard_timer = 0.0
	rapier_pivot.rotation = RAPIER_IDLE
	rapier_pivot.position = Vector2(14, -86)
	dagger_pivot.rotation = 1.2
	rapier.color = BLADE_COLOR
	dagger.color = BLADE_COLOR
	trail.clear_points()
