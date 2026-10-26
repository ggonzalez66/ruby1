extends SceneTree

const DIRECTORY := "res://docs/sanctuary/runtime"

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

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	change_scene_to_file("res://main_menu.tscn")
	await frames(10)
	await capture("main_menu")
	change_scene_to_file("res://level_testing.tscn")
	await frames(10)
	await capture("level_testing")
	change_scene_to_file("res://sanctuary.tscn")
	await frames(35)
	await capture("spawn")
	var player: CharacterBody2D = current_scene.player
	player.set_physics_process(false)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.offset = Vector2.ZERO
	for view in [
		["mother_tree", Vector2(3050, -650), 0.45],
		["lagoon", Vector2(3700, -80), 0.8],
		["west_trails", Vector2(1500, -350), 0.65],
		["canopy", Vector2(3050, -1050), 0.75],
	]:
		camera.global_position = view[1]
		camera.zoom = Vector2.ONE * float(view[2])
		camera.reset_smoothing()
		await frames(3)
		await capture(view[0])
	current_scene.pause_menu._open()
	await frames(2)
	await capture("pause")
	paused = false
	quit()
