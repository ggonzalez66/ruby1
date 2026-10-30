extends SceneTree

# Enemigos nuevos (conceptos del usuario): sabueso (inmoviliza, machacar el ligero para soltarse, se
# parrea), centinela (alarma y refuerzos, se corta golpeándolo), fusilero (láser y ráfaga), aguijón
# (orbita, se fija y embiste), restaurador (repara, huye y descarga) y guardián mecha (puñetazo,
# martillazo y misiles). También que aparezcan en el Gauntlet.
# Uso: godot --headless --path . -s res://tests/integration/test_new_enemies.gd

var level: Node
var player: CharacterBody2D
var F: Node
var fails := 0
var checks := 0
const GROUND := Vector2(2300, -2)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func check(c: bool, label: String) -> void:
	checks += 1
	print("  OK   " if c else "  FAIL ", label)
	if not c:
		fails += 1

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy_attack", "dash", "throw_knife", "roar"]:
		Input.action_release(a)

func tap(a: String) -> void:
	Input.action_press(a)
	await frames(1)
	Input.action_release(a)
	await frames(1)

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.invulnerability_timer = 0.0
	await frames(5)

func spawn(path: String, at: Vector2) -> Node2D:
	var enemy: Node2D = load(path).new()
	enemy.position = at
	level.add_child(enemy)
	return enemy

func clear_enemies() -> void:
	for enemy in get_nodes_in_group(&"training_dummies"):
		enemy.remove_from_group(&"training_dummies")
		enemy.queue_free()
	for node in get_nodes_in_group(&"projectiles"):
		node.queue_free()

