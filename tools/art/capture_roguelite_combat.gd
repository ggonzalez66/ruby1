extends SceneTree
const DIRECTORY := "res://docs/roguelite_combat/runtime"
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for _i in range(n):
		await physics_frame
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label + ".png"))
	print("CAPTURE ", label)
func _run() -> void:
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	change_scene_to_file("res://gauntlet.tscn")
	await frames(30)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	var camera: Camera2D = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(800, -200)
	camera.zoom = Vector2.ONE * 0.85
	player.position = Vector2(540, -2)
	await frames(5)
	await capture("gauntlet_armory")
	for id in [&"sword", &"axe", &"hammer", &"glaive"]:
		player.weapons.equip(id)
		player.position = Vector2(1800, -2)
		camera.global_position = Vector2(1800, -100)
		camera.zoom = Vector2.ONE * 1.4
		await frames(3)
		player.weapons.request(true)
		await frames(7)
		await capture(str(id))
		player._cancel_all_states()
	player.weapons.equip(&"glaive")
	player.position = Vector2(1800, -2)
	Input.action_press("throw_knife")
	await frames(3)
	await capture("aim")
	Input.action_release("throw_knife")
	Input.action_press("transform")
	await frames(2)
	Input.action_release("transform")
	Input.action_press("attack")
	await frames(12)
	await capture("liquid_beast")
	Input.action_release("attack")
	change_scene_to_file("res://sanctuary.tscn")
	await frames(20)
	player = get_first_node_in_group(&"player")
	camera = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(1270, -200)
	camera.zoom = Vector2.ONE * 0.85
	player.position = Vector2(1260, -2)
	await frames(8)
	await capture("sanctuary_armory")
	quit()
