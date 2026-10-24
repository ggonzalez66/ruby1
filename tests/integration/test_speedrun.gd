extends SceneTree

# Movimiento encadenado, estilo aéreo, récords/replay y salida común de los modos.
# Ejecutar con XDG_DATA_HOME temporal, como hace tests/run_tests.sh.
var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D
var session: Node
var style: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right", "attack", "heavy_attack", "roar"]:
		Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)

func _run() -> void:
	session = root.get_node("RunSession")
	style = root.get_node("Ferocity")
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30000, 100)
	shape.shape = rect
	shape.position.y = 50
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(5)

	print("== Bunnyhop acelerado")
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(25)
	await tap("jump")
	await frames(3)
	var speeds := [absf(player.velocity.x)]
	for hop in range(3):
		for i in range(100):
			await frames(1)
			if player.is_on_floor():
				break
		await tap("jump")
		await frames(3)
		speeds.append(absf(player.velocity.x))
	check(speeds[0] < speeds[1] and speeds[1] < speeds[2] and speeds[2] < speeds[3], "cada salto acelera: %s" % [speeds])
	check(player.bunnyhop_chain == 3, "se cuentan tres saltos encadenados")
	await frames(90)
	check(player.bunnyhop_bonus == 0.0, "se pierde el extra al dejar pasar la ventana en el suelo")
	player._respawn_player()
	check(player.bunnyhop_chain == 0 and player.bunnyhop_bonus == 0.0, "reaparecer limpia la cadena")

	print("== Backflip: freno seguido de carrera")
	release_all()
	player.position = Vector2(0, -2)
	await frames(4)
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(24)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await tap("jump")
	var saw_backflip: bool = player.backflip_active
	var saw_brake := false
	var saw_idle := false
	var resumed := false
	for i in range(150):
		await frames(1)
		if saw_brake and player.animated_sprite.animation in [&"idle", &"brake_recover", &"walk"]:
			saw_idle = true
		if player.is_on_floor() and not player.backflip_active:
			saw_brake = saw_brake or player.animated_sprite.animation == &"sprint_brake"
			if player.is_sprinting and player.sprint_direction == -1 and player.velocity.x < -500:
				resumed = true
				break
	check(saw_backflip and saw_brake, "aterriza del backflip y frena")
	check(resumed and not saw_idle, "pasa del freno a carrera contraria sin pose de pie")
	release_all()
	player.set_physics_process(false)

	print("== Tiempo aéreo y puntos graduales")
	style.reset()
	style.update_airtime(1.0, false, false)
	var points: float = style.points
	check(is_equal_approx(style.airtime, 1.0) and points > 0, "el tiempo aéreo suma estilo")
	style.update_airtime(0.5, false, true)
	check(is_equal_approx(style.airtime, 1.0) and is_equal_approx(style.points, points) and style.airtime_paused, "pared pausa contador y ganancia")
	style.update_airtime(0.5, false, false)
	check(is_equal_approx(style.airtime, 1.5) and style.points > points, "continúa la misma cuenta al abandonar la pared")
	style.update_airtime(1.0, true, false)
	check(is_equal_approx(style.airtime, 1.5) and not style.airtime_active, "suelo detiene la cuenta")
	style.update_airtime(0.25, false, false)
	check(is_equal_approx(style.airtime, 0.25), "el siguiente salto inicia una cuenta nueva")
	style.reset()
	arena.queue_free()
	await frames(3)

	print("== Top 10 y fantasma por etapa")
	session.storage_directory = "user://speedrun_test_%d" % Time.get_ticks_usec()
	var level: Node = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(5)
	player = level.get_node("Playerr")
	player.set_physics_process(false)
	session.begin_run(player, false)
	player.position = Vector2(100, -80)
	session.elapsed = 1.0
	session._record_frame()
	player.position = Vector2(200, -120)
	session.elapsed = 2.0
	var first: Dictionary = session.finish_stage()
	check(first.get("best", false) and first.get("saved", false), "primer final guarda tiempo y fantasma")
	var loaded: Dictionary = session.load_record("res://main.tscn")
	check(loaded.get("times", []).size() == 1 and loaded.get("frames", []).size() >= 3, "récord y replay sobreviven al leer desde disco")
	check(session.finish_stage() == first and session.load_record("res://main.tscn")["times"].size() == 1, "completar dos veces no duplica la marca")
	session.begin_run(player, false)
	session.elapsed = 1.5
	session._update_ghost()
	check(session.ghost != null and session.ghost.position.distance_to(Vector2(150, -100) + player.animated_sprite.position) < 1.0, "el fantasma interpola la trayectoria anterior")
	var original_frames: Array = loaded["frames"].duplicate(true)
	for index in range(12):
		session.begin_run(player, false)
		session.elapsed = 3.0 + index
		session.finish_stage()
	loaded = session.load_record("res://main.tscn")
	check(loaded["times"].size() == 10 and loaded["times"][0] == 2.0 and loaded["times"][9] == 11.0, "solo diez tiempos, ordenados de menor a mayor")
	check(loaded["frames"] == original_frames, "una marca peor conserva el fantasma del mejor")
	session.begin_run(player, false)
	session.elapsed = 0.75
	player.position = Vector2(300, -200)
	session.finish_stage()
	loaded = session.load_record("res://main.tscn")
	check(loaded["best"] == 0.75 and loaded["frames"] != original_frames, "una mejor marca reemplaza el replay")
	check(session.load_record("res://stage2.tscn").is_empty(), "cada etapa mantiene su propio ranking")
	var corrupt := FileAccess.open(session._record_path("res://stage2.tscn"), FileAccess.WRITE)
	corrupt.store_string('{"version":1,"times":[],"frames":[["incorrecto"]]}')
	corrupt.close()
	check(session.load_record("res://stage2.tscn").is_empty(), "un registro incompleto no rompe la carga")
	session.begin_run(player, false)
	session.elapsed = 0.0
	paused = true
	await frames(4)
	check(session.elapsed == 0.0, "la pausa no suma tiempo de etapa")
	paused = false
	session.show_records()
	check(session.records_panel.visible, "ranking consultable")
	session._close_records()
	session.begin_run(player, false)
	session.elapsed = 0.5
	for boss in level.get_node("BossSpawner").bosses:
		boss.take_hit(Vector2.ZERO, 1, 9999)
		boss.ruby_core.claim(get_first_node_in_group(&"player"))
		boss.ruby_core.complete(get_first_node_in_group(&"player"))
	check(session.finished and session.result["time"] == 0.5, "vencer al último guardián detiene y guarda el tiempo antes de los resultados")
	session._clear_run()
	level.queue_free()
	await frames(4)

	print("== Ready, ticks y GO en todos los modos")
	for scene in session.MODES:
		change_scene_to_file(scene)
		await frames(6)
		player = current_scene.get_node("Playerr")
		check(session.player == player and session.running, "el escenario inicia su sesión automáticamente")
		session.begin_run(player, true)
		var frozen := player.position
		check(paused and session.ready_label.text == "Ready" and session.countdown_label.text == "0.00", "%s empieza en Ready 0.00" % scene.get_file())
		session.set_process(false)
		session._process(0.51)
		check(session.countdown_tick == 1 and player.position == frozen and session.elapsed == 0.0, "tick intermedio: mundo y cronómetro detenidos")
		session._process(0.49)
		check(not paused and session.running and session.ready_label.text == "GO!" and session.countdown_label.text == "1.00", "GO inicia el modo al llegar a 1.00")
		session.set_process(true)
		await frames(3)
		check(session.elapsed > 0.0, "cronómetro avanza después de GO")
	check(root.get_node("Sfx").last_played.has("ready") and root.get_node("Sfx").last_played.has("countdown_tick") and root.get_node("Sfx").last_played.has("go"), "suenan Ready, segundos y GO")
	session._clear_run()
	paused = false
	await _test_chimney()
	session._clear_run()
	current_scene.queue_free()
	await frames(4)
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)

