extends SceneTree
# Capturas de los enemigos con sus sprites (normal, aviso y golpe). Carpeta: CAPTURE_DIR o docs/roguelite_combat/runtime.
var directory := OS.get_environment("CAPTURE_DIR") if OS.get_environment("CAPTURE_DIR") != "" else "res://docs/roguelite_combat/runtime"

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for _i in range(n):
		await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("CAPTURE ", label)

func _run() -> void:
	root.size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute(directory)
	change_scene_to_file("res://gauntlet.tscn")
	await frames(30)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.position = Vector2(1700, -2)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE * 2.0
	camera.global_position = Vector2(1960, -60)
	var enemies := []
	for entry in [["chaser_dummy", 1880.0, -2.0], ["shield_bearer", 1990.0, -2.0], ["hawk", 2100.0, -110.0]]:
		var enemy: Area2D = load("res://%s.gd" % entry[0]).new()
		enemy.position = Vector2(entry[1], entry[2])
		player.get_parent().add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await frames(4)
	await capture("enemies_idle")
	for enemy in enemies:
		enemy.facing = -1
		enemy.visual.scale.x = -absf(enemy.visual.scale.x)
		enemy.flash_timer = 0.1
		enemy.body_poly.color = Color(1, 1, 1)
	await frames(1)
	await capture("enemies_hit")
	quit()
