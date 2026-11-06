extends SceneTree

# Capturas de la tanda del 2026-11-04: combo con rodillazo y patadas normalizadas, corona de los enemigos
# elementales, estados con PixelFX, aterrizaje del picado (onda y brasas), estallido del ruby en rombo y
# orbes, corte del uppercut, muerte de Viridy, arbusto con contornos, pasarelas atravesables, ambiente de
# la jungla, fuente y transición de escena. Requiere renderer con ventana:
#   godot --path . --rendering-driver opengl3 -s res://tools/art/capture_batch_nov4.gd
# CAPTURE_ONLY=claws|combo|crown|status|landing|ruby|uppercut|death|bush|catwalk|ambient|fountain|fade|hound|variants
const DIRECTORY := "res://docs/batch_2026_11_04/runtime"
# Godot 4.7 no compila un script de -s que precarga scripts que usan autoloads (aún no existen al compilarlo):
# se cargan al empezar.
var FX: Script
var CHASER: Script
var HOUND: Script

func _initialize() -> void:
	FX = load("res://fx.gd")
	CHASER = load("res://chaser_dummy.gd")
	HOUND = load("res://hound.gd")
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

func player() -> CharacterBody2D:
	return get_first_node_in_group(&"player")

func view(at: Vector2, zoom: float) -> void:
	var camera: Camera2D = player().get_node("Camera2D")
	camera.set_process(false)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.offset = Vector2.ZERO
	camera.global_position = at
	camera.zoom = Vector2.ONE * zoom
	camera.reset_smoothing()
	await frames(2)

func quiet_director() -> Node:
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	if director != null:
		director.set_physics_process(false)
		for enemy in director.get("enemies") if director.get("enemies") != null else []:
			if is_instance_valid(enemy):
				enemy.queue_free()
	var stealth: Node = get_first_node_in_group(&"stealth_director")
	if stealth != null:
		stealth.set_physics_process(false)
		stealth.set_process(false)
	return director

func enemy(script: Script, at: Vector2) -> Node2D:
	var body: Node2D = script.new()
	current_scene.add_child(body)
	body.global_position = at
	await frames(2)
	body.set_physics_process(false)
	return body

func combo() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1200, -2)
	p.facing = 1
	p._update_facing_visual()
	await frames(10)
	await view(Vector2(1260, -60), 2.4)
	await capture("combo_idle")
	# Golpes 3 (rodillazo), 4 y 5 (patadas): el tamaño debe igualar al de pie y el barrido, a su zona.
	for step in [2, 3, 4]:
		p.combo.cancel()
		p.attack_cooldown_timer = 0.0
		p.combo.step = step - 1
		p.combo.window = 0.5
		p.combo.request()
		while p.combo.active and p.combo.elapsed < p.combo.startup + p.combo.active_time * 0.6:
			await frames(1)
		p.set_physics_process(false)
		await frames(1)
		await capture("combo_hit%d" % (step + 1))
		p.set_physics_process(true)
		await frames(20)

func claws() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1200, -2)
	p.facing = 1
	p._update_facing_visual()
	await frames(10)
	for step in [0, 1]:
		for moment in [0.2, 0.8]:
			p.combo.cancel()
			p.attack_cooldown_timer = 0.0
			p.combo.step = step - 1
			p.combo.window = 0.5 if step > 0 else 0.0
			p.combo.request()
			while p.combo.active and p.combo.elapsed < p.combo.startup + p.combo.active_time * moment:
				await frames(1)
			p.set_physics_process(false)
			await view(p.global_position + Vector2(40, -40), 3.0)
			await capture("claw_hit%d_%d" % [step + 1, int(moment * 10)])
			p.set_physics_process(true)
			await frames(20)

func crown() -> void:
	await wait_scene("res://factory_boss.tscn")
	var director := quiet_director()
	player().global_position = Vector2(700, -2)
	var spots := [Vector2(1150, -2), Vector2(1400, -2), Vector2(1650, -2)]
	var kinds := ["fire", "ice", "electric"]
	var bodies: Array = []
	bodies.append(await enemy(CHASER, spots[0]))
	bodies.append(await enemy(HOUND, spots[1]))
	bodies.append(await enemy(load("res://rifleman.gd"), spots[2]))
	for index in range(bodies.size()):
		director.make_variant(bodies[index], kinds[index])
	await frames(20)
	await view(Vector2(1400, -80), 1.8)
	await capture("crown_variants")

func status() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	player().global_position = Vector2(700, -2)
	var a: Node2D = await enemy(CHASER, Vector2(1150, -2))
	var b: Node2D = await enemy(CHASER, Vector2(1400, -2))
	var c: Node2D = await enemy(HOUND, Vector2(1650, -2))
	FX.status(a, "burning", Vector2(0, 2), 1.4)
	FX.status(b, "ice_block", Vector2(0, 4), 1.4, Color(1, 1, 1, 0.62))
	b.modulate = Color(0.6, 0.85, 1.5)
	FX.status(c, "stunned", c.impact_offset + Vector2(0, -30), 1.0)
	FX.muzzle(current_scene, Vector2(1880, -40), 0.0, Color(1.0, 0.85, 0.45), 1.0)
	await frames(8)
	await view(Vector2(1450, -70), 1.8)
	await capture("status_burn_ice_stun")
	FX.ice_shatter(current_scene, b.global_position + Vector2(0, 4), 0.85)
	b.queue_free()
	await frames(6)
	await capture("status_ice_shatter")

