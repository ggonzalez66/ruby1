extends SceneTree
var checks := 0
var fails := 0
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)
func block(at: Vector2, size: Vector2) -> StaticBody2D:
	var node := StaticBody2D.new()
	node.position = at
	node.collision_layer = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	node.add_child(shape)
	arena.add_child(node)
	return node
func make_enemy(kind: String, aerial: bool) -> Area2D:
	var enemy: Area2D
	if kind == "training_dummy":
		enemy = load("res://training_dummy.tscn").instantiate()
		enemy.aerial = aerial
	else:
		enemy = Area2D.new()
		enemy.set_script(load("res://%s.gd" % kind))
	enemy.position = Vector2(0, -1)
	arena.add_child(enemy)
	return enemy
func run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	block(Vector2(0, 20), Vector2(1600, 40))
	for kind in ["chaser_dummy", "shield_bearer", "training_dummy"]:
		for flying in ([false, true] if kind == "training_dummy" else [false]):
			var enemy := make_enemy(kind, flying)
			var ceiling := block(Vector2(0, -100), Vector2(200, 20))
			await frames(3)
			enemy.launch_to(Vector2(0, -350), 0.02, 0.2)
			var stayed_below := true
			for i in range(18):
				await frames(1)
				var height: float = enemy.collision_shape.shape.size.y
				stayed_below = stayed_below and enemy.global_position.y - height >= -90.5
			check(stayed_below and enemy.position.y < -8, "%s aéreo=%s: sube y su cuerpo se detiene bajo la plataforma incluso a gran velocidad" % [kind, flying])
			await frames(50)
			check(enemy.current_health > 0 and (enemy.position.y < -8 if flying else absf(enemy.position.y) < 3), "%s aéreo=%s: conserva flotación o caída al suelo sin atravesar el techo" % [kind, flying])
			enemy.queue_free()
			ceiling.queue_free()
			await frames(3)
			enemy = make_enemy(kind, flying)
			var wall := block(Vector2(80, -150), Vector2(20, 300))
			await frames(3)
			enemy.launch_to(Vector2(300, -180), 0.02, 0.2)
			await frames(15)
			check(enemy.global_position.x + enemy.collision_shape.shape.size.x * 0.5 <= 70.5, "%s aéreo=%s: el lanzamiento diagonal también respeta paredes" % [kind, flying])
			enemy.queue_free()
			wall.queue_free()
			await frames(3)
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
