extends SceneTree

# Regresión compacta: ataques y dash attack, riposte con el cuchillo, tiradores que shinean, trayectorias
# del heavy aéreo, daga del ágil, shine del arquero y paso de la torre a la etapa 2.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_regression.gd

var level: Node
var player: CharacterBody2D
var F: Node
var St: Node
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

func load_level(path: String) -> void:
	if level:
		level.queue_free()
		await frames(2)
	level = load(path).instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	await frames(5)
	Engine.time_scale = 1.0

func make_dummy(at: Vector2, props: Dictionary = {}) -> Node2D:
	var dummy: Node2D = load("res://training_dummy.tscn").instantiate()
	for key in props:
		dummy.set(key, props[key])
	dummy.position = at
	level.add_child(dummy)
	return dummy

func shoot(from: Vector2, shooter: Node2D, speed: float = 460.0) -> Area2D:
	var shot: Area2D = load("res://projectile.gd").new()
	shot.velocity = (player.global_position + Vector2(0, -16) - from).normalized() * speed
	shot.shooter = shooter
	level.add_child(shot)
	shot.global_position = from
	return shot

func _run() -> void:
	F = root.get_node("Ferocity")
	St = root.get_node("Stats")
	await load_level("res://main.tscn")

	print("== Ataques")
	await reset()
	await tap("attack")
	check(player.combo.active, "ataque ligero al pulsar")
	await frames(30)
	await reset()
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(20)
	await tap("attack")
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED, "dash attack corriendo")
	await frames(3)
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "salto = giro")
	release_all()
	await frames(60)
	await reset(GROUND + Vector2(300, 0))
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(4)
	await tap("attack")
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED and player.facing == -1, "dash attack al frenar hacia el nuevo lado")
	release_all()
	await frames(60)

	print("== Riposte con el cuchillo")
	await reset()
	var target := make_dummy(GROUND + Vector2(380, 2), {"max_health": 60})
	await frames(2)
	var shot := shoot(GROUND + Vector2(90, -16), target)
	Input.action_press("roar")
	await frames(14)
	release_all()
	check(shot.reflected and player.riposte_timer > 0.0, "devolver abre el riposte")
	player.current_health = 50
	player.combo.aim_direction = Vector2.RIGHT
	player._throw_spear()
	await frames(1)
	var knife: Node2D = player.thrown_knife
	check(knife != null and knife.empowered, "el cuchillo sale potenciado")
	await frames(40)
	player.recall_spear()
	check(player.current_health == 50, "sacar el cuchillo de riposte no cura: la energía procede del Ruby (%d)" % player.current_health)
	await frames(60)
	target.queue_free()

	print("== Tirador shinea (proyectil y cuchillo)")
	await reset(Vector2(1000, -2))
	var shooter := make_dummy(Vector2(1280, 0), {"shoot_interval": 99.0, "shine_chance": 1.0, "max_health": 99})
	await frames(2)
	# Shine latente: una devolución perfecta ahora deja open e inmóvil al tirador.
	Input.action_press("roar")
	await frames(14)
	shot = shoot(Vector2(1090, -18), shooter)
	await frames(10)
	release_all()
	await tap("jump")
	var returned := false
	for i in range(60):
		await frames(1)
		if is_instance_valid(shot) and not shot.reflected and shot.shine_level >= 2:
			returned = true
			break
	check(returned, "el tirador devuelve el proyectil")
	await frames(60)
	await reset(Vector2(1000, -2))
	player.current_health = 100
	player.invulnerability_timer = 0.0
	player.combo.aim_direction = Vector2.RIGHT
	player._throw_spear()
	var hostile := false
	for i in range(80):
		await frames(1)
		if is_instance_valid(player.thrown_knife) and player.thrown_knife.state == player.thrown_knife.State.HOSTILE:
			hostile = true
		if player.has_knife:
			break
	check(hostile and player.has_knife and player.current_health < 100, "devuelve el cuchillo: daña y vuelve a la mano (vida %d)" % player.current_health)
	shooter.queue_free()

	print("== Heavy aéreo")
	for mode in ["arco", "diagonal", "picado"]:
		await reset(Vector2(2250, -460))
		if mode != "arco":
			Input.action_press("move_down")
		if mode == "diagonal":
			Input.action_press("move_right")
		await frames(1)
		await tap("heavy_attack")
		await frames(8)
		print("    %s: vel %s" % [mode, player.velocity])
		var ok := false
		match mode:
			"arco":
				ok = player.velocity.x >= 1200.0
			"diagonal":
				ok = player.velocity.x > 800.0 and abs(player.velocity.x - player.velocity.y) < 1.0
			"picado":
				ok = player.velocity.x == 0.0 and player.velocity.y >= 1900.0
		check(ok, "trayectoria %s" % mode)
		release_all()
		await frames(40)

	print("== Guardianes")
	await reset(Vector2(7300, -5502))
	var spawner: Node = level.get_node("BossSpawner")
	spawner.forced_boss = 1
	spawner._spawn(1)
	await frames(4)
	var agile: Node2D = spawner.bosses[0]
	agile.throw_chance = 0.0
	agile.dagger_parry_chance = 0.0
	agile._face(player)
	agile._start(agile.State.THROW_WINDUP, agile.THROW_WINDUP_TIME)
	await frames(32)
	var dagger: Node2D = agile.thrown_dagger
	var hp: int = agile.current_health
	var roared := false
	for i in range(120):
		await frames(1)
		if not is_instance_valid(dagger):
			break
		if not roared and dagger.global_position.distance_to(player.global_position) < 110.0:
			Input.action_press("roar")
			roared = true
		if dagger.state == dagger.State.REFLECTED:
			break
	release_all()
	for i in range(90):
		await frames(1)
		if not is_instance_valid(dagger):
			break
	check(agile.current_health < hp and agile.state == agile.State.STAGGER, "la daga devuelta daña y aturde al ágil")
	# El reinicio de Rengar hace reaparecer al guardián: primero reiniciar, después configurarlo.
	spawner.forced_boss = 2
	await reset(Vector2(7300, -5502))
	var archer: Node2D = spawner.bosses[0]
	archer.shine_chance = 1.0
	# Quieto: si se reposiciona (backflip, teletransporte) la flecha devuelta podría no llegarle.
	archer.set_physics_process(false)
	var arrow: Area2D = load("res://projectile.gd").new()
	arrow.style = "arrow"
	arrow.velocity = Vector2(820, 0)
	arrow.shooter = archer
	level.add_child(arrow)
	arrow.global_position = player.global_position + Vector2(-90, -16)
	Input.action_press("roar")
	await frames(10)
	release_all()
	var shined := false
	for i in range(90):
		await frames(1)
		if is_instance_valid(arrow) and arrow.reflected == false and arrow.shine_level >= 2:
			shined = true
			break
	check(shined, "el arquero shinea la flecha de vuelta")

	print("== Partida")
	release_all()
	St.set_meta(&"defeated_bosses", [])
	change_scene_to_file("res://main.tscn")
	level.queue_free()
	level = null
	await frames(10)
	spawner = current_scene.get_node("BossSpawner")
	var first: String = spawner.bosses[0].boss_name
	for boss in spawner.bosses:
		boss.take_hit(Vector2.ZERO, 1, 9999)
		boss.ruby_core.claim(get_first_node_in_group(&"player"))
		boss.ruby_core.complete(get_first_node_in_group(&"player"))
	await frames(130)
	var demo: Node = get_first_node_in_group(&"demo_complete")
	check(demo.title_text == "ETAPA 1 COMPLETADA", "torre ganada")
	demo._next_stage()
	await frames(10)
	spawner = current_scene.get_node("BossSpawner")
	check(current_scene.scene_file_path == "res://stage2.tscn" and spawner.bosses[0].boss_name != first, "etapa 2 con otro guardián")
	paused = false
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
