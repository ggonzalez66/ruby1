extends SceneTree

# Capturas de la remasterización con PixelFX, la Araña Colosal de la Torre, las cámaras destructibles y el
# mundo espiritual dentro del sol. Requiere renderer con ventana:
#   godot --path . --rendering-driver opengl3 -s res://tools/art/capture_pixelfx_spider.gd
const DIRECTORY := "res://docs/pixelfx_spider/runtime"
const FX := preload("res://fx.gd")

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
	change_scene_to_file(path)
	for _i in range(120):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			break
	await frames(40)

func view(at: Vector2, zoom: float) -> void:
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

func effects_gallery() -> void:
	await wait_scene("res://factory_boss.tscn")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	director.set_physics_process(false)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.global_position = Vector2(300, -2)
	await view(Vector2(1600, -260), 1.0)
	var level := current_scene
	var row1 := [
		func(p): FX.impact(level, p, FX.SILVER, 1.0),
		func(p): FX.impact(level, p, FX.GOLD, 2.0),
		func(p): FX.deflect(level, p),
		func(p): FX.ruby_critical(level, p, Color(1.0, 0.08, 0.15)),
		func(p): FX.shatter(level, p, Color(0.5, 0.85, 1.0), 90.0),
		func(p): FX.puff(level, p, Color(1.0, 0.6, 0.3)),
	]
	var row2 := [
		func(p): FX.dust(level, p + Vector2(0, 60), Vector2.RIGHT, 8, 1.6),
		func(p): FX.explosion(level, p + Vector2(0, 40), 0.7),
		func(p): FX.zap(level, p, Color(0.5, 0.8, 1.0), 1.0),
		func(p): FX.warp_in(level, p + Vector2(0, 60), Color(1.0, 0.3, 0.25)),
		func(p): FX.charge(level, p, Color(1.0, 0.25, 0.2), 0.8),
		func(p): FX.collect(level, p, Color(1.0, 0.2, 0.25)),
	]
	for index in range(row1.size()):
		row1[index].call(Vector2(1100 + index * 200, -380))
		row2[index].call(Vector2(1100 + index * 200, -150))
	FX.heal(player)
	await frames(7)
	await capture("fx_gallery_early")
	await frames(12)
	await capture("fx_gallery_mid")

func spider() -> void:
	await wait_scene("res://tower_finale.tscn")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	director.phase = director.Phase.BOSS
	director._spawn_spider()
	await frames(10)
	var boss: Node2D = get_first_node_in_group(&"spider_boss")
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.global_position = boss.global_position + Vector2(-620, -2)
	await frames(150)
	await view(boss.global_position + Vector2(-200, -260), 0.8)
	await capture("spider_idle")
	boss.combat_started = true
	boss.state_timer = 0.0
	boss._start_stab_windup(player)
	await frames(40)
	await view(boss.global_position + Vector2(-200, -260), 0.8)
	await capture("spider_stab")
	boss._recover(0.1)
	await frames(10)
	boss._start_rail()
	await frames(70)
	await view(boss.global_position + Vector2(-200, -260), 0.8)
	await capture("spider_rail")
	for leg in boss.legs:
		leg.take_hit(Vector2.ZERO, 1, 999)
		leg.ruby_core._expire_dying()
	await frames(150)
	await view(boss.global_position + Vector2(-200, -200), 0.8)
	await capture("spider_collapsed")

func cameras() -> void:
	await wait_scene("res://factory_outdoor.tscn")
	var camera: Node2D = current_scene.get_node("CameraDoor")
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.global_position = camera.global_position + Vector2(-260, 330)
	await frames(20)
	await view(camera.global_position + Vector2(-80, 120), 1.0)
	await capture("camera_intact")
	camera.take_hit(player.global_position, 1, 1)
	await frames(12)
	await capture("camera_destroyed")

func sun_world() -> void:
	if not ResourceLoader.exists("res://sun_world.tscn"):
		return
	await wait_scene("res://sun_world.tscn")
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.set_physics_process(false)
	await frames(20)
	await capture("sun_start")
	# [nombre, posición de Viridy, zoom]
	var shots := [
		["sun_floor1", Vector2(1300, -150), 0.62],
		["sun_floor2", Vector2(1500, -790), 1.0],
		["sun_floor4", Vector2(1400, -2050), 0.62],
		["sun_floor5", Vector2(1700, -2700), 0.62],
		["sun_ruby", Vector2(1600, -3880), 0.62],
	]
	for index in range(shots.size()):
		player.global_position = shots[index][1]
		await frames(30)
		await view(shots[index][1] + Vector2(0, -150), shots[index][2])
		await capture(shots[index][0])

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var only: String = OS.get_environment("CAPTURE_ONLY")
	if only in ["", "fx"]:
		await effects_gallery()
	if only in ["", "spider"]:
		await spider()
	if only in ["", "cameras"]:
		await cameras()
	if only in ["", "sun"]:
		await sun_world()
	quit()
