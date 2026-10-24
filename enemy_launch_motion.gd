extends RefCounted

# Los autómatas usan Area2D como hurtbox: el lanzamiento debe barrer su volumen,
# no solo el punto de los pies, antes de cambiar la posición por interpolación.
static func move_to(enemy: Area2D, collision: CollisionShape2D, destination: Vector2) -> bool:
	var motion := destination - enemy.global_position
	if motion.is_zero_approx():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.motion = motion
	query.margin = 0.02
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var fractions := enemy.get_world_2d().direct_space_state.cast_motion(query)
	var safe: float = fractions[0] if fractions.size() > 0 else 1.0
	enemy.global_position += motion * safe
	return safe < 0.9999
