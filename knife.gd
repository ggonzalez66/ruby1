extends Node2D

# Cuchillo lanzado por Rengar: vuela en arco, se clava en enemigos o en el escenario
# (a veces cae suelto) y vuelve a la mano al hacer recall, golpeando por el camino.
# - Riposte (lanzado justo tras un parry o devolver un proyectil): rojo parpadeante, pega el doble
#   y al sacarlo (recall) cura, si ya golpeó algo.
# - Shine knife: si vuelve mientras el aura del rugido está activa, sale disparado en línea recta
#   contra el último enemigo en que estuvo clavado y se vuelve a enterrar; así se encadenan.
# - Algunos enemigos lo shinean de vuelta: viaja hostil hacia Rengar (que lo puede volver a shinear).

const KNIFE_TEXTURE: Texture2D = preload("res://assets/sprites/player/rengar_knife.png")
const KNIFE_REGION := Rect2(48, 271, 243, 227)
# En el sprite la punta apunta hacia arriba a la izquierda (unos -138°).
const TIP_ANGLE := -2.415
const VISUAL_SCALE := 0.13
const SPIN_SPEED := 24.0
const TRAIL_LENGTH := 9
const BOUNCE_RESTITUTION := 0.55
const REST_SPEED := 90.0

const GRAVITY := 1100.0
const WORLD_MASK := 2
const ENEMY_MASK := 8
const HIT_RADIUS := 14.0
const DAMAGE_THROW := 2
const DAMAGE_RECALL := 1
const DROP_CHANCE := 0.15
const PULL_STRENGTH := 70.0
const RETURN_START_SPEED := 500.0
const RETURN_MAX_SPEED := 1500.0
const RETURN_ACCELERATION := 3200.0
const SHINE_SPEED := 1300.0
# Tras un shine vuela recto (sin gravedad) este tiempo; si no encuentra nada, empieza a caer.
const SHINE_STRAIGHT_TIME := 0.9
const HOSTILE_SPEED := 900.0
const HOSTILE_DAMAGE := 10
const HOSTILE_TIME := 2.5
const RIPOSTE_COLOR := Color(1.0, 0.12, 0.08)

enum State { FLYING, FALLING, STUCK_ENEMY, STUCK_WORLD, BOUNCING, DROPPED, RETURNING, HOSTILE }

var state := State.FLYING
var velocity := Vector2.ZERO
var player: Node2D
var target: Node2D
var target_offset := Vector2.ZERO
var was_dropped := false
var return_speed := 0.0
var recall_hits: Array = []
var sprite: Sprite2D
var trail: Line2D
var spin_direction := 1.0
# Riposte: doble daño y cura al sacarlo si golpeó algo (una vez).
var empowered := false
var hit_any := false
var riposte_healed := false
# Veces que se ha shineado (Rengar o enemigos) y cuántas fueron de Rengar (para el "SHINE KNIFE xN").
var shine_level := 0
var player_shines := 0
var straight_timer := 0.0
var hostile_timer := 0.0
var last_target: Node2D
var return_direction := Vector2.ZERO
var trail_gradient: Gradient
# Resaltado al intentar atacar sin él: anillo rojo pulsante y destello (el rojo del aviso sobre Rengar).
const HIGHLIGHT_TIME := 0.8
const HIGHLIGHT_COLOR := Color(1.0, 0.25, 0.2)
var highlight_timer := 0.0

func _ready() -> void:
	z_index = 2
	# Estela plateada que sigue al cuchillo mientras vuela o vuelve.
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 9.0
	trail_gradient = Gradient.new()
	trail_gradient.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	trail_gradient.set_color(1, Color(1.0, 0.95, 0.75, 0.75))
	trail.gradient = trail_gradient
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.1))
	width_curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = width_curve
	add_child(trail)
	sprite = Sprite2D.new()
	sprite.texture = KNIFE_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = KNIFE_REGION
	sprite.scale = Vector2.ONE * VISUAL_SCALE
	add_child(sprite)

