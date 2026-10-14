extends "res://boss_base.gd"

# Guardián arquero: gigante alto con un arco enorme. Mantiene la distancia y dispara:
# - Disparo apuntado (tensa la cuerda y dispara hacia Rengar).
# - Ráfaga de 3 flechas en abanico.
# - Lluvia de flechas: marca el suelo en rojo y luego caen desde arriba.
# Si Rengar se queda cerca demasiado rato, se reposiciona con un backflip o teletransportándose.
# Todas las flechas se pueden devolver con el rugido.

@export var preferred_distance := 520.0
@export var close_distance := 260.0
@export var close_time_limit := 2.0
@export var walk_speed := 90.0
@export var arrow_damage := 14
@export var rain_damage := 16
@export var reflected_arrow_damage := 7

const PROJECTILE_SCRIPT := preload("res://projectile.gd")
const ROBE_COLOR := Color(0.24, 0.3, 0.2)
const ROBE_DARK := Color(0.14, 0.18, 0.12)
const HOOD_COLOR := Color(0.18, 0.22, 0.15)
const EYE_COLOR := Color(0.6, 1.0, 0.75)
const BOW_COLOR := Color(0.55, 0.36, 0.18)
const STRING_COLOR := Color(0.92, 0.9, 0.82)
const BOW_RADIUS := 120.0
const BOW_SPAN := 0.95

enum State { IDLE, AIM, VOLLEY_AIM, RAIN_AIM, RECOVER, BACKFLIP, TELEPORT_OUT, TELEPORT_IN, STAGGER }

var state := State.IDLE
var state_timer := 1.0
var attack_index := 0
var close_timer := 0.0
var aim_angle := 0.0
var flip_from := Vector2.ZERO
var flip_to := Vector2.ZERO
var rain_markers: Array = []
var quick_shot := false

var bow_pivot: Node2D
var bow_line: Line2D
var string_line: Line2D
var nocked_arrow: Node2D

func _configure() -> void:
	body_size = Vector2(60, 230)
	impact_offset = Vector2(0, -120)
	# A veces devuelve con un shine las flechas devueltas y el cuchillo.
	shine_chance = 0.2

func _build_body() -> void:
	# Piernas largas, túnica, capucha con un ojo brillante.
	visual.add_child(_poly([Vector2(-16, 0), Vector2(-6, 0), Vector2(-4, -90), Vector2(-14, -90)], ROBE_DARK))
	visual.add_child(_poly([Vector2(6, 0), Vector2(16, 0), Vector2(14, -90), Vector2(4, -90)], ROBE_DARK))
	visual.add_child(_add_flash_poly(_poly([Vector2(-26, -80), Vector2(26, -80), Vector2(20, -200), Vector2(-20, -200)], ROBE_COLOR)))
	visual.add_child(_poly([Vector2(-26, -86), Vector2(26, -86), Vector2(26, -80), Vector2(-26, -80)], Color(0.6, 0.45, 0.2)))
	visual.add_child(_poly([Vector2(-18, -200), Vector2(18, -200), Vector2(12, -238), Vector2(-4, -246), Vector2(-16, -230)], HOOD_COLOR))
	visual.add_child(_poly([Vector2(4, -222), Vector2(12, -222), Vector2(12, -216), Vector2(4, -216)], EYE_COLOR))
	# Arco gigante: pivota en las manos y apunta hacia +x.
	bow_pivot = Node2D.new()
	bow_pivot.position = Vector2(22, -140)
	visual.add_child(bow_pivot)
	bow_line = Line2D.new()
	bow_line.width = 7.0
	bow_line.default_color = BOW_COLOR
	for index in range(17):
		var angle: float = lerp(-BOW_SPAN, BOW_SPAN, index / 16.0)
		bow_line.add_point(Vector2(-60.0 + cos(angle) * BOW_RADIUS, sin(angle) * BOW_RADIUS))
	bow_pivot.add_child(bow_line)
	string_line = Line2D.new()
	string_line.width = 1.5
	string_line.default_color = STRING_COLOR
	bow_pivot.add_child(string_line)
	nocked_arrow = Node2D.new()
	nocked_arrow.add_child(_poly([Vector2(0, -1.5), Vector2(70, -1.5), Vector2(70, 1.5), Vector2(0, 1.5)], Color(0.45, 0.3, 0.18)))
	nocked_arrow.add_child(_poly([Vector2(68, -6), Vector2(84, 0), Vector2(68, 6)], Color(0.8, 0.8, 0.85)))
	bow_pivot.add_child(nocked_arrow)
	_set_draw(0.0)

