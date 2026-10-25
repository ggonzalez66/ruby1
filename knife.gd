extends Node2D

# Lanza espiritual jade: una marca activa, con quemadura periódica no letal.
# Recall devuelve la lanza y atrae a cada enemigo atravesado; conserva la ejecución si está open.
# Se clava también en el terreno hasta que se llama de vuelta.
# - Algunos enemigos lo shinean de vuelta: viaja hostil hacia Rengar (que lo puede volver a shinear).

const FIRE_VISUAL := preload("res://jade_fire_visual.gd")
const JADE_MARK := preload("res://jade_mark.gd")
const RETURN_SPEED := 1800.0
const BURN_DURATION := 2.0
const KNIFE_TEXTURE: Texture2D = preload("res://spirit_spear_visual.gd").TEXTURE
# La punta mira hacia la derecha y se orienta con la trayectoria.
const TIP_ANGLE := 0.0
# Lanza al doble de tamaño visual; conserva la hurtbox de 52 × 18.
const VISUAL_SCALE := 0.20
const TRAIL_LENGTH := 9

const GRAVITY := 1100.0
const WORLD_MASK := 2
const ENEMY_MASK := 8
# Hitbox alargada a lo largo de la hoja (gira con el cuchillo), a la medida del sprite.
const HIT_LENGTH := 52.0
const HIT_WIDTH := 18.0
const PULL_STRENGTH := 70.0
const SHINE_SPEED := 1300.0
# Tras un shine vuela recto (sin gravedad) este tiempo; si no encuentra nada, empieza a caer.
const SHINE_STRAIGHT_TIME := 0.9
const HOSTILE_SPEED := 900.0
const HOSTILE_DAMAGE := 10
const HOSTILE_TIME := 2.5
const RIPOSTE_COLOR := Color(1.0, 0.12, 0.08)

enum State { FLYING, MARKED, RETURNING, HOSTILE, STUCK_WORLD }

var state := State.FLYING
var velocity := Vector2.ZERO
var player: Node2D
var target: Node2D
var target_offset := Vector2.ZERO
var recall_hits: Array = []
var sprite: Sprite2D
var trail: Line2D
# El riposte conserva la apariencia potenciada; la marca y el recall no hacen daño.
var empowered := false
var hit_any := false
# Veces que se ha shineado (Rengar o enemigos) y cuántas fueron de Rengar (para el "SHINE KNIFE xN").
var shine_level := 0
var player_shines := 0
var straight_timer := 0.0
var hostile_timer := 0.0
var last_target: Node2D
var trail_gradient: Gradient
# Resaltado al intentar atacar sin él: anillo rojo pulsante y destello (el rojo del aviso sobre Rengar).
const HIGHLIGHT_TIME := 0.8
const HIGHLIGHT_COLOR := Color(1.0, 0.25, 0.2)
var highlight_timer := 0.0
var flame_time := 0.0
var life := 4.0
var released := false
var mark_effect: Node2D
@export var burn_tick_interval := 1.0
@export var burn_tick_damage := 1
var burn_left := 1.0
var burn_duration_left := BURN_DURATION
var embedded_angle := 0.0

func _ready() -> void:
	z_index = 2
	# Estela plateada que sigue al cuchillo mientras vuela o vuelve.
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 9.0
	trail_gradient = Gradient.new()
	trail_gradient.set_color(0, Color(FIRE_VISUAL.COLOR, 0.0))
	trail_gradient.set_color(1, Color(0.73, 0.88, 0.58, 0.75))
	trail.gradient = trail_gradient
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.1))
	width_curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = width_curve
	add_child(trail)
	sprite = Sprite2D.new()
	sprite.texture = KNIFE_TEXTURE
	sprite.hframes = 2
	sprite.vframes = 2
	sprite.scale = Vector2.ONE * VISUAL_SCALE
	add_child(sprite)

func launch(owner_player: Node2D, start: Vector2, initial_velocity: Vector2) -> void:
	player = owner_player
	global_position = start
	velocity = initial_velocity
	state = State.FLYING
	_point_along(velocity)

func is_returning() -> bool:
	return state == State.RETURNING

