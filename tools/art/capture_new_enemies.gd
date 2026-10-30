extends SceneTree
# Capturas de los enemigos nuevos (centinela, fusilero, aguijón, restaurador, sabueso y guardián mecha), del
# sabueso inmovilizando a Viridy, del galope de Wrath y del dash. Necesita renderer con ventana:
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/art/capture_new_enemies.gd
const DIRECTORY := "res://docs/art/enemies_v2/runtime"
var camera: Camera2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for _i in range(n):
		await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label + ".png"))
	print("CAPTURA ", label)

func look(at: Vector2, zoom: float) -> void:
	camera.global_position = at
	camera.zoom = Vector2.ONE * zoom

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura necesita un renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	change_scene_to_file("res://gauntlet.tscn")
	await frames(30)
	player = get_first_node_in_group(&"player")
	for director in get_nodes_in_group(&"gauntlet_director"):
		director.set_physics_process(false)
		director._clear_wave()
	player.position = Vector2(1500, -2)
	camera = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	var level: Node = player.get_parent()
	var lineup := []
	for entry in [["sentinel", 1820.0, -2.0], ["rifleman", 1910.0, -2.0], ["stinger", 1990.0, -70.0], ["restorer", 2070.0, -80.0], ["hound", 2160.0, -2.0]]:
		var enemy: Area2D = load("res://%s.gd" % entry[0]).new()
		enemy.position = Vector2(entry[1], entry[2])
		level.add_child(enemy)
		enemy.set_physics_process(false)
		lineup.append(enemy)
	await frames(4)
	look(Vector2(1990, -50), 2.6)
	await capture("nuevos_enemigos")
	for enemy in lineup:
		enemy.facing = -1
		enemy.visual.scale.x = -absf(enemy.visual.scale.x)
	await frames(1)
	await capture("nuevos_enemigos_izquierda")
	for enemy in lineup:
		enemy.queue_free()
	await frames(2)

	print("== Guardián mecha")
	var mecha: Area2D = load("res://boss_mecha.gd").new()
	mecha.position = Vector2(2000, -2)
	mecha.min_x = 1400.0
	mecha.max_x = 3000.0
	level.add_child(mecha)
	mecha.set_physics_process(false)
	await frames(3)
	look(Vector2(1930, -110), 1.8)
	await capture("mecha")
	mecha.set_physics_process(true)
	mecha.combat_started = true
	mecha._start_windup(mecha.State.PUNCH_WINDUP, 5.0, "")
	await frames(20)
	await capture("mecha_punetazo_aviso")
	mecha.state_timer = 0.0
	mecha.missile_cooldown = 0.0
	mecha._start_windup(mecha.State.MISSILE_WINDUP, 0.05, "¡MISILES!")
	await frames(30)
	look(Vector2(1800, -220), 1.2)
	await capture("mecha_misiles")
	mecha.queue_free()
	for node in get_nodes_in_group(&"projectiles"):
		node.queue_free()
	await frames(2)

	print("== Sabueso inmovilizando")
	var hound: Area2D = load("res://hound.gd").new()
	hound.position = player.global_position + Vector2(200, 0)
	level.add_child(hound)
	for i in range(240):
		await frames(1)
		if player.is_pinned():
			break
	await frames(6)
	look(player.global_position + Vector2(0, -40), 3.0)
	await capture("sabueso_inmoviliza")
	player.release_pin(false)
	hound.queue_free()
	await frames(30)

	print("== Wrath: galope y dash")
	var style: Node = root.get_node("Ferocity")
	player._respawn_player()
	player.position = Vector2(1500, -2)
	await frames(6)
	style._set_points(650.0)
	player.wrath.arm()
	player.wrath.launch(Vector2.RIGHT)
	for index in range(4):
		await frames(4)
		look(player.global_position + Vector2(-30, -45), 2.4)
		await capture("wrath_galope_%d" % index)
	player.wrath.cancel()
	style.reset()
	await frames(20)
	player._respawn_player()
	player.position = Vector2(1500, -2)
	await frames(6)
	player._start_dash()
	await frames(3)
	look(player.global_position + Vector2(0, -30), 3.0)
	await capture("dash")
	quit(0)
