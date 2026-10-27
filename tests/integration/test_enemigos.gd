extends SceneTree

# Halcón (patrulla, avisa, espera y se lanza en picada), escudero (bloquea de frente, se gira despacio,
# guardia rota), tiradores voladores más rápidos, avisos agudos y oleadas del Gauntlet en las plataformas altas.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_enemigos.gd

var level: Node
var player: CharacterBody2D
var F: Node
var St: Node
var S: Node
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

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	await frames(5)

func _run() -> void:
	F = root.get_node("Ferocity")
	St = root.get_node("Stats")
	S = root.get_node("Sfx")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")
	# Sin los enemigos del nivel para que no molesten.
	for enemy in get_nodes_in_group(&"training_dummies"):
		enemy.remove_from_group(&"training_dummies")
		enemy.queue_free()
	for boss in get_nodes_in_group(&"boss"):
		boss.queue_free()

	print("== Avisos")
	for sound in ["boss_alert", "bow_draw", "hawk_screech", "hawk_dive", "guard_break"]:
		check(S.streams.has(sound) and S.MIX.has(sound), "sonido %s cargado y mezclado" % sound)

	print("== Halcón")
	await reset()
	var hawk: Area2D = load("res://hawk.gd").new()
	hawk.position = GROUND + Vector2(260, -520)
	level.add_child(hawk)
	await frames(2)
	var spotted := false
	for i in range(60):
		await frames(1)
		if hawk.state == hawk.State.WATCH:
			spotted = true
			break
	check(spotted and hawk.warning_label.visible, "ve a Viridy debajo y avisa con el \"!\"")
	check(S.last_played.has("hawk_screech"), "con el chillido agudo")
	var watch_frames := 0
	while hawk.state == hawk.State.WATCH and watch_frames < 400:
		await frames(1)
		watch_frames += 1
	check(watch_frames >= int(hawk.watch_time * 60.0 * 0.9), "espera unos segundos antes de lanzarse (%.2f s)" % (watch_frames / 60.0))
	check(hawk.state == hawk.State.DIVE, "y se lanza en picada")
	var health_before: int = player.current_health
	var lowest: float = hawk.global_position.y
	for i in range(90):
		await frames(1)
		lowest = max(lowest, hawk.global_position.y)
		if hawk.state == hawk.State.CLIMB:
			break
	check(player.current_health < health_before, "la picada le pega (%d -> %d)" % [health_before, player.current_health])
	check(lowest > GROUND.y - 60.0, "baja hasta Viridy (%.0f)" % lowest)
	for i in range(240):
		await frames(1)
		if hawk.state == hawk.State.PATROL:
			break
	check(hawk.state == hawk.State.PATROL and abs(hawk.global_position.y - hawk.home.y) < 30.0, "luego vuelve a subir y a patrullar")
	var x_before: float = hawk.global_position.x
	await frames(30)
	check(abs(hawk.global_position.x - x_before) > 40.0, "patrulla volando de lado a lado")
	await reset()
	player.invulnerability_timer = 0.0
	hawk.cooldown = 0.0
	for i in range(60):
		await frames(1)
		if hawk.state == hawk.State.WATCH:
			break
	hawk.take_hit(player.global_position, 1, 1)
	check(hawk.state == hawk.State.STAGGER, "golpearlo mientras avisa lo aturde")
	hawk.state = hawk.State.DIVE
	hawk.dive_direction = Vector2.DOWN
	hawk.on_deflected(player)
	check(hawk.state == hawk.State.STAGGER and hawk.dive_hit_done, "el rugido desvía la picada")
	hawk.take_hit(Vector2.ZERO, 1, 999)
	check(hawk.visible and hawk.ruby_core.dying, "entra en dying antes de explotar")
	hawk.reset_dummy()
	check(hawk.visible and hawk.current_health == hawk.max_health and hawk.state == hawk.State.PATROL, "y reaparece con reset_dummy")
	hawk.queue_free()

	print("== Escudero")
	await reset()
	var shield: Area2D = load("res://shield_bearer.gd").new()
	shield.position = GROUND + Vector2(60, 2)
	level.add_child(shield)
	await frames(3)
	shield.facing = -1
	shield.visual.scale.x = -1
	player.facing = 1
	var shield_health: int = shield.current_health
	await tap("attack")
	await frames(12)
	check(shield.current_health == shield_health, "un ligero de frente rebota en el escudo (%d)" % shield.current_health)
	check(shield.try_block(player.global_position), "bloquea lo que le llega por delante")
	check(not shield.try_block(shield.global_position + Vector2(80, 0)), "pero no por la espalda")
	shield.state = shield.State.RECOVER
	check(not shield.try_block(player.global_position), "ni con la guardia baja tras atacar")
	shield.state = shield.State.IDLE
	shield.take_hit(player.global_position, 1, 3)
	check(shield.state == shield.State.STAGGER and shield.state_timer > 1.0, "un golpe fuerte de frente le rompe la guardia")
	check(S.last_played.has("guard_break"), "con su sonido")
	check(shield.knock_velocity < 200.0 * 0.5, "y apenas lo mueve (acorazado: %.0f)" % shield.knock_velocity)
	await frames(80)
	# Viridy pasa a su espalda: tarda en girarse.
	player.global_position = shield.global_position + Vector2(120, -2)
	shield.state = shield.State.CHASE
	shield.facing = -1
	shield.visual.scale.x = -1
	await frames(15)
	check(shield.facing == -1, "a los 0,25 s sigue de espaldas")
	await frames(30)
	check(shield.facing == 1, "luego se gira")
	shield.take_hit(Vector2.ZERO, 1, 999)
	check(shield.ruby_core.dying and shield.visible, "entra en dying")
	shield.queue_free()

	print("== Tiradores voladores")
	var flyer: Node2D = load("res://training_dummy.tscn").instantiate()
	flyer.shoot_interval = 2.4
	flyer.aerial = true
	var walker: Node2D = load("res://training_dummy.tscn").instantiate()
	walker.shoot_interval = 2.4
	level.add_child(flyer)
	level.add_child(walker)
	await frames(2)
	check(is_equal_approx(flyer.projectile_speed, walker.projectile_speed * 2.0), "el proyectil volador va al doble (%.0f frente a %.0f)" % [flyer.projectile_speed, walker.projectile_speed])
	check(flyer.shoot_interval < walker.shoot_interval * 0.8, "y dispara más seguido (cada %.2f s)" % flyer.shoot_interval)
	flyer.queue_free()
	walker.queue_free()
	level.queue_free()
	await frames(5)

	print("== Gauntlet: oleadas en lo alto")
	var gauntlet: Node = load("res://gauntlet.tscn").instantiate()
	root.add_child(gauntlet)
	await frames(15)
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var summary := {}
	for round_number in [1, 2, 3, 5, 7]:
		director.round_number = round_number
		director._start_wave()
		await frames(20)
		var highest := 0.0
		var hawks := 0
		var shields := 0
		var upper_kinds := {}
		for enemy in director.enemies:
			var height: float = -enemy.global_position.y
			highest = max(highest, height)
			if enemy.get_script() == load("res://hawk.gd"):
				hawks += 1
			elif enemy.get_script() == load("res://shield_bearer.gd"):
				shields += 1
			elif height > 300.0:
				var kind: String = "volador" if enemy.get("aerial") else ("tirador" if enemy.get("shoot_interval") else "melee")
				upper_kinds[kind] = true
		summary[round_number] = [director.enemies.size(), hawks, shields, highest, upper_kinds.keys()]
		print("    ronda %d: %d enemigos, %d halcones, %d escuderos, el más alto a %.0f px, arriba: %s" % ([round_number] + summary[round_number]))
	check(summary[1][1] == 0 and summary[1][2] == 0 and summary[1][3] < 300.0, "ronda 1: solo en el suelo, sin halcones ni escuderos")
	check(summary[2][1] >= 1 and summary[2][2] >= 1, "ronda 2: aparecen halcones y escuderos")
	check(summary[3][4].size() >= 2, "ronda 3: enemigos en plataformas altas")
	check(summary[7][4].size() == 3, "en las grandes, de los tres tipos arriba (%s)" % [summary[7][4]])
	check(summary[7][3] > summary[3][3] + 200.0 and summary[7][0] > summary[3][0], "cada ronda más arriba y más enemigos")
	# Los de las plataformas se quedan en ellas (no caen al suelo).
	await frames(60)
	var standing := 0
	var upper := 0
	for enemy in director.enemies:
		if enemy.get_script() == load("res://chaser_dummy.gd") and enemy.spawn_position.y < -300.0:
			upper += 1
			if abs(enemy.global_position.y - enemy.spawn_position.y) < 6.0:
				standing += 1
	check(upper > 0 and standing == upper, "los cuerpo a cuerpo de arriba se quedan en su plataforma (%d de %d)" % [standing, upper])

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
