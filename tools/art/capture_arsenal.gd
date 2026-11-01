extends SceneTree
# Capturas del arsenal del Gauntlet: confirmación de arma, armas a distancia, variantes, Enfoque y Reloj detenido.
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/art/capture_arsenal.gd
const DIRECTORY := "res://docs/art/arsenal/runtime"
var player: CharacterBody2D
var director: Node
var upgrades: Node

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

func quiet_chaser(at: Vector2) -> Area2D:
	director._add_chaser(at)
	await frames(4)
	var enemy: Area2D = director.enemies[-1]
	var agent: Node = enemy.get_node("StealthAgent")
	agent.timer = 999.0
	agent._turn(1)
	return enemy

func aim(direction: Vector2) -> void:
	player.combo.aim = true
	player.combo.aim_direction = direction.normalized()
	player.combo.queue_redraw()

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
	director = get_first_node_in_group(&"gauntlet_director")
	var stealth: Node2D = get_first_node_in_group(&"stealth_director")
	upgrades = root.get_node("Upgrades")
	var hints: Node = root.get_node("InputHints")
	hints.device = hints.Device.JOYPAD
	director._clear_wave()
	stealth.begin_wave()
	player.position = Vector2(2200, -2)
	await frames(6)

	var menu: CanvasLayer = director.upgrade_menu
	upgrades.add_rubies(40)
	menu.open()
	menu.cards = [upgrades._weapon_card("railgun"), upgrades._element_card("electric", upgrades.RANGED_SLOT), upgrades._card("time_stop")]
	menu._render()
	await process_frame
	await capture("mejoras_nuevas")
	menu.choose(0)
	await process_frame
	await capture("confirmar_arma")
	menu.cancel_replace()
	menu.root_control.hide()
	paused = false
	await frames(3)

	for pair in [["fire", 2400.0], ["ice", 2560.0], ["electric", 2720.0]]:
		var enemy := await quiet_chaser(Vector2(pair[1], 0))
		director.make_variant(enemy, pair[0])
	await frames(12)
	await capture("variantes")

	upgrades.grant(upgrades._weapon_card("pistol"))
	await frames(2)
	aim(Vector2(1, -0.02))
	player._throw_spear()
	await frames(3)
	await capture("pistola")

	upgrades.grant(upgrades._weapon_card("railgun"))
	player.jade_fire_cooldown_timer = 0.0
	aim(Vector2(1, -0.02))
	await frames(2)
	player._throw_spear()
	await process_frame
	await capture("railgun")
	await create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0

	upgrades.grant(upgrades._weapon_card("grenade"))
	player.jade_fire_cooldown_timer = 0.0
	aim(Vector2(1, -0.12))
	await frames(2)
	player._throw_spear()
	await frames(6)
	await capture("granada")
	for _i in range(60):
		await frames(1)
		if player.get_parent().get_children().filter(func(node): return node.get_script() == load("res://ice_grenade.gd")).size() > 1:
			break
	await frames(6)
	await capture("racimos")

	player.ailments.apply("electric")
	player.ailments.apply("ice")
	player.ailments.apply("fire")
	await frames(10)
	await capture("elementos_en_viridy")
	player.ailments.clear()

	var rifle: Area2D = await quiet_chaser(player.global_position + Vector2(420, 0))
	director._clear_wave()
	director._add_scripted(load("res://rifleman.gd"), player.global_position + Vector2(420, 0))
	await frames(4)
	rifle = director.enemies[-1]
	rifle.set_physics_process(false)
	rifle.aim_direction = Vector2(-1, -0.03).normalized()
	rifle._fire()
	await frames(4)
	await capture("bala_fusilero")
	await frames(10)
	director._clear_wave()
	player.current_health = player.max_health

	stealth.trigger_alarm()
	await frames(4)
	upgrades.focus = 62.0
	await capture("alarma_y_enfoque")
	stealth.stand_down()

	upgrades.grant(upgrades._card("time_stop"))
	upgrades.focus = 90.0
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	await frames(6)
	await capture("tiempo_detenido")
	Input.action_release("slow_motion")
	await frames(2)
	quit(0)