func launch(owner_player: Node2D, start: Vector2, initial_velocity: Vector2) -> void:
	player = owner_player
	global_position = start
	velocity = initial_velocity
	state = State.FLYING
	spin_direction = 1.0 if velocity.x >= 0.0 else -1.0
	_point_along(velocity)

func is_returning() -> bool:
	return state == State.RETURNING

func recall() -> void:
	# Si un enemigo lo devolvió, no se puede llamar: hay que esquivarlo o shinearlo.
	if state == State.RETURNING or state == State.HOSTILE:
		return
	if empowered and hit_any and not riposte_healed and is_instance_valid(player):
		riposte_healed = true
		player.on_riposte_knife_pulled()
	# Al arrancarlo de un enemigo lo golpea otra vez.
	if state == State.STUCK_ENEMY and _is_target_alive(target):
		_recall_hit(target)
	state = State.RETURNING
	return_speed = RETURN_START_SPEED

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
	_update_trail()
	_update_look()
	match state:
		State.FLYING, State.FALLING, State.BOUNCING:
			_fly(delta)
		State.HOSTILE:
			_fly_hostile(delta)
		State.STUCK_ENEMY:
			if _is_target_alive(target):
				global_position = target.to_global(target_offset)
			else:
				# El enemigo murió: el cuchillo cae desde ahí.
				state = State.FALLING
				velocity = Vector2(0.0, 60.0)
		State.RETURNING:
			_return(delta)

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
		if state == State.BOUNCING:
			_bounce_again(hit.normal)
		elif randf() < DROP_CHANCE:
			_bounce_off(hit.normal)
		else:
			global_position = hit.position
			_stick_in_world()
		return

	global_position = to
	# Gira sobre sí mismo mientras vuela.
	rotation += SPIN_SPEED * delta * spin_direction
	if state == State.FLYING:
		var enemy := _find_enemy(recall_hits)
		if enemy:
			_stick_in_enemy(enemy)

func _stick_in_world() -> void:
	state = State.STUCK_WORLD
	was_dropped = false
	# Se clava con la punta por delante en la dirección en que iba.
	_point_along(velocity)
	global_position += velocity.normalized() * 4.0

func _bounce_off(normal: Vector2) -> void:
	# 15% de las veces no se clava: rebota libremente hasta quedar tirado.
	state = State.BOUNCING
	was_dropped = true
	velocity = velocity.bounce(normal) * BOUNCE_RESTITUTION
	spin_direction = 1.0 if velocity.x >= 0.0 else -1.0

func _bounce_again(normal: Vector2) -> void:
	velocity = velocity.bounce(normal) * BOUNCE_RESTITUTION
	# Sobre el suelo y casi sin velocidad: se queda tirado.
	if normal.y < -0.5 and velocity.length() < REST_SPEED:
		_lie_down(normal)

func _lie_down(normal: Vector2) -> void:
	state = State.DROPPED
	global_position += normal * 3.0
	rotation = -TIP_ANGLE if velocity.x >= 0.0 else PI - TIP_ANGLE

func _stick_in_enemy(enemy: Node2D) -> void:
	# Algunos enemigos lo shinean de vuelta en vez de dejar que se clave.
	if enemy.has_method("try_shine") and enemy.try_shine(self):
		_enemy_shine(enemy)
		return
	var direction: int = 1 if velocity.x >= 0.0 else -1
	enemy.take_hit(global_position, direction, _damage(DAMAGE_THROW))
	Ferocity.add("knife", 12.0, "CUCHILLO")
	_on_damage_dealt()
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	state = State.STUCK_ENEMY
	straight_timer = 0.0
	was_dropped = false
	target = enemy
	last_target = enemy
	target_offset = enemy.to_local(global_position)

