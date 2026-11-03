extends SceneTree

# Dificultad de la run (pedido del 2026-11-03): cámaras de seguridad en la fábrica (cono, paredes, bush,
# alarma casi instantánea y refuerzos), refuerzos dobles del centinela, embestida del sabueso que solo para
# el parry (la guardia no), halcón espiritual que solo ataca lo que ve y ligeros aéreos que no la elevan.
var checks := 0
var fails := 0
var upgrades: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func release() -> void:
	for action in ["attack", "heavy_attack", "jump", "dash", "throw_knife", "roar", "move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)

func open(path: String) -> void:
	change_scene_to_file(path)
	for _i in range(60):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			break
	await frames(10)

func player() -> CharacterBody2D:
	return get_first_node_in_group(&"player")

func park_enemies(director: Node) -> void:
	# Los guardias quedan lejos y quietos (siguen contando como vivos).
	for enemy in director.enemies:
		if is_instance_valid(enemy):
			enemy.global_position = Vector2(80, -2000)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED

func aim_at_player(camera: Node2D) -> void:
	var direction: Vector2 = player().global_position + Vector2(0, -40) - camera.global_position
	camera.aim_angle = rad_to_deg(direction.angle())
	camera.sweep = 0.0
	camera.angle = direction.angle()

func _run() -> void:
	root.size = Vector2i(1152, 648)
	upgrades = root.get_node("Upgrades")

	print("== Cámaras: afueras")
	await open("res://factory_outdoor.tscn")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var stealth: Node = get_first_node_in_group(&"stealth_director")
	check(get_nodes_in_group(&"security_cameras").size() == 3, "tres cámaras en las entradas de afuera")
	check(stealth.FILL_TIME <= 1.5, "la alarma de los guardias se llena en %.1f s" % stealth.FILL_TIME)
	await frames(5)
	park_enemies(director)
	var camera: Node2D = current_scene.get_node("CameraDoor")
	# Todas las cámaras miran a la derecha y arriba, lejos de Viridy.
	for other in get_nodes_in_group(&"security_cameras"):
		other.aim_angle = -30.0
		other.sweep = 0.0
		other.angle = deg_to_rad(-30.0)
		other.lock_left = 0.0
	player().global_position = Vector2(3250, -2)
	await frames(3)
	stealth._clear_alert()
	await frames(30)
	check(stealth.level == 0.0 and not camera.spotting, "fuera del cono no la ve")
	var before: int = director.enemies.size()
	aim_at_player(camera)
	var frames_to_alarm := 0
	for _i in range(60):
		await frames(1)
		frames_to_alarm += 1
		if stealth.alarm_active():
			break
	check(stealth.alarm_active() and frames_to_alarm <= 30, "en el cono la alarma salta casi al instante (%d frames)" % frames_to_alarm)
	await frames(3)
	check(director.enemies.size() == before + 4 and camera.called_reinforcements, "la alarma de la cámara trae 4 refuerzos (%d)" % (director.enemies.size() - before))
	stealth.evasion_left = 1.0
	await frames(20)
	check(stealth.alarm_active() and stealth.evasion_left > 8.0, "mientras la ve, la alarma no se apaga")
	stealth._end_alarm()
	stealth._clear_alert()
	stealth.cloak_left = 10.0
	await frames(30)
	check(stealth.level == 0.0 and not stealth.alarm_active(), "invisible tras un bush no la ve")
	stealth.cloak_left = 0.0

	print("== Cámaras: dentro, las paredes tapan")
	await open("res://factory_indoor.tscn")
	director = get_first_node_in_group(&"gauntlet_director")
	stealth = get_first_node_in_group(&"stealth_director")
	check(get_nodes_in_group(&"security_cameras").size() == 5, "cinco cámaras dentro de la fábrica")
	await frames(5)
	park_enemies(director)
	camera = current_scene.get_node("CameraF1")
	# Viridy en el piso 2, justo encima de la cámara del piso 1: la losa la tapa.
	player().global_position = Vector2(camera.global_position.x, -442)
	await frames(10)
	camera.sweep = 0.0
	camera.aim_angle = -90.0
	camera.angle = -PI * 0.5
	await frames(30)
	check(stealth.level == 0.0 and not camera.spotting, "a través de la losa no la ve")
	player().global_position = Vector2(camera.global_position.x + 120, -2)
	await frames(10)
	aim_at_player(camera)
	await frames(30)
	check(stealth.alarm_active(), "en su piso, sí")

	print("== Centinela: refuerzos dobles")
	var sentinel: Node = load("res://sentinel.gd").new()
	check(sentinel.reinforcements == 4, "el centinela llama %d refuerzos" % sentinel.reinforcements)
	sentinel.free()

	print("== Sabueso: más rápido; la guardia no lo para")
	await open("res://factory_boss.tscn")
	director = get_first_node_in_group(&"gauntlet_director")
	director.set_physics_process(false)
	var hound: Node2D = load("res://hound.gd").new()
	check(hound.pounce_time < 0.3 and hound.telegraph_time < 0.3 and hound.pounce_range > 300.0, "embestida más rápida y de más lejos")
	hound.position = Vector2(1200, 0)
	current_scene.add_child(hound)
	player().global_position = Vector2(900, -2)
	await frames(5)
	Input.action_press("roar")
	await frames(20)
	check(player().roar_active and not player()._is_roar_invincible(), "Viridy en guardia (sin parry)")
	var pinned := false
	for _i in range(240):
		await frames(1)
		if player().is_pinned():
			pinned = true
			break
	Input.action_release("roar")
	check(pinned and hound.pinning, "la embestida atraviesa la guardia e inmoviliza")
	for _i in range(hound.mash_count):
		await tap("attack")
	await frames(30)
	hound.queue_free()

	print("== Halcón espiritual: solo ataca lo que ve")
	await open("res://factory_indoor.tscn")
	director = get_first_node_in_group(&"gauntlet_director")
	director.set_physics_process(false)
	park_enemies(director)
	# Sin cámaras: sus refuerzos atacarían al halcón.
	get_first_node_in_group(&"stealth_director").stand_down()
	for other in get_nodes_in_group(&"security_cameras"):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	upgrades.owned["spirit_hawk"] = 1
	player().global_position = Vector2(2000, -2)
	director._sync_allies()
	await frames(30)
	var hawk: Node2D = director.allies.get("spirit_hawk")
	check(is_instance_valid(hawk), "aparece el halcón")
	# Un enemigo en el piso de arriba, a su alcance pero detrás de la losa.
	var hidden: Area2D = load("res://chaser_dummy.gd").new()
	hidden.position = Vector2(2100, -442)
	current_scene.add_child(hidden)
	await frames(3)
	hidden.set_physics_process(false)
	hawk.cooldown = 0.0
	var hidden_health: int = hidden.current_health
	await frames(90)
	check(hidden.current_health == hidden_health and hawk.target != hidden, "no ataca a través de la losa")
	var seen: Area2D = load("res://chaser_dummy.gd").new()
	seen.position = Vector2(2250, -2)
	current_scene.add_child(seen)
	await frames(3)
	seen.set_physics_process(false)
	var seen_health: int = seen.current_health
	hawk.cooldown = 0.0
	for _i in range(240):
		await frames(1)
		if seen.current_health < seen_health:
			break
	check(seen.current_health < seen_health, "al que ve sí lo ataca")
	upgrades.owned.erase("spirit_hawk")

	print("== Ligeros aéreos: se queda a la altura del enemigo")
	await open("res://factory_boss.tscn")
	director = get_first_node_in_group(&"gauntlet_director")
	director.set_physics_process(false)
	var target: Area2D = load("res://training_dummy.tscn").instantiate()
	target.position = Vector2(1060, -300)
	target.aerial = true
	target.max_health = 999
	target.shoot_interval = 0.0
	current_scene.add_child(target)
	await frames(3)
	target.set_physics_process(false)
	player().global_position = Vector2(1000, -300)
	player().facing = 1
	player()._update_facing_visual()
	# Viene subiendo de un salto.
	player().velocity = Vector2(0, -620)
	await frames(1)
	var start_y: float = player().global_position.y
	var highest := start_y
	var lowest := start_y
	for _i in range(5):
		await tap("attack")
		for _j in range(9):
			await frames(1)
			highest = minf(highest, player().global_position.y)
			lowest = maxf(lowest, player().global_position.y)
	check(player().combo.air_stall, "conecta en el aire")
	check(start_y - highest < 45.0, "el string no la eleva (subió %.0f px)" % (start_y - highest))
	check(lowest - start_y < 45.0 and not player().is_on_floor(), "ni la deja caer (bajó %.0f px)" % (lowest - start_y))
	release()

	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
