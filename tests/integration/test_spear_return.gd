extends SceneTree

class RecallTarget extends Area2D:
	var pulls := 0
	var hits := 0
	var pull_direction := 0.0
	var impact_offset := Vector2.ZERO

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(12, 24)
		add_child(shape)

	func take_hit() -> void:
		hits += 1

	func pull_towards(point: Vector2, _strength: float) -> void:
		pulls += 1
		pull_direction = signf(point.x - global_position.x)

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func enemy_at(point: Vector2) -> RecallTarget:
	var enemy := RecallTarget.new()
	enemy.position = point
	arena.add_child(enemy)
	return enemy

func spear_at(point: Vector2) -> Node2D:
	var spear: Node2D = load("res://knife.gd").new()
	arena.add_child(spear)
	spear.launch(player, point, Vector2.RIGHT * 900)
	spear.set_physics_process(false)
	player.thrown_knife = spear
	player.has_knife = false
	return spear

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	player = load("res://playerr.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	await frames(2)
	print("== Regreso barrido, multiblanco y ambos lados")
	for side in [1.0, -1.0]:
		var enemies: Array[RecallTarget] = []
		for index in range(40):
			enemies.append(enemy_at(Vector2(side * (230 + index * 15), -16)))
		var outside := enemy_at(Vector2(side * 500, -100))
		var spear := spear_at(Vector2(side * 1000, -16))
		await frames(2)
		spear.recall()
		spear.recall()
		check(spear.is_returning() and spear.sprite.visible and not player.has_knife, "lado %d: recall en vuelo inicia un único regreso visible" % side)
		spear._physics_process(0.43)
		check(enemies.all(func(e): return e.pulls == 1 and e.pull_direction == -side and e.hits == 0), "lado %d: atraviesa y atrae 40 enemigos en un frame sin daño instantáneo" % side)
		check(outside.pulls == 0, "lado %d: no atrae enemigos fuera del trayecto" % side)
		spear._physics_process(0.001)
		check(enemies.all(func(e): return e.pulls == 1), "lado %d: el solapamiento de frames no repite la atracción" % side)
		spear._physics_process(0.2)
		check(player.has_knife and player.thrown_knife == null, "lado %d: recupera la lanza al llegar al jugador" % side)
		for enemy in enemies:
			enemy.queue_free()
		outside.queue_free()
		await frames(2)
	print("== Regreso contra terreno")
	var near := enemy_at(Vector2(750, -16))
	var behind_wall := enemy_at(Vector2(250, -16))
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.position = Vector2(500, -16)
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = RectangleShape2D.new()
	wall_shape.shape.size = Vector2(20, 300)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	var spear := spear_at(Vector2(1000, -16))
	await frames(2)
	spear.recall()
	spear._physics_process(1.0)
	check(near.pulls == 1 and behind_wall.pulls == 0, "atrae antes de la pared sin alcanzar enemigos al otro lado")
	check(player.has_knife, "una pared bloqueando el regreso no deja el arma inutilizable")
	await frames(2)
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