func _return(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	var goal: Vector2 = player.global_position + Vector2(0.0, -16.0)
	var offset := goal - global_position
	return_speed = min(return_speed + RETURN_ACCELERATION * delta, RETURN_MAX_SPEED)
	var step: float = return_speed * delta
	# Shine knife: el aura del rugido lo despide de nuevo antes de que llegue a la mano. Se mira antes
	# de atraparlo (y en todo el tramo de este frame): si no, a veces entraba en la mano de un salto.
	if _player_aura_reaches() or _aura_reaches_segment(global_position, global_position + offset.normalized() * min(step, offset.length())):
		_player_shine()
		return
	if offset.length() <= step + 14.0:
		if player.has_method("on_knife_caught"):
			player.on_knife_caught(self)
		queue_free()
		return
	var move := offset.normalized() * step
	return_direction = move.normalized()
	global_position += move
	rotation += SPIN_SPEED * delta * (1.0 if move.x >= 0.0 else -1.0)
	var enemy := _find_enemy(recall_hits)
	if enemy:
		_recall_hit(enemy)

func _recall_hit(enemy: Node2D) -> void:
	recall_hits.append(enemy)
	var direction: int = 1 if player.global_position.x >= enemy.global_position.x else -1
	enemy.take_hit(global_position, direction, _damage(DAMAGE_RECALL))
	_on_damage_dealt()
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	# Si el cuchillo estaba tirado en el suelo solo golpea; si no, atrae hacia Rengar.
	if not was_dropped and enemy.has_method("pull_towards"):
		Ferocity.add("knife_pull", 15.0, "ATRAÍDO")
		enemy.pull_towards(player.global_position, PULL_STRENGTH)

# ---------- Shine y riposte

func _damage(base: int) -> int:
	# El primer shine de Rengar ya pega más que un lanzamiento normal; el riposte lo duplica.
	var amount: float = base * Ferocity.damage_multiplier() * Shine.multiplier(shine_level + 1)
	if empowered:
		amount *= 2.0
	return int(round(amount))

func _on_damage_dealt() -> void:
	if empowered and not hit_any:
		Fx.text(get_parent(), global_position + Vector2(0, -30), "¡RIPOSTE!", Color(1.0, 0.4, 0.3))
		Ferocity.add("ranged_riposte", 40.0, "RIPOSTE A DISTANCIA", Ferocity.BONUS_COLOR)
	hit_any = true

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
	var direction: Vector2 = -return_direction if state == State.RETURNING else -velocity.normalized()
	if _is_target_alive(last_target):
		direction = (_target_center(last_target) - global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2(float(player.facing), 0.0)
	velocity = direction * SHINE_SPEED * (player.perfect_reflect_speed if perfect and from_enemy else 1.0)
	state = State.FLYING
	straight_timer = SHINE_STRAIGHT_TIME
	was_dropped = false
	spin_direction = 1.0 if velocity.x >= 0.0 else -1.0
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
	spin_direction = 1.0 if velocity.x >= 0.0 else -1.0
	Fx.text(get_parent(), global_position + Vector2(0, -30), "¡SHINE!", Shine.color(shine_level, false).lightened(0.3))

func _fly_hostile(delta: float) -> void:
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
	rotation += SPIN_SPEED * 1.4 * delta * spin_direction
	if global_position.distance_to(player.global_position + Vector2(0, -16)) <= 24.0 and not player.dead:
		player.take_damage(Shine.damage(HOSTILE_DAMAGE, shine_level), global_position)
		if player.has_method("on_knife_caught"):
			player.on_knife_caught(self)
		queue_free()
		return
	if hostile_timer <= 0.0:
		# Se le acabó el impulso: cae y queda como un cuchillo normal.
		state = State.BOUNCING
		was_dropped = true

func _target_center(node: Node2D) -> Vector2:
	var offset = node.get("impact_offset")
	return node.global_position + (offset if offset is Vector2 else Vector2.ZERO)

func _update_look() -> void:
	# Más grande con cada shine; rojo parpadeante en riposte; tono enemigo si viene hacia Rengar.
	sprite.scale = Vector2.ONE * VISUAL_SCALE * Shine.visual_scale(shine_level + 1 if shine_level > 0 else 0)
	var tint := Color.WHITE
	var trail_color := Color(1.0, 0.95, 0.75)
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
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
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
	var moving: bool = state in [State.FLYING, State.FALLING, State.BOUNCING, State.RETURNING, State.HOSTILE]
	if moving:
		trail.add_point(global_position)
		while trail.get_point_count() > TRAIL_LENGTH:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)

func _point_along(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		rotation = direction.angle() - TIP_ANGLE
