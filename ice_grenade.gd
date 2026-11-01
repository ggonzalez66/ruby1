extends Node2D

# Granada de hielo (arma del Gauntlet): vuela en arco, explota al tocar terreno o a un enemigo, hiela lo que
# alcanza y suelta mini racimos que hacen lo mismo con menos fuerza. Lleva también el elemento del arma.

const SPEED := 780.0
const LIFT := 140.0
const GRAVITY := 1100.0
const FUSE := 1.6
const RADIUS := 130.0
const DAMAGE := 6
const CLUSTERS := 5
const CLUSTER_RADIUS := 70.0
const CLUSTER_DAMAGE := 2
const CLUSTER_FUSE := 0.7
const CONTACT := 14.0
const WORLD_MASK := 2
const ENEMY_MASK := 8
const ICE := Color(0.55, 0.85, 1.0)

var velocity := Vector2.ZERO
var fuse := FUSE
var radius := RADIUS
var damage := DAMAGE
var size := 9.0
var cluster := false

func launch(start: Vector2, direction: Vector2, power: int) -> void:
	global_position = start
	velocity = direction.normalized() * SPEED + Vector2(0, -LIFT)
	damage = DAMAGE * power
	z_index = 4

func launch_cluster(start: Vector2, launch_velocity: Vector2, power: int) -> void:
	global_position = start
	velocity = launch_velocity
	cluster = true
	radius = CLUSTER_RADIUS
	damage = CLUSTER_DAMAGE * power
	size = 5.0
	fuse = CLUSTER_FUSE * randf_range(0.7, 1.0)
	z_index = 4

func _physics_process(delta: float) -> void:
	fuse -= delta
	velocity.y += GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK))
	if not wall.is_empty():
		global_position = wall.position + wall.normal * 2.0
		_explode()
		return
	global_position = to
	if fuse <= 0.0 or not _enemies_within(CONTACT).is_empty():
		_explode()

func _enemies_within(reach: float) -> Array:
	var circle := CircleShape2D.new()
	circle.radius = reach
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var enemy: Node2D = hit.collider
		if enemy.visible and enemy.has_method("take_hit") and not enemy in found:
			found.append(enemy)
	return found

func _explode() -> void:
	for enemy in _enemies_within(radius):
		var center: Vector2 = enemy.global_position + enemy.impact_offset
		# Las paredes cubren de la explosión.
		if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, center, WORLD_MASK)).is_empty():
			continue
		var dealt: int = Upgrades.imbue(enemy, "ice", Upgrades.strike(enemy, Upgrades.RANGED_SLOT, damage))
		enemy.take_hit(global_position, 1 if center.x >= global_position.x else -1, dealt)
		Ferocity.add("grenade_hit", 3.0 if cluster else 8.0, "" if cluster else "GRANADA")
	Fx.shatter(get_parent(), global_position, ICE, radius * 0.7)
	Sfx.play("grenade_blast", -6.0 if cluster else 0.0, 1.4 if cluster else 1.0)
	if not cluster:
		_release_clusters()
	queue_free()

func _release_clusters() -> void:
	# En abanico hacia arriba.
	for index in range(CLUSTERS):
		var angle: float = -PI * 0.5 + lerpf(-1.1, 1.1, float(index) / (CLUSTERS - 1))
		var piece: Node2D = get_script().new()
		get_parent().add_child(piece)
		piece.launch_cluster(global_position, Vector2.from_angle(angle) * randf_range(260.0, 430.0), damage / DAMAGE)

func _draw() -> void:
	draw_circle(Vector2.ZERO, size + 3.0, Color(ICE, 0.3))
	draw_circle(Vector2.ZERO, size, ICE)
	draw_circle(Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color.WHITE)
