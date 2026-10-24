extends SceneTree

# Revisión visual con el renderer real, las escalas del jugador, shader jade y VFX existentes.
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_refresh.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura necesita un renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	var level: Node2D = load("res://main.tscn").instantiate()
	root.add_child(level)
	for i in range(10):
		await physics_frame
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.position = Vector2(2300, -2)
	for i in range(4):
		await physics_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := root.get_camera_2d()
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(2300, -120)
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	camera.zoom = Vector2(2, 2)
	var directory := "res://docs/art/viridy_refresh/runtime"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		directory = arguments[0]
	DirAccess.make_dir_recursive_absolute(directory)
	var poses: Array = ["run", "walk", "dash", "heavy", "screw", "light1", "light2", "light3", "hurt"]
	if arguments.size() > 1:
		poses.assign(arguments[1].split(","))
	for name in poses:
		player._cancel_all_states()
		player.position = Vector2(2300, -2)
		player.attack_mode = player.ATTACK_NONE
		player.hurt_lock_timer = 0.0
		player.velocity = Vector2.ZERO
		player.is_sprinting = false
		match name:
			"run":
				player.is_sprinting = true
				player.velocity.x = 560
			"walk":
				player.velocity.x = 160
			"dash":
				player.attack_mode = player.ATTACK_GROUND_CHARGED
				player.attack_timer = 0.14
			"heavy":
				player.attack_mode = player.ATTACK_HEAVY_GROUND
				player.attack_timer = 0.10
			"heavy_close":
				player.attack_mode = player.ATTACK_HEAVY_GROUND
				player.attack_timer = 0.02
			"heavy_recovery":
				player.heavy_morph_recovery_timer = 0.08
			"screw":
				player.position.y = -70
				player.attack_mode = player.ATTACK_SPIN
				player.attack_timer = 0.08
			"light1", "light2", "light3":
				player.attack_mode = player.ATTACK_SLASH
				player.light_combo_step = int(name.right(1))
				player.attack_timer = 0.08
			"hurt":
				player.hurt_lock_timer = 0.12
		player._update_character_animation()
		if name == "run":
			player.animated_sprite.frame = 4
		player._set_attack_active(player._is_attack_active())
		player._update_attack_animation()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
		print("CAPTURE ", name)
	quit()
