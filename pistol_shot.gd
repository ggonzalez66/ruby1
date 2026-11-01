extends Node2D

# Disparo de la pistola (mejora del Gauntlet): bala rápida y recta que barre su trayecto cada frame.
# Hereda de la lanza la punta perforante; el elemento del arma solo va en los disparos cargados.

const SPEED := 2100.0
const LIFE := 0.7
const WORLD_MASK := 2
const ENEMY_MASK := 8
const COLOR := Color(1.0, 0.9, 0.55)

var velocity := Vector2.ZERO
var damage := 3
var pierce_left := 0
var charged := false
var hits: Array = []
var life := LIFE
var trail: Line2D

func fire(start: Vector2, direction: Vector2, shot_damage: int, pierce: int, carries_element: bool) -> void:
	global_position = start
	velocity = direction.normalized() * SPEED
	damage = shot_damage
	pierce_left = pierce
	charged = carries_element
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 3.0
	trail.default_color = Color(COLOR, 0.8)
	trail.points = PackedVector2Array([start, start])
	add_child(trail)
	z_index = 4

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_2d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK))
	if not wall.is_empty():
		to = wall.position
	var finished := _hit_enemies(from, to)
	global_position = to
	trail.points = PackedVector2Array([from - velocity * delta * 0.5, to])
	if finished or not wall.is_empty():
		Fx.impact(get_parent(), to, Fx.SILVER, 0.5)
		queue_free()

func _hit_enemies(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, ENEMY_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var excluded: Array[RID] = []
	while true:
		query.exclude = excluded
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		excluded.append(hit.rid)
		var enemy: Node2D = hit.collider
		if enemy in hits or not enemy.visible or not enemy.has_method("take_hit"):
			continue
		hits.append(enemy)
		var direction := 1 if velocity.x >= 0.0 else -1
		if enemy.has_method("try_block") and enemy.try_block(from):
			Sfx.play("block")
			return true
		enemy.take_hit(from, direction, Upgrades.strike(enemy, Upgrades.RANGED_SLOT if charged else "", damage))
		Ferocity.add("pistol_hit", 3.0, "DISPARO")
		Fx.impact(get_parent(), hit.position, Fx.SILVER, 0.7)
		Sfx.play("hit_light")
		if pierce_left <= 0:
			return true
		pierce_left -= 1
	return false