func _set_draw(amount: float) -> void:
	# amount 0 = cuerda suelta, 1 = tensada al máximo (con la flecha montada).
	var string_end_x: float = -60.0 + cos(BOW_SPAN) * BOW_RADIUS
	var string_end_y: float = sin(BOW_SPAN) * BOW_RADIUS
	var pull_x: float = string_end_x - amount * 55.0
	string_line.points = PackedVector2Array([Vector2(string_end_x, -string_end_y), Vector2(pull_x, 0), Vector2(string_end_x, string_end_y)])
	nocked_arrow.visible = amount > 0.05
	nocked_arrow.position = Vector2(pull_x, 0)

func _boss_process(delta: float, player: Node2D) -> void:
	state_timer -= delta
	if not state in [State.AIM, State.VOLLEY_AIM]:
		# Tras un shine el arco vuelve poco a poco a su color.
		bow_line.default_color = bow_line.default_color.lerp(BOW_COLOR, 6.0 * delta)
	if player and state in [State.IDLE, State.RECOVER, State.AIM, State.VOLLEY_AIM]:
		close_timer = close_timer + delta if _distance_to(player) < close_distance else max(close_timer - delta, 0.0)
	match state:
		State.IDLE:
			_face(player)
			_aim_at(player, delta)
			# Ya en combate, sigue disparando aunque Rengar se aleje (mientras esté en la arena).
			if player == null or abs(player.global_position.y - global_position.y) > 400.0:
				return
			if close_timer > close_time_limit:
				_reposition(player)
				return
			# Mantiene la distancia: se acerca si está lejos, retrocede despacio si está cerca.
			var distance := _distance_to(player)
			if distance > preferred_distance + 260.0:
				_move(facing * walk_speed * delta)
			elif distance < close_distance:
				_move(-facing * walk_speed * 0.8 * delta)
			if state_timer <= 0.0:
				_choose_attack(player)
		State.AIM, State.VOLLEY_AIM:
			var duration: float = (0.35 if quick_shot else 0.55) if state == State.AIM else 0.7
			var progress: float = clamp(1.0 - state_timer / duration, 0.0, 1.0)
			_face(player)
			_aim_at(player, delta)
			_set_draw(ease(progress, 0.5))
			bow_line.default_color = BOW_COLOR.lerp(WARNING_COLOR, 0.5 + 0.5 * sin(progress * progress * 40.0))
			if state_timer <= 0.0:
				if state == State.AIM:
					_shoot([0.0], 820.0)
				else:
					_shoot([-0.16, 0.0, 0.16], 700.0)
				_release()
		State.RAIN_AIM:
			# Apunta al cielo; las marcas rojas del suelo parpadean hasta que caen las flechas.
			bow_pivot.rotation = lerp_angle(bow_pivot.rotation, -1.35, 8.0 * delta)
			var progress: float = clamp(1.0 - state_timer / 0.9, 0.0, 1.0)
			_set_draw(ease(progress, 0.5))
			for marker in rain_markers:
				marker.modulate.a = 0.4 + 0.6 * float(int(state_timer * 16.0) % 2)
			if state_timer <= 0.0:
				_drop_rain()
				_release()
		State.RECOVER, State.STAGGER:
			_face(player)
			_aim_at(player, delta)
			if state_timer <= 0.0:
				state = State.IDLE
				state_timer = 0.6
		State.BACKFLIP:
			# Backflip hacia atrás en arco, girando una vuelta completa.
			var progress: float = clamp(1.0 - state_timer / 0.6, 0.0, 1.0)
			var x: float = lerp(flip_from.x, flip_to.x, progress)
			position = Vector2(clamp(x, min_x, max_x), flip_from.y - sin(progress * PI) * 180.0)
			visual.rotation = -sign(flip_to.x - flip_from.x) * TAU * progress
			if state_timer <= 0.0:
				position.y = flip_from.y
				visual.rotation = 0.0
				_quick_shot(player)
		State.TELEPORT_OUT:
			visual.modulate.a = clamp(state_timer / 0.3, 0.0, 1.0)
			if state_timer <= 0.0:
				# Reaparece en el lado de la arena más alejado de Rengar.
				var center: float = (min_x + max_x) * 0.5
				position.x = max_x - 120.0 if player and player.global_position.x < center + get_parent().global_position.x else min_x + 120.0
				Fx.puff(get_parent(), global_position + Vector2(0, -120), Color(0.6, 1.0, 0.75, 0.8))
				state = State.TELEPORT_IN
				state_timer = 0.3
		State.TELEPORT_IN:
			visual.modulate.a = clamp(1.0 - state_timer / 0.3, 0.0, 1.0)
			if state_timer <= 0.0:
				visual.modulate.a = 1.0
				_quick_shot(player)

