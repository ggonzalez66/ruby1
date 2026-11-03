extends SceneTree

# Capturas de la run con mapa de hexágonos: hub, mapa, las tres fases de la fábrica, fuente, zorro y Torre.
# Requiere renderer con ventana:
#   godot --path . --rendering-driver opengl3 -s res://tools/art/capture_run_map.gd
const DIRECTORY := "res://docs/run_map/runtime"

var state: Node

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

func wait_scene(path: String) -> void:
	for _i in range(120):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			break
	await frames(40)

func view(at: Vector2, zoom: float) -> void:
	# Cámara fija para ver el escenario completo.
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	var camera: Camera2D = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.offset = Vector2.ZERO
	camera.global_position = at
	camera.zoom = Vector2.ONE * zoom
	camera.reset_smoothing()
	await frames(3)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	state = root.get_node("RunState")
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	change_scene_to_file("res://mother_tree.tscn")
	await wait_scene("res://mother_tree.tscn")
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.global_position = Vector2(6050, -100)
	await frames(30)
	await capture("hub_exit")
	state.start_run(2026)
	state.return_to_map()
	await wait_scene("res://run_map.tscn")
	await capture("map_start")
	# Un mapa a mitad de run: tres hexágonos recorridos.
	for step in range(3):
		var moves: Array = state.available_moves()
		state.current = moves[0]
		state.visited[moves[0]] = true
	state.fights_cleared = 2
	state.health = 64
	change_scene_to_file("res://run_map.tscn")
	await wait_scene("res://run_map.tscn")
	await capture("map_mid")
	for job in [
		["res://factory_outdoor.tscn", "outdoor", Vector2(2600, -420), 0.42],
		["res://factory_indoor.tscn", "indoor", Vector2(1800, -650), 0.36],
		["res://factory_boss.tscn", "boss_hall", Vector2(1900, -600), 0.4],
		["res://tower_finale.tscn", "tower", Vector2(1900, -600), 0.4],
		["res://fountain.tscn", "fountain", Vector2(2000, -250), 0.5],
		["res://fox_shop.tscn", "fox_shop", Vector2(2400, -260), 0.75],
	]:
		change_scene_to_file(job[0])
		await wait_scene(job[0])
		await capture(job[1] + "_play")
		await view(job[2], job[3])
		await capture(job[1])
	# La puerta abierta de afuera y la tienda abierta.
	change_scene_to_file("res://factory_outdoor.tscn")
	await wait_scene("res://factory_outdoor.tscn")
	current_scene.get_node("FactoryDoor").open()
	await frames(80)
	await view(Vector2(3550, -200), 0.9)
	await capture("door_open")
	change_scene_to_file("res://fox_shop.tscn")
	await wait_scene("res://fox_shop.tscn")
	state.active = true
	root.get_node("Upgrades").rubies = 40
	get_first_node_in_group(&"player").global_position = Vector2(current_scene.STALL_X, -4)
	await frames(20)
	await capture("shop_menu")
	paused = false
	state.abort_run()
	quit()