func recall() -> void:
	if state in [State.HOSTILE, State.RETURNING] or released:
		return
	if not is_instance_valid(player):
		_release()
		return
	if state == State.MARKED and _is_target_alive(target):
		if player.try_soul_execution(target):
			_release()
			return
	state = State.RETURNING
	_clear_mark()
	target = null
	recall_hits.clear()
	rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.show()
	life = 4.0
	Sfx.play("soul_snap")

func _clear_mark() -> void:
	if is_instance_valid(mark_effect):
		mark_effect.queue_free()
	mark_effect = null

func _return_to_player(delta: float) -> void:
	if not is_instance_valid(player) or player.dead:
		_release()
		return
	var goal := player.global_position + Vector2(0, -16)
	var from := global_position
	var to := from.move_toward(goal, RETURN_SPEED * delta)
	velocity = (goal - from).normalized() * RETURN_SPEED
	_point_along(velocity)
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK))
	if not wall.is_empty():
		to = wall.position
	# Barre todo el trayecto, también con velocidades altas y varios enemigos por frame.
	var rect := RectangleShape2D.new()
	rect.size = Vector2(from.distance_to(to) + HIT_LENGTH, HIT_WIDTH)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D((to - from).angle(), (from + to) * 0.5)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var excluded: Array[RID] = []
	while true:
		query.exclude = excluded
		var hits := get_world_2d().direct_space_state.intersect_shape(query, 32)
		if hits.is_empty():
			break
		for hit in hits:
			excluded.append(hit.rid)
			var enemy: Node2D = hit.collider
			if enemy in recall_hits or not enemy.has_method("take_hit") or not _is_target_alive(enemy):
				continue
			var ray := PhysicsRayQueryParameters2D.create(from, _target_center(enemy), WORLD_MASK)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			recall_hits.append(enemy)
			if enemy.has_method("pull_towards"):
				enemy.pull_towards(player.global_position, PULL_STRENGTH)
			elif enemy.has_method("on_shine_hit"):
				enemy.on_shine_hit(int(signf(player.global_position.x - enemy.global_position.x)), PULL_STRENGTH * 5.0)
			Ferocity.add("soul_pull", 8.0, "SOUL PULL")
			Fx.impact(get_parent(), _target_center(enemy), [FIRE_VISUAL.COLOR.darkened(0.6), FIRE_VISUAL.COLOR, Color(0.85, 1.0, 0.8)], 0.5)
	global_position = to
	if not wall.is_empty() or to.is_equal_approx(goal):
		_release()

func _release() -> void:
	if released:
		return
	released = true
	if is_instance_valid(player):
		player.on_knife_caught(self)
	queue_free()

func highlight() -> void:
	highlight_timer = HIGHLIGHT_TIME

func _process(delta: float) -> void:
	if highlight_timer > 0.0 or is_queued_for_deletion():
		highlight_timer = max(highlight_timer - delta / max(Engine.time_scale, 0.01), 0.0)
		queue_redraw()

func _draw() -> void:
	if highlight_timer <= 0.0:
		return
	# Anillo que late y se cierra sobre el cuchillo (sin girar con él).
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	var progress: float = 1.0 - highlight_timer / HIGHLIGHT_TIME
	var pulse: float = 0.5 + 0.5 * sin(progress * TAU * 3.0)
	var alpha: float = clamp(highlight_timer / 0.25, 0.0, 1.0)
	var radius: float = lerp(34.0, 20.0, progress) + 3.0 * pulse
	draw_circle(Vector2.ZERO, radius, Color(HIGHLIGHT_COLOR, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.03, 0.02, 0.8 * alpha), 5.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(HIGHLIGHT_COLOR, alpha), 2.5, true)

func _physics_process(delta: float) -> void:
	flame_time += delta
	sprite.frame = int(flame_time * 14.0) % 4
	_update_trail()
	_update_look()
	if state == State.STUCK_WORLD:
		return
	if state == State.MARKED:
		rotation = 0.0
		if not _is_target_alive(target):
			_release()
			return
		global_position = _target_center(target)
		_update_burn(delta)
		return
	life -= delta
	if life <= 0.0:
		_release()
		return
	match state:
		State.FLYING:
			_fly(delta)
		State.HOSTILE:
			_fly_hostile(delta)
		State.RETURNING:
			_return_to_player(delta)

