extends Node2D

# Cuchillo lanzado por Rengar: vuela en arco, se clava en enemigos o en el escenario
# (a veces cae suelto) y vuelve a la mano al hacer recall, golpeando por el camino.

const KNIFE_TEXTURE: Texture2D = preload("res://assets/sprites/player/rengar_knife.png")
const KNIFE_REGION := Rect2(48, 271, 243, 227)
# En el sprite la punta apunta hacia arriba a la izquierda (unos -138°).
const TIP_ANGLE := -2.415
const VISUAL_SCALE := 0.1

const GRAVITY := 1100.0
const WORLD_MASK := 2
const ENEMY_MASK := 8
const HIT_RADIUS := 11.0
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

func _ready() -> void:
	z_index = 2
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
		global_position = hit.position
		if state == State.BOUNCING:
			_lie_down(hit.normal)
		elif randf() < DROP_CHANCE:
			_bounce_off(hit.normal)
		else:
			_stick_in_world()
		return

	global_position = to
	if state == State.BOUNCING:
		rotation += 14.0 * delta * sign(velocity.x if velocity.x != 0.0 else 1.0)
		return
	_point_along(velocity)
	if state == State.FLYING:
		var enemy := _find_enemy(recall_hits)
		if enemy:
			_stick_in_enemy(enemy)

func _stick_in_world() -> void:
	state = State.STUCK_WORLD
	was_dropped = false
	global_position += velocity.normalized() * 4.0

func _bounce_off(normal: Vector2) -> void:
	# Pequeña probabilidad de no clavarse: rebota y queda tirado.
	state = State.BOUNCING
	was_dropped = true
	velocity = velocity.bounce(normal) * 0.35 + normal * 120.0

func _lie_down(normal: Vector2) -> void:
	state = State.DROPPED
	global_position += normal * 3.0
	rotation = -TIP_ANGLE if velocity.x >= 0.0 else PI - TIP_ANGLE

func _stick_in_enemy(enemy: Node2D) -> void:
	var direction: int = 1 if velocity.x >= 0.0 else -1
	enemy.take_hit(global_position, direction, DAMAGE_THROW)
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
	_point_along(move)
	var enemy := _find_enemy(recall_hits)
	if enemy:
		_recall_hit(enemy)

func _recall_hit(enemy: Node2D) -> void:
	recall_hits.append(enemy)
	var direction: int = 1 if player.global_position.x >= enemy.global_position.x else -1
	enemy.take_hit(global_position, direction, DAMAGE_RECALL)
	if player and player.has_method("on_knife_hit"):
		player.on_knife_hit(global_position)
	# Si el cuchillo estaba tirado en el suelo solo golpea; si no, atrae hacia Rengar.
	if not was_dropped and enemy.has_method("pull_towards"):
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

func _point_along(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		rotation = direction.angle() - TIP_ANGLE
