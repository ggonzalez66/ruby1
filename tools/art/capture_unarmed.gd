extends SceneTree

# Revisión visual del combate sin armas: patadas por fase, embestida y picada con la cabeza de león y su
# estela, y Wrath of Nature. Necesita renderer con ventana:
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_unarmed.gd
const DIRECTORY := "res://docs/art/unarmed_rework/runtime"
var player: CharacterBody2D
var camera: Camera2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label + ".png"))
	print("CAPTURA ", label)

func look(at: Vector2, zoom := 2.0) -> void:
	camera.global_position = at
	camera.zoom = Vector2.ONE * zoom

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura necesita un renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var level := Node2D.new()
	root.add_child(level)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.1, 0.14, 0.13)
	backdrop.position = Vector2(-4000, -3000)
	backdrop.size = Vector2(12000, 6000)
	backdrop.z_index = -50
	level.add_child(backdrop)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.size = Vector2(8000, 100)
	floor_body.position = Vector2(0, 50)
	floor_body.collision_layer = 2
	level.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	level.add_child(player)
	await frames(10)
	camera = Camera2D.new()
	level.add_child(camera)
	camera.make_current()
	var combo: Node2D = player.combo
	print("== Patadas por fase")
	player.set_physics_process(false)
	for step in [3, 4]:
		look(player.global_position + Vector2(20, -40), 3.0)
		for index in range(6):
			player._cancel_all_states()
			player.attack_cooldown_timer = 0.0
			combo.step = step - 1
			combo.window = 0.5
			combo.request()
			var at: float = [0.0001, combo.startup * 0.5, combo.startup * 0.95, combo.startup + combo.active_time * 0.5,
				combo.startup + combo.active_time + combo.recovery * 0.2, combo.duration - 0.001][index]
			combo.tick(at)
			player._update_character_animation()
			player._update_attack_animation()
			await capture("patada%d_frame%d" % [step - 2, index + 1])
	player._cancel_all_states()
	player.set_physics_process(true)
	print("== Embestida y picada")
	player.position = Vector2(0, -2)
	player.facing = 1
	await frames(3)
	player._start_ground_heavy_attack()
	await frames(5)
	look(player.global_position + Vector2(-20, -40), 2.5)
	await capture("embestida")
	await frames(40)
	player.position = Vector2(400, -320)
	player.velocity = Vector2.ZERO
	await frames(2)
	player.attack_cooldown_timer = 0.0
	player._start_heavy_attack(false)
	await frames(8)
	look(player.global_position + Vector2(-20, -30), 2.5)
	await capture("picada")
	await frames(60)
	print("== Wrath of Nature")
	var style: Node = root.get_node("Ferocity")
	player._respawn_player()
	player.position = Vector2(800, -2)
	await frames(4)
	style._set_points(650.0)
	player.wrath.arm()
	player.wrath.launch(Vector2.RIGHT)
	await frames(10)
	look(player.global_position + Vector2(-60, -40), 2.0)
	await capture("wrath")
	player.wrath.cancel()
	style.reset()
	quit(0)
