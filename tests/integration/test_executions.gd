extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D
var style: Node
var stats: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func make_enemy(kind: String, at: Vector2, health: int = -1) -> Node2D:
	var enemy: Node2D
	if kind == "training_dummy":
		enemy = load("res://training_dummy.tscn").instantiate()
	else:
		enemy = Area2D.new()
		enemy.set_script(load("res://%s.gd" % kind))
	if health > 0:
		enemy.max_health = health
	enemy.position = at
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func clean() -> void:
	Input.action_release("heavy_attack")
	Input.action_release("dash")
	Input.action_release("move_down")
	for enemy in get_nodes_in_group(&"ruby_enemies"):
		enemy.queue_free()
	await frames(3)
	player._respawn_player()
	style.reset()
	await frames(4)

func hit(enemy: Node2D, mode: int) -> void:
	player.attack_mode = mode
	player.attack_timer = 1.0
	player.attack_targets_hit.clear()
	player._hit_area(enemy)

func wait_execution() -> void:
	for tick in range(120):
		await frames(1)
		if player.execution_core == null:
			return
	check(false, "la ejecución debe terminar")

func _run() -> void:
	style = root.get_node("Ferocity")
	stats = root.get_node("Stats")
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12000, 100)
	collision.shape = rectangle
	collision.position.y = 50
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(6)

	print("== Rombos interiores y apertura de normales")
	for kind in ["training_dummy", "chaser_dummy", "shield_bearer", "hawk", "boss_heavy", "boss_agile", "boss_archer"]:
		var enemy := make_enemy(kind, Vector2(800, 0))
		check(enemy.ruby_core != null and enemy.ruby_core.position == enemy.impact_offset, "%s tiene Ruby dentro del cuerpo" % kind)
		check(not enemy.ruby_core.is_open(), "núcleo sano cerrado")
	await clean()
	var chaser := make_enemy("chaser_dummy", Vector2(400, 0))
	chaser.state = chaser.State.SWING
	chaser.on_deflected(player)
	chaser.set_physics_process(true)
	var frozen := chaser.position
	await frames(60)
	check(chaser.ruby_core.is_open() and chaser.position == frozen, "parry normal inmoviliza y abre")
	await frames(65)
	check(not chaser.ruby_core.is_open(), "la apertura del parry termina tras dos segundos")
	chaser.set_physics_process(false)
	chaser.current_health = 2
	chaser.state = chaser.State.CHASE
	chaser.position = Vector2(400, 0)
	chaser.set_physics_process(true)
	await frames(12)
	check(chaser.ruby_core.is_open() and chaser.position.x < 400, "poca vida abre sin inmovilizar al enemigo")
	await clean()

	print("== Heavy necesita apertura previa; daño ordinario sigue matando")
	var victim := make_enemy("chaser_dummy", Vector2(70, 0))
	victim.current_health = 4
	hit(victim, player.ATTACK_HEAVY_GROUND)
	check(victim.current_health == 1 and victim.ruby_core.is_open() and player.execution_core == null, "el heavy que deja poca vida NO ejecuta en ese mismo impacto")
	player._cancel_attack_for_chain()
	player.current_health = 40
	var neighbor := make_enemy("chaser_dummy", Vector2(150, 0))
	style._set_points(500.0)
	player.riposte_attack = true
	player._start_sprint(1)
	player.velocity.x = 860.0
	player.bunnyhop_bonus = 180.0
	hit(victim, player.ATTACK_HEAVY_GROUND)
	check(player.execution_core == victim.ruby_core and victim.current_health == 1, "el siguiente heavy reclama el Ruby antes del daño")
	player.take_damage(99, Vector2.ZERO)
	check(player.current_health == 40, "Viridy es invulnerable durante la ejecución")
	await frames(2)
	check(player.animated_sprite.animation == player.ANIMATION_ROAR, "placeholder terrestre usa el rugido")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	await wait_execution()
	check(not victim.visible and victim.ruby_core.broken and player.current_health == 52, "rompe Ruby, mata y cura una sola vez")
	check(neighbor.current_health == neighbor.max_health - 1 and neighbor.knock_velocity > 250, "explosión daña poco y empuja hacia fuera")
	check(not paused, "la ejecución no pausa el mundo")
	check(player.is_sprinting and player.velocity.x >= 860.0, "la ejecución terrestre devuelve la velocidad de carrera")
	await frames(2)
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND, "un heavy pulsado durante la ejecución puede salir inmediatamente después")
	await clean()
	victim = make_enemy("chaser_dummy", Vector2(70, 0))
	victim.take_hit(Vector2.ZERO, 1, 999)
	check(not victim.visible and player.execution_core == null, "un golpe ordinario letal puede matar sin ejecutar")
	await clean()

	print("== Ejecución aérea real y último rebote del volador")
	victim = make_enemy("training_dummy", Vector2(220, -130), 20)
	victim.aerial = true
	victim.current_health = 2
	player.position = Vector2(200, -280)
	await frames(2)
	player._start_sprint(1)
	player.bunnyhop_bonus = 180.0
	Input.action_press("move_down")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	var captured := false
	for tick in range(100):
		await frames(1)
		if player.execution_core != null:
			captured = true
			break
	check(captured, "heavy aéreo conecta físicamente y captura un enemigo open")
	if captured:
		await frames(4)
		check(player.global_position.distance_to(victim.ruby_core.global_position) < 65 and player.velocity == Vector2.ZERO, "se detiene junto al núcleo en lugar de seguir cayendo")
		check(player.animated_sprite.animation == player.ANIMATION_FRONTFLIP and absf(player.animated_sprite.rotation) > 0.0, "flip en el sitio durante la captura")
		await wait_execution()
		check(not victim.visible and player.velocity.y < 0 and player.air_jumps_remaining == player.max_air_jumps, "el volador muere y entrega el último rebote y salto aéreo")
		check(player.is_sprinting and player.velocity.x >= 860 and player.bunnyhop_bonus >= 180, "conserva carrera y velocidad acumulada")
	await clean()

	print("== Postura determinista, crítico y remate de los tres jefes")
	for kind in ["boss_heavy", "boss_agile", "boss_archer"]:
		var boss := make_enemy(kind, Vector2(90, 0), 100)
		boss.ruby_core.register_parry(10)
		var first: float = boss.ruby_core.posture
		boss.ruby_core.register_parry(10)
		check(is_equal_approx(first, boss.ruby_core.posture), "%s: un mismo ataque no daña dos veces la postura" % kind)
		boss.ruby_core.register_parry(11)
		boss.ruby_core.register_parry(10)
		check(not boss.ruby_core.is_open(), "dos parries no bastan")
		boss.ruby_core.register_parry(12)
		check(boss.ruby_core.is_open() and boss.ruby_core.posture <= 0.01, "tercer parry rompe postura y abre la ventana")
		player.current_health = 40
		hit(boss, player.ATTACK_HEAVY_GROUND)
		await wait_execution()
		check(boss.current_health == 78 and not boss.is_defeated() and not boss.ruby_core.broken and boss.ruby_core.cracks == 1, "crítico daña mucho, agrieta y deja el cristal intacto")
		check(player.current_health == 48 and boss.ruby_core.posture == 100.0, "absorbe esencia y restablece postura")
		boss.ruby_core.register_parry(20)
		boss.ruby_core.register_parry(21)
		boss.ruby_core.register_parry(22)
		await frames(155)
		check(not boss.ruby_core.is_open() and boss.ruby_core.posture == 100.0, "perder la ventana también restablece postura")
		boss.current_health = 10
		boss.ruby_core.register_parry(30)
		boss.ruby_core.register_parry(31)
		boss.ruby_core.register_parry(32)
		hit(boss, player.ATTACK_HEAVY_GROUND)
		await wait_execution()
		check(boss.current_health == 0 and boss.ruby_core.final_open and not boss.is_defeated(), "un crítico a cero exige otro heavy")
		hit(boss, player.ATTACK_SLASH)
		check(not boss.is_defeated(), "un ligero no remata al jefe a cero")
		hit(boss, player.ATTACK_HEAVY_GROUND)
		await wait_execution()
		check(boss.is_defeated() and boss.ruby_core.broken, "otro heavy rompe el cristal y derrota definitivamente")
		boss.reset_dummy()
		check(not boss.ruby_core.final_open and not boss.ruby_core.broken and boss.ruby_core.posture == 100.0 and boss.current_health == 100, "reiniciar limpia núcleo, vida y postura")
		await clean()

	print("== Cancelación y parries de proyectiles")
	victim = make_enemy("training_dummy", Vector2(70, 0), 20)
	victim.current_health = 2
	hit(victim, player.ATTACK_HEAVY_GROUND)
	await frames(2)
	victim.reset_dummy()
	await frames(3)
	check(player.execution_core == null and victim.current_health == 20, "reset durante captura libera a Viridy sin premio ni daño diferido")
	await clean()
	var archer := make_enemy("boss_archer", Vector2(400, 0), 100)
	player.roar_active = true
	player.roar_explosive_timer = 10.0
	for i in range(3):
		var arrow: Area2D = load("res://projectile.gd").new()
		arrow.shooter = archer
		arrow.parry_token = 100 + i
		arrow.velocity = Vector2.LEFT * 400
		arena.add_child(arrow)
		arrow._reflect(player)
		arrow.queue_free()
	check(archer.ruby_core.is_open(), "tres devoluciones perfectas de ataques distintos abren al arquero")
	await clean()
	var sun: Node2D = load("res://sun_enemy.tscn").instantiate()
	arena.add_child(sun)
	check(not sun.has_node("RubyCore"), "el sol conserva su comportamiento especial")
	player.current_health = 40
	player.on_riposte_knife_pulled()
	check(player.current_health == 40, "el riposte ya no cura por recuperar el cuchillo")
	arena.queue_free()
	await frames(4)
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
