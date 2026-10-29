extends SceneTree
# Capturas de la presentación de armas: swings alternos, giros horizontales, ráfaga, frenado al cargar,
# uppercut de la bestia y dive de Viridy. Carpeta de salida: variable CAPTURE_DIR o docs/roguelite_combat/runtime.
var directory := OS.get_environment("CAPTURE_DIR") if OS.get_environment("CAPTURE_DIR") != "" else "res://docs/roguelite_combat/runtime"
var player: CharacterBody2D
var camera: Camera2D

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

func focus(at: Vector2) -> void:
	camera.global_position = at + Vector2(0, -40)

func pose(id: StringName, heavy: bool, step: int, progress: float) -> void:
	var w = player.weapons
	player._cancel_all_states()
	player.attack_cooldown_timer = 0
	w.equip(id)
	w.step = step - 1
	w.last_heavy = heavy
	w.window = 0.5
	w.request(heavy)
	w.elapsed = w.startup + w.active_time * progress
	player._update_character_animation()
	w._process(0.0)
	w.queue_redraw()

func _run() -> void:
	root.size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute(directory)
	change_scene_to_file("res://gauntlet.tscn")
	await frames(30)
	player = get_first_node_in_group(&"player")
	camera = player.get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE * 2.2
	for enemy in get_nodes_in_group(&"ruby_enemies"):
		enemy.queue_free()
	player.position = Vector2(1800, -2)
	player.facing = 1
	player._update_facing_visual()
	await frames(4)
	player.set_physics_process(false)
	focus(player.global_position)
	for step in range(4):
		pose(&"sword", false, step, 0.55)
		await capture("sword_light_%d" % (step + 1))
	for entry in [[&"axe", false, 2], [&"glaive", false, 3]]:
		for quarter in range(4):
			pose(entry[0], entry[1], entry[2], (quarter + 0.5) / (4.0 * float(player.weapons.move.pulses)))
			await capture("%s_spin_%d" % [entry[0], quarter])
	for pulse in range(3):
		pose(&"sword", true, 1, (pulse + 0.5) / 3.0)
		await capture("sword_flurry_%d" % pulse)
	player._cancel_all_states()
	player.set_physics_process(true)
	player.weapons.equip(&"hammer")
	player.position = Vector2(1500, -2)
	await frames(3)
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(40)
	Input.action_press("heavy_attack")
	await frames(7)
	focus(player.global_position)
	await capture("hammer_charge_brake")
	Input.action_release("heavy_attack")
	Input.action_release("move_right")
	Input.action_release("dash")
	await frames(60)
	player.weapons.equip(&"unarmed")
	player.position = Vector2(1800, -260)
	player.velocity = Vector2.ZERO
	await frames(2)
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	await frames(6)
	focus(player.global_position)
	await capture("viridy_dive")
	await frames(60)
	player.position = Vector2(1800, -2)
	player.liquid_beast = true
	await frames(4)
	Input.action_press("move_up")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	await frames(5)
	Input.action_release("move_up")
	focus(player.global_position)
	await capture("beast_uppercut")
	quit()
