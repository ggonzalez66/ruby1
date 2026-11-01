extends SceneTree
# Capturas del sigilo y la tienda del Gauntlet: conos de visión, bush, alarma, precaución y pantalla de mejoras.
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/art/capture_stealth.gd
const DIRECTORY := "res://docs/art/stealth/runtime"
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
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var stealth: Node2D = get_first_node_in_group(&"stealth_director")
	var upgrades: Node = root.get_node("Upgrades")
	director._clear_wave()
	stealth.begin_wave()
	var bush: Node2D = stealth.bushes[0]
	director._add_chaser(bush.position + Vector2(230, 0))
	director._add_scripted(load("res://rifleman.gd"), bush.position + Vector2(-330, 0))
	await frames(4)
	var guard: Area2D = director.enemies[0]
	var rifle: Area2D = director.enemies[1]
	guard.get_node("StealthAgent").timer = 999.0
	guard.get_node("StealthAgent")._turn(-1)
	rifle.get_node("StealthAgent").timer = 999.0
	rifle.get_node("StealthAgent")._turn(1)
	player.position = bush.position + Vector2(-90, -2)
	stealth.cloak_left = 0.0
	await frames(10)
	await capture("conos_de_vision")
	player.position = bush.position + Vector2(10, -2)
	await frames(30)
	await capture("en_el_bush")
	stealth.bush_time = 2.0
	await frames(3)
	await capture("bush_lista")
	player.position = bush.position + Vector2(140, -2)
	await frames(6)
	await capture("invisible")
	stealth.cloak_left = 0.0
	player.position = guard.global_position + Vector2(-120, -2)
	await frames(30)
	await capture("descubierta_cargando")
	stealth.trigger_alarm()
	await frames(20)
	await capture("alarma")
	stealth.evasion_left = 0.02
	await frames(3)
	player.position = bush.position + Vector2(10, -2)
	await frames(10)
	await capture("precaucion_marca")
	upgrades.add_rubies(23)
	director.upgrade_menu.open()
	await process_frame
	await capture("mejora_gratis")
	director.upgrade_menu.choose(0)
	await process_frame
	await capture("tienda")
	quit(0)