func _fly(delta: float) -> void:
	if straight_timer > 0.0:
		straight_timer -= delta
	else:
		velocity.y += GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal * 1.0
		_stick_in_world()
		return

	global_position = to
	# El núcleo encabeza la trayectoria y la cola de fuego queda atrás.
	_point_along(velocity)
	if state == State.FLYING:
		var enemy := _find_enemy(recall_hits)
		if enemy:
			_stick_in_enemy(enemy)

func _stick_in_world() -> void:
	state = State.STUCK_WORLD
	embedded_angle = velocity.angle()
	rotation = 0.0
	sprite.rotation = embedded_angle
	sprite.position = -Vector2.from_angle(embedded_angle) * 40.0
	sprite.show()
	trail.clear_points()
	Sfx.play("knife_hit")

func _stick_in_enemy(enemy: Node2D) -> void:
	# Algunos enemigos lo shinean de vuelta en vez de dejar que se clave.
	if enemy.has_method("try_shine") and enemy.try_shine(self):
		_enemy_shine(enemy)
		return
	Ferocity.add("knife_mark", 8.0, "LANZA JADE")
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	state = State.MARKED
	hit_any = true
	sprite.show()
	trail.clear_points()
	straight_timer = 0.0
	target = enemy
	last_target = enemy
	target_offset = enemy.to_local(global_position)
	embedded_angle = velocity.angle()
	sprite.rotation = embedded_angle
	sprite.position = -Vector2.from_angle(embedded_angle) * 40.0
	burn_duration_left = BURN_DURATION
	burn_left = maxf(burn_tick_interval, 0.01)
	rotation = 0.0
	global_position = _target_center(target)
	mark_effect = JADE_MARK.new()
	mark_effect.target = target
	add_child(mark_effect)

func _update_burn(delta: float) -> void:
	if burn_duration_left <= 0.0:
		return
	var active_delta := minf(delta, burn_duration_left)
	burn_duration_left = maxf(burn_duration_left - delta, 0.0)
	var core: Node2D = target.get_node_or_null("RubyCore")
	if core != null:
		if core.locked or core.final_open:
			burn_left = maxf(burn_tick_interval, 0.01)
		else:
			burn_left -= active_delta
			while burn_left <= 0.00001:
				burn_left += maxf(burn_tick_interval, 0.01)
				core.apply_spirit_burn(burn_tick_damage)
	if burn_duration_left <= 0.0:
		_clear_mark()

func _aura_reaches_segment(from: Vector2, to: Vector2) -> bool:
	if not is_instance_valid(player) or not player.is_roar_aura_active():
		return false
	var center: Vector2 = player.get_roar_center()
	return Geometry2D.get_closest_point_to_segment(center, from, to).distance_to(center) <= player.roar_radius + 8.0

func _player_aura_reaches() -> bool:
	return is_instance_valid(player) and player.is_roar_aura_active() and global_position.distance_to(player.get_roar_center()) <= player.roar_radius + 8.0