func _test_chimney() -> void:
	print("== Chimenea del Ruby: recorrido con física real")
	change_scene_to_file("res://stage4.tscn")
	await frames(6)
	player = current_scene.get_node("Playerr")
	player.spawn_position = Vector2(7080, -2)
	player._respawn_player()
	await frames(4)
	Input.action_press("move_right")
	for i in range(90):
		await frames(1)
		if player.position.x >= 7378:
			break
	check(player.position.x >= 7378, "se entra a la chimenea caminando desde el checkpoint")
	release_all()
	player.spawn_position = Vector2(7380, -2)
	player._respawn_player()
	await frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(1)
	var last_side := 0
	var jumps := 0
	var reached := false
	var checkpoint_return := false
	for tick in range(650):
		await frames(1)
		if tick > 60 and player.position.y > -10:
			checkpoint_return = true
			break
		if player.position.y < -1200 and player.position.x < 7280:
			reached = true
			break
		if player.position.y < -1200:
			Input.action_release("move_right")
			Input.action_press("move_left")
		if player.is_on_wall() and not player.is_on_floor():
			var side := int(signf(player.get_wall_normal().x))
			if side != last_side:
				last_side = side
				jumps += 1
				Input.action_release("jump")
				await frames(1)
				Input.action_release("move_right" if side < 0 else "move_left")
				Input.action_press("move_left" if side < 0 else "move_right")
				Input.action_press("jump")
	check(reached and jumps >= 10 and not checkpoint_return, "se alcanza el piso superior con walljumps precisos, sin recibir daño")
	release_all()
	player.global_position = Vector2(7294, -700)
	await frames(4)
	check(player.position.y > -100, "rozar una banda de pinchos devuelve al checkpoint")
	var ruby: Node2D = current_scene.get_node("Ruby1")
	check(ruby.position.x == 3800 and ruby.position.y < -1200, "Ruby centrado y elevado en el piso nuevo")
	player.global_position = ruby.global_position
	await frames(5)
	check(ruby.merging and session.finished and not session.result.is_empty(), "tocar el Ruby guarda el tiempo y el fantasma antes de la fusión")