func landing() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1300, -2)
	await frames(10)
	await view(Vector2(1300, -60), 2.0)
	FX.shockwave(current_scene, p.global_position, p.LANDING_JADE, 1.1)
	FX.embers(current_scene, p.global_position + Vector2(10, 0), p.LANDING_JADE, 1.2)
	await frames(5)
	await capture("landing_wave")
	await frames(20)
	await capture("landing_embers_hang")

func ruby() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1100, -2)
	await frames(10)
	await view(Vector2(1250, -90), 1.6)
	FX.ruby_burst(current_scene, Vector2(1400, -40), Color(1.0, 0.08, 0.15), 125.0)
	FX.absorb_orbs(current_scene, Vector2(1400, -40), p, Color(1.0, 0.18, 0.25), 10)
	await frames(6)
	await capture("ruby_burst")
	await frames(10)
	await capture("ruby_orbs")

func uppercut() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1200, -2)
	p.facing = 1
	await frames(10)
	p._start_uppercut_attack(false)
	await frames(10)
	await view(Vector2(1240, -150), 1.6)
	await capture("uppercut_cut")
	await frames(16)
	await capture("uppercut_cut_fading")

func death() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1300, -2)
	p.respawn_enabled = false
	await frames(10)
	var camera: Camera2D = p.get_node("Camera2D")
	p.take_damage(9999, p.global_position + Vector2(60, -20))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.2, true, false, true).timeout
	await capture("death_freeze_negative")
	await create_timer(0.75, true, false, true).timeout
	await capture("death_flight")
	await create_timer(0.75, true, false, true).timeout
	await capture("death_jade_blast")

func bush() -> void:
	await wait_scene("res://factory_outdoor.tscn")
	quiet_director()
	var p := player()
	var bushes := get_nodes_in_group(&"bushes")
	if bushes.is_empty():
		return
	var spot: Node2D = bushes[0]
	p.global_position = spot.global_position + Vector2(-20, -2)
	var guard: Node2D = await enemy(CHASER, spot.global_position + Vector2(45, -2))
	guard.visible = true
	await frames(10)
	await view(spot.global_position + Vector2(0, -50), 2.2)
	await capture("bush_outlines")

func catwalk() -> void:
	await wait_scene("res://factory_indoor.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(950, -2)
	await frames(10)
	await view(Vector2(1300, -180), 0.9)
	await capture("catwalks_indoor")

func ambient() -> void:
	await wait_scene("res://factory_outdoor.tscn")
	quiet_director()
	player().global_position = Vector2(700, -2)
	await frames(90)
	await view(Vector2(900, -260), 0.8)
	await capture("jungle_ambient")

func fountain() -> void:
	await wait_scene("res://fountain.tscn")
	var p := player()
	p.global_position = Vector2(1900, 150)
	p.current_health = 40
	await frames(20)
	await view(Vector2(1950, 40), 1.0)
	await capture("fountain_ripples")
	await frames(30)
	await capture("fountain_bloom")

func fade() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var scene_fade: Node = root.get_node("SceneFade")
	scene_fade.cover()
	await create_timer(0.3, true, false, true).timeout
	await capture("transition_burning")
	await scene_fade.covered
	scene_fade.reveal()
	await create_timer(0.3, true, false, true).timeout
	await capture("transition_opening")
	await create_timer(1.0, true, false, true).timeout
	# cover() deja el juego en pausa (SceneFade.go lo reanuda al cambiar de escena): sin esto, las secciones
	# siguientes saldrían congeladas al correr todas seguidas.
	paused = false

func hound() -> void:
	await wait_scene("res://factory_boss.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1500, -2)
	var dog: Node2D = await enemy(HOUND, Vector2(1200, -2))
	dog.set_physics_process(true)
	dog.cooldown = 0.0
	dog._face(p)
	dog._start_telegraph()
	await frames(8)
	await view(Vector2(1350, -80), 1.8)
	await capture("hound_warning")
	for _i in range(60):
		await frames(1)
		if dog.state == dog.State.SWING and dog.airborne:
			break
	await frames(6)
	await capture("hound_trail")

func variants() -> void:
	# [escena, centro de la vista, zoom]
	var shots := [
		["res://factory_outdoor_b.tscn", Vector2(2000, -250), 0.42],
		["res://factory_outdoor_c.tscn", Vector2(2300, -300), 0.42],
		["res://factory_indoor_b.tscn", Vector2(1800, -620), 0.42],
		["res://factory_indoor_c.tscn", Vector2(1800, -620), 0.42],
	]
	for shot in shots:
		await wait_scene(shot[0])
		quiet_director()
		player().global_position = shot[1] + Vector2(0, 250)
		await frames(20)
		await view(shot[1], shot[2])
		await capture("variant_" + String(shot[0]).get_file().get_basename())
	await wait_scene("res://factory_indoor_b.tscn")
	quiet_director()
	var p := player()
	p.global_position = Vector2(1300, 158)
	Input.action_press("move_right")
	await frames(40)
	Input.action_release("move_right")
	await view(Vector2(1400, 60), 1.6)
	await capture("water_bubbles")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta captura requiere renderer con ventana.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var only: String = OS.get_environment("CAPTURE_ONLY")
	for section in ["claws", "combo", "crown", "status", "landing", "ruby", "uppercut", "death", "bush", "catwalk", "ambient", "fountain", "fade", "hound", "variants"]:
		if only == "" or only == section:
			await call(section)
	quit()