func _player_shine() -> void:
	# Sale recto y rápido hacia el último enemigo en que estuvo clavado (o por donde vino).
	var from_enemy: bool = state == State.HOSTILE
	var perfect: bool = player.has_method("is_perfect_shine") and player.is_perfect_shine()
	shine_level += 2 if perfect and from_enemy else 1
	player_shines += 1
	recall_hits.clear()
	var direction: Vector2 = -velocity.normalized()
	if _is_target_alive(last_target):
		direction = (_target_center(last_target) - global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2(float(player.facing), 0.0)
	velocity = direction * SHINE_SPEED * (player.perfect_reflect_speed if perfect and from_enemy else 1.0)
	state = State.FLYING
	straight_timer = SHINE_STRAIGHT_TIME
	Fx.impact(get_parent(), global_position, Fx.ROAR, 1.2)
	if player.has_method("on_knife_shined"):
		player.on_knife_shined(self)
	# Si venía devuelto por un enemigo, cuenta como devolver un proyectil (gasta durabilidad salvo perfect).
	if from_enemy and player.has_method("on_projectile_reflected"):
		player.on_projectile_reflected(perfect)

func _enemy_shine(enemy: Node2D) -> void:
	shine_level += 1
	state = State.HOSTILE
	hostile_timer = HOSTILE_TIME
	straight_timer = 0.0
	target = null
	last_target = enemy
	var goal: Vector2 = player.get_roar_center() if is_instance_valid(player) else global_position - velocity
	velocity = (goal - global_position).normalized() * HOSTILE_SPEED
	Fx.text(get_parent(), global_position + Vector2(0, -30), "¡SHINE!", Shine.color(shine_level, false).lightened(0.3))

func _fly_hostile(delta: float) -> void:
	if is_instance_valid(player) and player.wrath_aura_reaches(global_position, global_position + velocity * delta):
		_release()
		return
	# Devuelto por un enemigo: recto hacia Rengar. Si lo alcanza le hace daño y vuelve a su mano.
	hostile_timer -= delta
	if not is_instance_valid(player):
		queue_free()
		return
	if _player_aura_reaches():
		_player_shine()
		return
	var from := global_position
	var to := from + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK))
	if not hit.is_empty():
		global_position = hit.position
		_stick_in_world()
		return
	global_position = to
	_point_along(velocity)
	if global_position.distance_to(player.global_position + Vector2(0, -16)) <= 24.0 and not player.dead:
		player.take_damage(Shine.damage(HOSTILE_DAMAGE, shine_level), global_position)
		if player.has_method("on_knife_caught"):
			player.on_knife_caught(self)
		queue_free()
		return
	if hostile_timer <= 0.0:
		_release()

func _target_center(node: Node2D) -> Vector2:
	var offset = node.get("impact_offset")
	return node.global_position + (offset if offset is Vector2 else Vector2.ZERO)

func _update_look() -> void:
	# Más grande con cada shine; rojo parpadeante en riposte; tono enemigo si viene hacia Rengar.
	sprite.scale = Vector2.ONE * VISUAL_SCALE * Shine.visual_scale(shine_level + 1 if shine_level > 0 else 0)
	var tint := Color.WHITE
	var trail_color := FIRE_VISUAL.COLOR.lightened(0.25)
	if state == State.HOSTILE:
		trail_color = Shine.color(shine_level, false)
		tint = Color.WHITE.lerp(trail_color, 0.6)
	elif empowered:
		var blink: bool = int(Time.get_ticks_msec() / 70) % 2 == 0
		tint = RIPOSTE_COLOR.lightened(0.25) if blink else Color(1.0, 0.7, 0.65)
		trail_color = RIPOSTE_COLOR
	elif shine_level > 0:
		trail_color = Shine.color(shine_level, true)
		tint = Color.WHITE.lerp(trail_color, 0.35)
	if highlight_timer > 0.0:
		# Destello rojo parpadeante mientras está resaltado.
		var flash: bool = int(highlight_timer * 14.0) % 2 == 0
		tint = tint.lerp(Color(1.6, 0.45, 0.4), 0.7 if flash else 0.25)
	sprite.modulate = tint
	trail.width = 9.0 * (1.0 + 0.25 * min(shine_level, 4))
	trail_gradient.set_color(0, Color(trail_color, 0.0))
	trail_gradient.set_color(1, Color(trail_color, 0.8))

func _find_enemy(exclude: Array) -> Node2D:
	var rect := RectangleShape2D.new()
	# Crece con el cuchillo (shine) y sigue la orientación de la hoja.
	rect.size = Vector2(HIT_LENGTH, HIT_WIDTH) * (sprite.scale.x / VISUAL_SCALE)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(rotation + TIP_ANGLE, global_position)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var collider: Object = result.collider
		if collider in exclude or not collider.has_method("take_hit"):
			continue
		if _is_target_alive(collider):
			return collider
	return null

func _is_target_alive(node: Object) -> bool:
	return is_instance_valid(node) and node.visible and node.get("monitorable") != false

func _update_trail() -> void:
	var moving: bool = state in [State.FLYING, State.HOSTILE, State.RETURNING]
	if moving:
		trail.add_point(global_position)
		while trail.get_point_count() > TRAIL_LENGTH:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)

func _point_along(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		rotation = direction.angle() - TIP_ANGLE
