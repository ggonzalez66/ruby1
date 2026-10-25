extends SceneTree

const DIRECTORY := "res://docs/art/spear_rework/runtime"
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label + ".png"))
	print("CAPTURE ", label)

func spear_at(point: Vector2, speed: Vector2) -> Node2D:
	var spear: Node2D = load("res://knife.gd").new()
	arena.add_child(spear)
	spear.launch(player, point, speed)
	spear.set_physics_process(false)
	player.thrown_knife = spear
	player.has_knife = false
	return spear

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("La captura visual requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	RenderingServer.set_default_clear_color(Color("14261e"))
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.size = Vector2(2000, 100)
	floor_body.position = Vector2(400, 50)
	floor_body.collision_layer = 2
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(50, -2)
	arena.add_child(player)
	await frames(3)
	player.set_physics_process(false)
	player._update_character_animation()
	var camera := Camera2D.new()
	camera.position = Vector2(330, -120)
	camera.zoom = Vector2(1.6, 1.6)
	arena.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var spear := spear_at(Vector2(340, -90), Vector2(950, -180))
	await capture("flight_right")
	spear.velocity = Vector2(-950, -180)
	spear._point_along(spear.velocity)
	await capture("flight_left")
	spear._release()
	await frames(2)
	var enemies: Array[Node2D] = []
	for x in [250, 390, 530]:
		var enemy: Area2D = load("res://chaser_dummy.gd").new()
		enemy.position = Vector2(x, -2)
		enemy.max_health = 100
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	spear = spear_at(enemies[2].position + enemies[2].impact_offset, Vector2(950, -120))
	spear._stick_in_enemy(enemies[2])
	# Mantener el renderer y las partículas activos para ver motas reales.
	await frames(50)
	await capture("embedded_motes")
	spear._physics_process(2.1)
	await frames(2)
	await capture("embedded_expired")
	spear.recall()
	spear._physics_process(0.08)
	await capture("return_multi")
	spear._release()
	await frames(2)
	spear = spear_at(Vector2(520, -1), Vector2(450, 850))
	spear._stick_in_world()
	await capture("embedded_ground")
	spear._release()
	await frames(2)
	quit()