func _run() -> void:
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")
	clear_enemies()
	for boss in get_nodes_in_group(&"boss"):
		boss.queue_free()
	await frames(2)

	print("== Sabueso")
	await reset()
	var hound: Node2D = spawn("res://hound.gd", GROUND + Vector2(420, 0))
	var health: int = player.current_health
	var pinned := false
	for i in range(240):
		await frames(1)
		if player.is_pinned():
			pinned = true
			break
	check(pinned and hound.pinning, "persigue, salta y deja a Viridy inmovilizada")
	check(player.current_health == health, "inmovilizar no quita vida")
	var x_before: float = player.global_position.x
	Input.action_press("move_right")
	await frames(10)
	Input.action_release("move_right")
	check(absf(player.global_position.x - x_before) < 2.0 and player.pin_label.visible, "inmovilizada no se mueve y ve el aviso de machacar")
	var chaser: Node2D = spawn("res://chaser_dummy.gd", player.global_position + Vector2(-150, 0))
	var hit := false
	for i in range(150):
		await frames(1)
		if player.current_health < health:
			hit = true
			break
	check(hit and player.is_pinned(), "otro enemigo le pega mientras sigue inmovilizada")
	chaser.queue_free()
	await reset()
	hound.reset_dummy()
	hound.global_position = GROUND + Vector2(200, 0)
	for i in range(240):
		await frames(1)
		if player.is_pinned():
			break
	for i in range(hound.mash_count):
		await tap("attack")
	await frames(2)
	check(not player.is_pinned() and hound.state == hound.State.STAGGER and not hound.pinning, "machacar el ligero la suelta y despide al sabueso")
	await reset()
	hound.reset_dummy()
	hound.global_position = GROUND + Vector2(200, 0)
	for i in range(240):
		await frames(1)
		if player.is_pinned():
			break
	for i in range(int(player.PIN_MAX_TIME * 60.0) + 10):
		await frames(1)
		if not player.is_pinned():
			break
	check(not player.is_pinned(), "sin machacar se suelta sola a los %.1f s" % player.PIN_MAX_TIME)
	# Parry: el rugido justo cuando salta lo desvía y abre su rubí.
	await reset()
	hound.reset_dummy()
	hound.cooldown = 0.0
	hound.global_position = GROUND + Vector2(200, 0)
	var parried := false
	for i in range(240):
		await frames(1)
		if hound.state == hound.State.SWING and absf(hound.global_position.x - player.global_position.x) < 80.0:
			await tap("roar")
			for j in range(30):
				await frames(1)
				if hound.state == hound.State.STAGGER:
					parried = true
					break
			break
	check(parried and not player.is_pinned() and hound.ruby_core.open_time > 0.0, "el rugido parrea el salto y abre el rubí del sabueso")
	hound.queue_free()
	await frames(2)

	print("== Centinela")
	await reset()
	clear_enemies()
	await frames(2)
	var sentinel: Node2D = spawn("res://sentinel.gd", GROUND + Vector2(380, 0))
	var sleeper: Node2D = spawn("res://chaser_dummy.gd", GROUND + Vector2(-500, 0))
	sleeper.set_physics_process(false)
	await frames(2)
	var before: int = get_nodes_in_group(&"training_dummies").size()
	var alarming := false
	for i in range(60):
		await frames(1)
		if sentinel.state == sentinel.State.TELEGRAPH:
			alarming = true
			break
	check(alarming and sentinel.warning_label.visible, "ve a Viridy y empieza la alarma")
	for i in range(int(sentinel.alarm_time * 60.0) + 10):
		await frames(1)
	await frames(3)
	check(get_nodes_in_group(&"training_dummies").size() == before + sentinel.reinforcements, "la alarma trae %d refuerzos" % sentinel.reinforcements)
	check(sleeper.alert_until_msec > Time.get_ticks_msec(), "y despierta a los enemigos cercanos")
	clear_enemies()
	await frames(2)
	sentinel = spawn("res://sentinel.gd", GROUND + Vector2(380, 0))
	await frames(2)
	before = get_nodes_in_group(&"training_dummies").size()
	for i in range(60):
		await frames(1)
		if sentinel.state == sentinel.State.TELEGRAPH:
			break
	sentinel.take_hit(player.global_position, 1, 1)
	for i in range(int(sentinel.alarm_time * 60.0) + 10):
		await frames(1)
	check(get_nodes_in_group(&"training_dummies").size() == before and not sentinel.called_reinforcements, "golpearlo mientras carga corta la alarma")
	clear_enemies()
	await frames(2)

	print("== Fusilero")
	await reset()
	var rifleman: Node2D = spawn("res://rifleman.gd", GROUND + Vector2(420, 0))
	var aimed := false
	for i in range(90):
		await frames(1)
		if rifleman.state == rifleman.State.TELEGRAPH and rifleman.laser.default_color.a > 0.0:
			aimed = true
			break
	check(aimed, "apunta con el láser de aviso")
	var shots := 0
	for i in range(int((rifleman.aim_time + rifleman.burst_gap * rifleman.burst) * 60.0) + 20):
		await frames(1)
		shots = maxi(shots, get_nodes_in_group(&"projectiles").size())
	check(shots >= 2 and rifleman.state in [rifleman.State.SWING, rifleman.State.RECOVER], "suelta una ráfaga (%d disparos en el aire)" % shots)
	clear_enemies()
	await frames(2)
	await reset()
	rifleman = spawn("res://rifleman.gd", GROUND + Vector2(-140, 0))
	await frames(30)
	check(rifleman.global_position.x < GROUND.x - 140.0, "retrocede si Viridy se le echa encima")
	clear_enemies()
	await frames(2)

	print("== Aguijón")
	await reset()
	var stingers: Array = []
	for index in range(3):
		stingers.append(spawn("res://stinger.gd", GROUND + Vector2(150 + index * 50, -220)))
	var orbit_ok := false
	var dived := false
	health = player.current_health
	for i in range(420):
		await frames(1)
		for stinger in stingers:
			if stinger.state == stinger.State.PATROL and absf(stinger.global_position.distance_to(player.global_position + Vector2(0, -40)) - stinger.orbit_radius) < 70.0:
				orbit_ok = true
			if stinger.state == stinger.State.DIVE:
				dived = true
		if dived and player.current_health < health:
			break
	check(orbit_ok, "orbitan alrededor de Viridy")
	check(dived and player.current_health < health, "se fijan y embisten")
	clear_enemies()
	await frames(2)

	print("== Restaurador")
	await reset(GROUND + Vector2(-1200, 0))
	var patient: Node2D = spawn("res://chaser_dummy.gd", GROUND + Vector2(300, 0))
	patient.set_physics_process(false)
	var restorer: Node2D = spawn("res://restorer.gd", GROUND + Vector2(100, -200))
	await frames(2)
	patient.current_health = 3
	for i in range(240):
		await frames(1)
		if patient.current_health >= 6:
			break
	check(patient.current_health >= 6, "repara al aliado dañado (%d/%d)" % [patient.current_health, patient.max_health])
	check(restorer.max_health >= 12, "aguanta más que los demás pequeños (%d de vida)" % restorer.max_health)
	patient.ruby_core.enter_dying()
	patient.current_health = 0
	check(not restorer._repairable(patient), "no repara a un enemigo en DYING")
	await reset(restorer.global_position + Vector2(-60, 40))
	health = player.current_health
	var pulsed := false
	for i in range(120):
		player.global_position = restorer.global_position + Vector2(-50, 40)
		await frames(1)
		if player.current_health < health:
			pulsed = true
			break
	check(pulsed, "acorralado suelta una descarga")
	clear_enemies()
	await frames(2)

	print("== Guardián mecha")
	await reset()
	var spawner: Node = load("res://boss_spawner.gd").new()
	spawner.auto_spawn = false
	spawner.forced_boss = 3
	spawner.spawn_point = GROUND + Vector2(700, 0)
	spawner.arena_min_x = GROUND.x - 1500.0
	spawner.arena_max_x = GROUND.x + 1500.0
	level.add_child(spawner)
	spawner.spawn_round()
	await frames(2)
	var mecha: Node2D = spawner.bosses[0]
	check(mecha.get_script() == load("res://boss_mecha.gd") and mecha.boss_name == "GUARDIÁN MECHA", "el selector de guardianes trae al mecha")
	check(spawner.BOSSES.size() == 4 and spawner.TRIO_MEMBERS == [0, 1, 2], "el trío sigue siendo pesado, ágil y arquero")
	var missiles := 0
	for i in range(300):
		await frames(1)
		for node in get_nodes_in_group(&"projectiles"):
			if node.get_script() == load("res://missile.gd"):
				missiles += 1
		if missiles > 0:
			break
	check(missiles > 0, "de lejos lanza una salva de misiles")
	await frames(150)
	# Sin reset(): reaparecer a Viridy haría que el selector (sin auto_spawn) quitara al guardián.
	mecha.missile_cooldown = 99.0
	for attack in [[mecha.State.PUNCH_WINDUP, mecha.punch_windup, "el puñetazo la alcanza"], [mecha.State.SLAM_WINDUP, mecha.slam_windup, "el martillazo la alcanza"]]:
		for node in get_nodes_in_group(&"projectiles"):
			node.queue_free()
		player.global_position = mecha.global_position + Vector2(-170, 0)
		player.velocity = Vector2.ZERO
		player.invulnerability_timer = 0.0
		await frames(2)
		health = player.current_health
		mecha._start_windup(attack[0], attack[1], "")
		var landed := false
		for i in range(int(attack[1] * 60.0) + 40):
			await frames(1)
			if player.current_health < health:
				landed = true
				break
		check(landed, attack[2])
		await frames(80)
	spawner.clear_bosses()
	spawner.queue_free()
	clear_enemies()
	await frames(2)

	print("== Gauntlet")
	level.queue_free()
	await frames(5)
	var gauntlet: Node = load("res://gauntlet.tscn").instantiate()
	root.add_child(gauntlet)
	await frames(15)
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var kinds := {}
	for round_number in [1, 3]:
		director.round_number = round_number
		director._start_wave()
		await frames(5)
		for enemy in director.enemies:
			if is_instance_valid(enemy):
				kinds[[round_number, enemy.get_script().resource_path.get_file()]] = true
	check(kinds.has([1, "rifleman.gd"]), "desde la ronda 1 hay fusileros")
	for file in ["hound.gd", "sentinel.gd", "stinger.gd", "restorer.gd", "rifleman.gd"]:
		check(kinds.has([3, file]), "en la ronda 3 aparece %s" % file)

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
