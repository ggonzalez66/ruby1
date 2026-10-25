extends SceneTree

const DIRECTORY := "res://docs/art/spirit_spear/runtime"
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label + ".png"))
	print("CAPTURE ", label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("La captura visual requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	change_scene_to_file("res://main.tscn")
	for index in range(10):
		await physics_frame
	player = get_first_node_in_group(&"player")
	player.position = Vector2(2300, -2)
	for index in range(4):
		await physics_frame
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	for collider in current_scene.find_children("*", "CollisionObject2D", true, false):
		collider.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for enemy in get_nodes_in_group(&"ruby_enemies"):
		enemy.hide()
	var camera := root.get_camera_2d()
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(2360, -110)
	camera.zoom = Vector2(2, 2)
	camera.offset = Vector2.ZERO
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for side in [1, -1]:
		player.facing = side
		for frame in range(4):
			player.knife_throw_pose_timer = player.JAVELIN_THROW_DURATION * (1.0 - [0.0, 0.25, 0.55, 0.85][frame])
			player._update_character_animation()
			await capture("throw_%s_%d" % ["right" if side > 0 else "left", frame])
	player.knife_throw_pose_timer = 0.0
	player.facing = 1
	player._update_character_animation()
	var spear: Node2D = load("res://knife.gd").new()
	current_scene.add_child(spear)
	spear.launch(player, Vector2(2420, -70), Vector2(950, -180))
	player.thrown_knife = spear
	player.has_knife = false
	spear._physics_process(0.02)
	await capture("flight")
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(2520, -2)
	boss.shine_chance = 0.0
	boss.max_health = 20
	current_scene.add_child(boss)
	spear.global_position = boss.global_position + boss.impact_offset
	spear._stick_in_enemy(boss)
	spear.mark_effect._process(0.07)
	await capture("embedded")
	for tick in range(12):
		spear._physics_process(0.5)
		if is_instance_valid(spear.mark_effect):
			spear.mark_effect._process(0.5)
	await capture("burn")
	spear.recall()
	spear._physics_process(0.02)
	await capture("soul_pull")
	root.get_node("RunSession")._clear_run()
	quit()
