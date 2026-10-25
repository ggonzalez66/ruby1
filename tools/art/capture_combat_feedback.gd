extends SceneTree

const DIRECTORY := "res://docs/combat_feedback/runtime"

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIRECTORY.path_join(name + ".png"))
	print("CAPTURE ", name)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	change_scene_to_file("res://main.tscn")
	for i in range(10):
		await physics_frame
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.position = Vector2(2300, -2)
	for i in range(4):
		await physics_frame
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := root.get_camera_2d()
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(2300, -120)
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	camera.zoom = Vector2(2, 2)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var shine_only := "--shine-only" in OS.get_cmdline_user_args()
	for facing in ([] if shine_only else [1, -1]):
		for hit in [1, 2, 3]:
			player._cancel_all_states()
			player.facing = facing
			player._update_facing_visual()
			player.attack_mode = player.ATTACK_SLASH
			player.light_combo_step = hit
			player.attack_timer = 0.08
			player._update_character_animation()
			player._set_attack_active(true)
			player._update_attack_animation()
			await capture("combo_%d_%s" % [hit, "right" if facing > 0 else "left"])
	player._cancel_all_states()
	player.facing = 1
	player._update_facing_visual()
	if shine_only:
		player._update_character_animation()
		await capture("idle_scale")
		Input.action_press("move_down")
		player._update_character_animation()
		await capture("crouch_scale")
		Input.action_release("move_down")
	player._start_roar()
	var previous_time := 0.0
	for elapsed in [0.0, 0.16, 0.30]:
		for tween in get_processed_tweens():
			tween.custom_step(elapsed - previous_time)
		previous_time = elapsed
		player.roar_elapsed = elapsed
		player.roar_explosive_timer = maxf(player.roar_explosive_duration - elapsed, 0.0)
		player._update_character_animation()
		player._update_roar_aura()
		await capture("shine_%d" % roundi(elapsed * 100.0))
	player._end_roar()
	player._update_roar_aura()
	if shine_only:
		root.get_node("RunSession")._clear_run()
		quit()
		return
	for tween in get_processed_tweens():
		tween.custom_step(1.0)
	player._cancel_all_states()
	player.hide()
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.boss_name = "GUARDIÁN PESADO"
	boss.position = Vector2(2300, -2)
	current_scene.add_child(boss)
	camera.zoom = Vector2(2.6, 2.6)
	for health in [100, 50, 20, 0]:
		boss.current_health = health
		boss.ruby_core.posture = health
		boss.ruby_core.queue_redraw()
		await capture("ruby_%d" % health)
	boss.current_health = 70
	boss.ruby_core.posture = 100.0 / 3.0
	boss.ruby_core.queue_redraw()
	for plane in [boss.SpinPlane.VERTICAL, boss.SpinPlane.HORIZONTAL]:
		boss.spin_plane = plane
		boss.sword_pivot.position = boss._spin_pivot_position()
		for pose in range(4):
			boss.spin_angle = 0.35 + pose * PI * 0.5
			boss._pose_spin_sword()
			await capture("spin_%d_%d" % [plane, pose])
	boss.hide()
	player.show()
	camera.zoom = Vector2(2, 2)
	player.still_time = player.proud_delay
	player.proud_active = true
	player._start_proud_roar()
	player._update_character_animation()
	await capture("taunt")
	var menu: CanvasLayer = current_scene.get_node("PauseMenu")
	menu._open()
	await capture("pause")
	menu._resume()
	var session: CanvasLayer = root.get_node("RunSession")
	session.begin_run(player, true)
	session.set_process(false)
	await capture("ready_0")
	session._process(0.5)
	await capture("ready_50")
	session._process(0.5)
	await capture("go")
	session._clear_run()
	quit()
