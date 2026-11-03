extends SceneTree

# Sigilo del Gauntlet: visión larga y corta, investigar, descubrir, alarma (carga, pausa, baja, más rápida
# con dos, llena), evasión y precaución, ejecución por sorpresa, bushes e invisibilidad.
var checks := 0
var fails := 0
var director: Node
var stealth: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func clear_field(player_at: Vector2) -> void:
	director._clear_wave()
	stealth.begin_wave()
	player.position = player_at
	player.velocity = Vector2.ZERO
	await frames(3)

func chaser(at: Vector2, facing: int) -> Area2D:
	director._add_chaser(at)
	var enemy: Area2D = director.enemies[-1]
	await frames(3)
	var agent: Node = enemy.get_node("StealthAgent")
	agent.timer = 999.0
	agent._turn(facing)
	return enemy

func agent_of(enemy: Node) -> Node:
	return enemy.get_node("StealthAgent")

func execute(enemy: Area2D) -> void:
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	player.attack_targets_hit.clear()
	player._hit_area(enemy)
	for _i in range(90):
		await frames(1)
		if player.execution_core == null:
			break
	player.attack_mode = player.ATTACK_NONE

func _run() -> void:
	root.add_child(load("res://gauntlet.tscn").instantiate())
	await frames(10)
	director = get_first_node_in_group(&"gauntlet_director")
	stealth = get_first_node_in_group(&"stealth_director")
	player = get_first_node_in_group(&"player")
	var ground_y: float = 0.0

	print("== La oleada empieza sin margen y sin saber nada")
	director._start_wave()
	await frames(3)
	var unaware := true
	var graceful := true
	for enemy in director.enemies:
		unaware = unaware and enemy.ruby_core.ai_suspended and agent_of(enemy).mode == agent_of(enemy).Mode.UNAWARE
		graceful = graceful and enemy.ruby_core.spawn_grace_left == 0.0
	check(unaware, "todos empiezan con la IA dormida, sin saber nada")
	check(graceful, "ya no hay dos segundos de preparación")
	var bush_xs: Array = stealth.bushes.map(func(bush): return bush.position.x)
	check(bush_xs == [100.0, 4300.0], "solo dos bushes, en los bordes izquierdo y derecho (%s)" % [bush_xs])

	print("== Patrulla, visión larga, investigar")
	await clear_field(Vector2(2000, ground_y - 2))
	var guard := await chaser(Vector2(2500, ground_y), -1)
	var agent := agent_of(guard)
	agent.timer = 0.0
	var start_x: float = guard.global_position.x
	await frames(40)
	check(guard.global_position.x != start_x, "patrulla sin ver a Viridy")
	check(agent.mode == agent.Mode.UNAWARE, "lejos no nota nada")
	agent.timer = 999.0
	agent._turn(-1)
	player.position = Vector2(guard.global_position.x - 380.0, ground_y - 2)
	await frames(3)
	check(agent.mode == agent.Mode.SUSPICIOUS and agent.mark.text == "?", "en la visión larga se queda quieto con ?")
	var stopped_x: float = guard.global_position.x
	await frames(20)
	check(is_equal_approx(guard.global_position.x, stopped_x), "quieto, le llamó la atención")
	check(stealth.level == 0.0, "sospechar no carga la alarma")
	player.position = Vector2(guard.global_position.x - 600.0, ground_y - 2)
	await frames(70)
	check(agent.mode == agent.Mode.INVESTIGATE and guard.global_position.x < stopped_x, "luego va a investigar el punto")
	check(guard.ruby_core.is_executable(), "sin estar en alerta se le puede ejecutar")

	print("== Por la espalda no ve; un pesado lo ejecuta")
	await clear_field(Vector2(2000, ground_y - 2))
	guard = await chaser(Vector2(2500, ground_y), 1)
	agent = agent_of(guard)
	player.position = guard.global_position + Vector2(-90, -2)
	await frames(4)
	check(agent.mode == agent.Mode.UNAWARE, "por la espalda no la nota")
	check(guard.ruby_core.is_executable(), "ejecutable sin bajarle la vida")
	await execute(guard)
	check(guard.ruby_core.broken and not guard.visible, "un pesado lo ejecuta de un golpe")
	check(stealth.level == 0.0, "ejecutar en silencio no carga la alarma")

	print("== Visión corta: descubre y carga la alarma")
	await clear_field(Vector2(2000, ground_y - 2))
	guard = await chaser(Vector2(2500, ground_y), -1)
	agent = agent_of(guard)
	player.position = guard.global_position + Vector2(-150, -2)
	player.current_health = player.max_health
	await frames(3)
	check(agent.mode == agent.Mode.ENGAGED and agent.mark.text == "!", "en la visión corta la descubre con !")
	check(not guard.ruby_core.ai_suspended, "su IA normal despierta")
	check(not guard.ruby_core.is_executable(), "en alerta ya no se ejecuta de un golpe")
	await frames(30)
	var after_one: float = stealth.level
	check(after_one > 0.0, "la alarma se carga (%.2f)" % after_one)

	print("== Golpearlo pausa, matarlo baja")
	guard.take_hit(player.global_position, 1, 1)
	await frames(3)
	var paused_at: float = stealth.level
	await frames(40)
	check(is_equal_approx(stealth.level, paused_at), "golpearlo pausa la alarma (%.3f)" % stealth.level)
	await frames(60)
	check(stealth.level > paused_at, "si sigue vivo, vuelve a cargar")
	guard.take_hit(player.global_position, 1, 999)
	await frames(3)
	var dying_at: float = stealth.level
	await frames(30)
	check(stealth.level < dying_at, "muerto, la alarma baja (%.3f → %.3f)" % [dying_at, stealth.level])

	print("== Un segundo enemigo la carga más rápido")
	await clear_field(Vector2(2500, ground_y - 2))
	var first := await chaser(Vector2(2650, ground_y), -1)
	first.set_physics_process(false)
	agent_of(first)._discover()
	var before: float = stealth.level
	await frames(20)
	var solo_rate: float = stealth.level - before
	var second := await chaser(Vector2(2350, ground_y), 1)
	second.set_physics_process(false)
	agent_of(second)._discover()
	await frames(1)
	before = stealth.level
	await frames(20)
	var pair_rate: float = stealth.level - before
	check(pair_rate > solo_rate * 1.3, "con dos carga más rápido (%.3f > %.3f)" % [pair_rate, solo_rate])

	print("== Alarma llena: todos saben; huir la apaga; precaución")
	await clear_field(Vector2(2000, ground_y - 2))
	var near := await chaser(Vector2(2300, ground_y), -1)
	var far := await chaser(Vector2(3600, ground_y), 1)
	near.set_physics_process(false)
	far.set_physics_process(false)
	stealth.level = 0.999
	agent_of(near)._discover()
	await frames(4)
	check(stealth.alarm_active(), "llena salta la alarma")
	check(agent_of(far).is_aware(), "también lo sabe el que no la veía")
	check(not far.ruby_core.is_executable(), "durante la alarma nadie se ejecuta de un golpe")
	player.position = Vector2(900, ground_y - 2)
	var last: Vector2 = stealth.last_known
	await frames(10)
	check(last.distance_to(Vector2(2000, ground_y)) < 60.0, "recuerda la última posición")
	stealth.evasion_left = 0.05
	await frames(5)
	check(stealth.caution_active(), "sin verla, la alarma se apaga y queda precaución")
	check(is_instance_valid(stealth.last_known_mark), "queda la marca en su última posición")
	check(stealth.vision_scale() > 1.0, "en precaución ven más lejos")
	await frames(2)
	var spotter: Node = agent_of(near)
	spotter._discover()
	await frames(1)
	check(stealth.alarm_active(), "descubierta en precaución, alarma al instante")
	check(not is_instance_valid(stealth.last_known_mark) or stealth.last_known_mark.is_queued_for_deletion(), "la marca se borra al volver la alarma")

	print("== Bush: oculta, carga y conserva la invisibilidad")
	await clear_field(Vector2(1500, ground_y - 2))
	var bush: Node2D = stealth.bushes[0]
	player.position = bush.global_position + Vector2(0, -2)
	await frames(3)
	check(stealth.player_cloaked(), "dentro es invisible al instante")
	check(player.modulate.a < 0.5, "se ve translúcida")
	player.position = Vector2(1500, ground_y - 2)
	await frames(3)
	check(not stealth.player_cloaked(), "al salir antes de 2 s deja de serlo")
	player.position = bush.global_position + Vector2(0, -2)
	stealth.bush_time = 1.95
	await frames(8)
	check(stealth.bush_time >= 2.0, "2 s dentro la carga")
	player.position = Vector2(1500, ground_y - 2)
	await frames(3)
	check(stealth.player_cloaked() and stealth.cloak_left > 5.8, "al salir conserva 6 s (%.2f)" % stealth.cloak_left)
	check(player.modulate == stealth.CLOAK_TINT, "sigue translúcida")
	stealth.cloak_left = 0.02
	await frames(3)
	check(not stealth.player_cloaked() and player.modulate == Color.WHITE, "se acaba y vuelve a verse")

	print("== Invisible: no la ven y ejecuta a cualquiera; atacar la corta")
	await clear_field(Vector2(2000, ground_y - 2))
	guard = await chaser(Vector2(2500, ground_y), -1)
	agent = agent_of(guard)
	guard.set_physics_process(false)
	agent._discover()
	await frames(2)
	stealth.cloak_left = 6.0
	player.position = guard.global_position + Vector2(-90, -2)
	await frames(3)
	check(agent.mode == agent.Mode.HUNT, "descubierta, al volverse invisible la pierde de vista")
	check(not agent.seeing, "no la ve aunque esté delante")
	agent._discover()
	agent.lost_time = 0.0
	check(guard.ruby_core.is_executable(), "invisible ejecuta incluso a uno en alerta")
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	await frames(2)
	check(not stealth.player_cloaked(), "empezar un ataque corta la invisibilidad")
	check(stealth.strike_left > 0.0 and guard.ruby_core.is_executable(), "pero ese ataque aún ejecuta")
	await execute(guard)
	check(guard.ruby_core.broken, "ejecutado al instante")

	print("== Ataques en el bush y fin de la oleada")
	await clear_field(Vector2(1500, ground_y - 2))
	player.position = bush.global_position + Vector2(0, -2)
	await frames(3)
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	await frames(2)
	player.attack_mode = player.ATTACK_NONE
	check(not stealth.player_cloaked(), "atacar dentro del bush también la corta")
	# La embestida del pesado la saca del bush: vuelve a meterse.
	await frames(10)
	player.velocity = Vector2.ZERO
	player.position = bush.global_position + Vector2(0, -2)
	await frames(60)
	check(stealth.player_cloaked(), "al rato vuelve a ocultarse")
	stealth.stand_down()
	await frames(2)
	check(not stealth.player_cloaked() and player.modulate == Color.WHITE, "con el guardián se acaba el sigilo")

	print("== Aturdido no se mueve; los últimos voladores bajan")
	await clear_field(Vector2(1000, ground_y - 2))
	guard = await chaser(Vector2(2500, ground_y), -1)
	agent = agent_of(guard)
	agent.mode = agent.Mode.HUNT
	stealth.last_known = Vector2(3000, ground_y)
	var stun_x: float = guard.global_position.x
	guard.ruby_core.stagger(1.0)
	await frames(30)
	check(is_equal_approx(guard.global_position.x, stun_x), "aturdido, su agente no lo mueve")
	await frames(50)
	check(guard.global_position.x > stun_x, "al recuperarse sigue buscando")
	await clear_field(Vector2(2000, ground_y - 2))
	var flyer: Area2D = load("res://hawk.gd").new()
	flyer.position = Vector2(2400, -760)
	director._add_enemy(flyer)
	await frames(4)
	var flyer_y: float = flyer.global_position.y
	await frames(60)
	check(agent_of(flyer).mode == agent_of(flyer).Mode.HUNT and flyer.global_position.y > flyer_y + 40.0, "el último volador baja a buscarla")

	print("== El centinela dispara la alarma global")
	await clear_field(Vector2(2000, ground_y - 2))
	director._add_scripted(load("res://sentinel.gd"), Vector2(2300, ground_y))
	var sentinel: Area2D = director.enemies[-1]
	await frames(3)
	agent = agent_of(sentinel)
	agent.timer = 999.0
	agent._turn(-1)
	player.position = sentinel.global_position + Vector2(-150, -2)
	await frames(90)
	check(agent.mode == agent.Mode.ENGAGED, "el centinela la descubre")
	check(stealth.alarm_active(), "su alarma salta sin esperar a llenarse")

	print("== Oleada real con todos los tipos: patrulla y alarma")
	stealth.begin_wave()
	director.round_number = 6
	director._start_wave()
	player.position = Vector2(300, ground_y - 2)
	await frames(200)
	var kinds := {}
	for enemy in director.enemies:
		kinds[agent_of(enemy).mover] = true
	check(kinds.size() == 3, "hay enemigos que caminan, vuelan y están fijos")
	check(stealth.level == 0.0 and not stealth.alarm_active(), "lejos de todos no pasa nada")
	player.position = Vector2(2700, ground_y - 2)
	stealth.trigger_alarm()
	var siren_at: int = root.get_node("Sfx").last_played.get("alarm_siren", -1)
	player.current_health = player.max_health
	var moved := 0
	var start: Dictionary = {}
	for enemy in director.enemies:
		start[enemy] = enemy.global_position
	await frames(240)
	for enemy in director.enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(start[enemy]) > 20.0:
			moved += 1
	check(moved >= director.enemies.size() / 3, "en alarma van a por ella (%d/%d)" % [moved, director.enemies.size()])
	check(player.current_health < player.max_health or player.dead, "y la atacan (%d)" % player.current_health)
	check(siren_at >= 0 and root.get_node("Sfx").last_played.get("alarm_siren", -1) == siren_at, "la sirena suena una sola vez al saltar la alarma")

	print("== Morir apaga el sigilo")
	stealth.trigger_alarm()
	director._on_player_died()
	await frames(2)
	check(not stealth.running and not stealth.alarm_active(), "sin sirena en la pantalla final")

	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
