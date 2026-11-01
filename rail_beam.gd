extends Node2D

# Disparo de la railgun (arma del Gauntlet): un láser instantáneo que atraviesa a todos los enemigos hasta
# la primera pared e ignora los escudos. Si conecta, Viridy recibe el hitstop y el retroceso.

const RANGE := 1800.0
const WORLD_MASK := 2
const ENEMY_MASK := 8
const COLOR := Color(0.75, 0.55, 1.0)
const FADE_TIME := 0.3

func fire(shooter: Node2D, start: Vector2, direction: Vector2, damage: int) -> void:
	var end := start + direction.normalized() * RANGE
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, end, WORLD_MASK))
	if not wall.is_empty():
		end = wall.position
	_draw_beam(start, end)
	if _hit_enemies(start, end, damage):
		shooter.on_rail_hit(direction.normalized())

func _hit_enemies(start: Vector2, end: Vector2, damage: int) -> bool:
	var query := PhysicsRayQueryParameters2D.create(start, end, ENEMY_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	var excluded: Array[RID] = []
	var connected := false
	while true:
		query.exclude = excluded
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return connected
		excluded.append(hit.rid)
		var enemy: Node2D = hit.collider
		if not enemy.visible or not enemy.has_method("take_hit"):
			continue
		connected = true
		enemy.take_hit(start, 1 if end.x >= start.x else -1, Upgrades.strike(enemy, Upgrades.RANGED_SLOT, damage))
		Ferocity.add("rail_hit", 16.0, "RAILGUN")
		Fx.impact(get_parent(), hit.position, Fx.GOLD, 1.2)
	return connected

func _draw_beam(start: Vector2, end: Vector2) -> void:
	z_index = 6
	var tween := create_tween().set_parallel()
	for layer in [[16.0, Color(COLOR, 0.55)], [6.0, Color.WHITE]]:
		var line := Line2D.new()
		line.top_level = true
		line.width = layer[0]
		line.default_color = layer[1]
		line.points = PackedVector2Array([start, end])
		add_child(line)
		tween.tween_property(line, "width", 0.0, FADE_TIME)
	tween.chain().tween_callback(queue_free)
