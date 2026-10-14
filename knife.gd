extends Node2D

# Cuchillo lanzado por Rengar: vuela en arco, se clava en enemigos o en el escenario
# (a veces cae suelto) y vuelve a la mano al hacer recall, golpeando por el camino.

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

enum State { FLYING, FALLING, STUCK_ENEMY, STUCK_WORLD, BOUNCING, DROPPED, RETURNING }

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

func _ready() -> void:
	z_index = 2
	# Estela plateada que sigue al cuchillo mientras vuela o vuelve.
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 9.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 0.95, 0.75, 0.75))
	trail.gradient = gradient
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
	if state == State.RETURNING:
		return
	# Al arrancarlo de un enemigo lo golpea otra vez.
	if state == State.STUCK_ENEMY and _is_target_alive(target):
		_recall_hit(target)
	state = State.RETURNING
	return_speed = RETURN_START_SPEED

func _physics_process(delta: float) -> void:
	_update_trail()
	match state:
		State.FLYING, State.FALLING, State.BOUNCING:
			_fly(delta)
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
	var direction: int = 1 if velocity.x >= 0.0 else -1
	enemy.take_hit(global_position, direction, int(round(DAMAGE_THROW * Ferocity.damage_multiplier())))
	Ferocity.add("knife", 12.0, "CUCHILLO")
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	state = State.STUCK_ENEMY
	was_dropped = false
	target = enemy
	target_offset = enemy.to_local(global_position)

func _return(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	var goal: Vector2 = player.global_position + Vector2(0.0, -16.0)
	var offset := goal - global_position
	return_speed = min(return_speed + RETURN_ACCELERATION * delta, RETURN_MAX_SPEED)
	var step: float = return_speed * delta
	if offset.length() <= step + 14.0:
		if player.has_method("on_knife_caught"):
			player.on_knife_caught()
		queue_free()
		return
	var move := offset.normalized() * step
	global_position += move
	rotation += SPIN_SPEED * delta * (1.0 if move.x >= 0.0 else -1.0)
	var enemy := _find_enemy(recall_hits)
	if enemy:
		_recall_hit(enemy)

func _recall_hit(enemy: Node2D) -> void:
	recall_hits.append(enemy)
	var direction: int = 1 if player.global_position.x >= enemy.global_position.x else -1
	enemy.take_hit(global_position, direction, int(round(DAMAGE_RECALL * Ferocity.damage_multiplier())))
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	# Si el cuchillo estaba tirado en el suelo solo golpea; si no, atrae hacia Rengar.
	if not was_dropped and enemy.has_method("pull_towards"):
		Ferocity.add("knife_pull", 15.0, "ATRAÍDO")
		enemy.pull_towards(player.global_position, PULL_STRENGTH)

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
	var moving: bool = state in [State.FLYING, State.FALLING, State.BOUNCING, State.RETURNING]
	if moving:
		trail.add_point(global_position)
		while trail.get_point_count() > TRAIL_LENGTH:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)

func _point_along(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		rotation = direction.angle() - TIP_ANGLE