func _choose_attack(player: Node2D) -> void:
	var pattern := [State.AIM, State.VOLLEY_AIM, State.AIM, State.RAIN_AIM]
	var next: State = pattern[attack_index % pattern.size()]
	attack_index += 1
	quick_shot = false
	warning_label.visible = true
	state = next
	match next:
		State.AIM:
			state_timer = 0.55
		State.VOLLEY_AIM:
			state_timer = 0.7
		State.RAIN_AIM:
			state_timer = 0.9
			_place_rain_markers(player)

func _quick_shot(player: Node2D) -> void:
	_face(player)
	close_timer = 0.0
	quick_shot = true
	warning_label.visible = true
	state = State.AIM
	state_timer = 0.35

func _release() -> void:
	warning_label.visible = false
	bow_line.default_color = BOW_COLOR
	_set_draw(0.0)
	state = State.RECOVER
	state_timer = 0.7

func _aim_at(player: Node2D, delta: float) -> void:
	if player == null:
		return
	# El arco apunta al cuerpo de Rengar (en el espacio del arquero, que ya está girado hacia él).
	var target: Vector2 = visual.to_local(player.global_position + Vector2(0, -16)) - bow_pivot.position
	aim_angle = clamp(target.angle(), -1.2, 1.2)
	bow_pivot.rotation = lerp_angle(bow_pivot.rotation, aim_angle, 10.0 * delta)

func _shoot(spreads: Array, speed: float) -> void:
	var base_direction := Vector2.RIGHT.rotated(bow_pivot.global_rotation)
	if visual.scale.x < 0.0:
		base_direction = Vector2.RIGHT.rotated(PI - bow_pivot.rotation)
	for spread in spreads:
		var direction: Vector2 = base_direction.rotated(float(spread) * facing)
		_spawn_arrow(bow_pivot.global_position + direction * 50.0, direction * speed, arrow_damage)

func _place_rain_markers(player: Node2D) -> void:
	_clear_markers()
	if player == null:
		return
	for offset in [-130.0, 0.0, 130.0]:
		var marker := _poly([Vector2(-26, -3), Vector2(26, -3), Vector2(20, 3), Vector2(-20, 3)], Color(1.0, 0.2, 0.15, 0.85))
		get_parent().add_child(marker)
		marker.global_position = Vector2(player.global_position.x + offset, global_position.y - 2.0)
		rain_markers.append(marker)

func _drop_rain() -> void:
	for marker in rain_markers:
		var top: Vector2 = marker.global_position + Vector2(0, -620)
		_spawn_arrow(top, Vector2(0, 950), rain_damage)
	_clear_markers()

func _spawn_arrow(origin: Vector2, arrow_velocity: Vector2, damage: int) -> void:
	var arrow := PROJECTILE_SCRIPT.new()
	arrow.style = "arrow"
	arrow.velocity = arrow_velocity
	arrow.damage = damage
	arrow.reflected_damage = reflected_arrow_damage
	arrow.shooter = self
	get_parent().add_child(arrow)
	arrow.global_position = origin

func _clear_markers() -> void:
	for marker in rain_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	rain_markers.clear()

func _reposition(player: Node2D) -> void:
	close_timer = 0.0
	warning_label.visible = false
	_set_draw(0.0)
	if randf() < 0.5:
		var away: float = -1.0 if player.global_position.x >= global_position.x else 1.0
		flip_from = position
		flip_to = position + Vector2(away * 380.0, 0)
		state = State.BACKFLIP
		state_timer = 0.6
	else:
		Fx.puff(get_parent(), global_position + Vector2(0, -120), Color(0.6, 1.0, 0.75, 0.8))
		state = State.TELEPORT_OUT
		state_timer = 0.3

func _move(amount: float) -> void:
	position.x = clamp(position.x + amount, min_x, max_x)

func is_warning() -> bool:
	return state in [State.AIM, State.VOLLEY_AIM, State.RAIN_AIM]

func _on_hit(_damage: int) -> void:
	# Una flecha devuelta o un golpe fuerte interrumpe la lluvia.
	if state == State.RAIN_AIM and randf() < 0.3:
		_clear_markers()
		_release()

func _shine_color() -> Color:
	return EYE_COLOR

func _on_shine() -> void:
	# El arco destella con el color del ojo.
	bow_line.default_color = EYE_COLOR
	Fx.text(get_parent(), global_position + Vector2(0, -260), "¡SHINE!", EYE_COLOR)

func _on_defeat() -> void:
	_clear_markers()
	_set_draw(0.0)

func _on_reset() -> void:
	state = State.IDLE
	state_timer = 1.0
	attack_index = 0
	close_timer = 0.0
	visual.modulate.a = 1.0
	bow_line.default_color = BOW_COLOR
	_clear_markers()
	_set_draw(0.0)
