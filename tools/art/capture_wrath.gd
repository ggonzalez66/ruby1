extends SceneTree

const DIRECTORY := "res://docs/wrath_nature/runtime"
var player: CharacterBody2D
var camera: Camera2D

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(name + ".png"))
	print("CAPTURE ", name)

func advance(delta: float) -> void:
	player.wrath.tick(delta)
	for tween in get_processed_tweens():
		tween.custom_step(delta)

func target(at: Vector2) -> Node2D:
	var actor: Node2D = load("res://training_dummy.tscn").instantiate()
	actor.max_health = 100
	actor.position = at
	actor.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	current_scene.add_child(actor)
	return actor

func mark(actor: Node2D) -> Node2D:
	var fire: Node2D = load("res://knife.gd").new()
	current_scene.add_child(fire)
	fire.launch(player, actor.position + actor.impact_offset, Vector2.RIGHT)
	player.thrown_knife = fire
	player.has_knife = false
	fire._stick_in_enemy(actor)
	fire._physics_process(0.01)
	return fire

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	change_scene_to_file("res://main.tscn")
	for i in range(10):
		await physics_frame
	player = get_first_node_in_group(&"player")
	player.position = Vector2(2300, -2)
	for i in range(5):
		await physics_frame
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	# Congelar la lógica sin sacar los cuerpos del espacio físico usado por move_and_collide.
	for collider in current_scene.find_children("*", "CollisionObject2D", true, false):
		collider.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await physics_frame
	current_scene.get_node("HUD").process_mode = Node.PROCESS_MODE_ALWAYS
	for actor in get_nodes_in_group(&"ruby_enemies"):
		actor.hide()
	camera = root.get_camera_2d()
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(2300, -110)
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	camera.zoom = Vector2(2, 2)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var style: Node = root.get_node("Ferocity")
	style._set_points(650)
	Input.action_press("move_down")
	advance(0.5)
	player._update_character_animation()
	await capture("charge")
	advance(0.51)
	Input.action_release("move_down")
	player._update_character_animation()
	await capture("ready")
	player.wrath.begin_aim()
	advance(0.10)
	await capture("aim")
	if "--aim-only" in OS.get_cmdline_user_args():
		root.get_node("RunSession")._clear_run()
		quit()
		return
	var first := target(Vector2(2480, -2))
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.boss_name = "GUARDIÁN PESADO"
	boss.position = Vector2(2660, -2)
	boss.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	current_scene.add_child(boss)
	var wall: StaticBody2D = load("res://platform.gd").new()
	wall.size = Vector2(30, 400)
	wall.position = Vector2(2800, -200)
	wall.collision_layer = 2
	wall.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	current_scene.add_child(wall)
	await physics_frame
	advance(0.16)
	for i in range(6):
		advance(0.02)
	camera.global_position.x = player.position.x + 80
	await capture("rush")
	for i in range(40):
		advance(0.02)
		if player.wrath.state == player.wrath.State.RECOIL:
			break
	camera.global_position.x = player.position.x - 10
	await capture("rubies")
	advance(0.13)
	advance(0.18)
	await capture("chew")
	advance(0.15)
	await capture("shatter")
	advance(0.1)
	await capture("recovery")
	advance(0.1)
	await capture("normal")
	player.position = Vector2(2300, -2)
	player.velocity = Vector2.ZERO
	player.animated_sprite.rotation = 0.0
	player._update_character_animation()
	camera.global_position.x = 2420
	for tween in get_processed_tweens():
		tween.custom_step(1.0)
	var marked := target(Vector2(2510, -2))
	var fire := mark(marked)
	await capture("mark")
	fire.recall()
	fire._physics_process(0.05)
	await capture("soul_pull")
	fire._release()
	await process_frame
	marked.current_health = 20
	fire = mark(marked)
	fire.recall()
	await process_frame
	await capture("soul_execution")
	root.get_node("RunSession")._clear_run()
	quit()
