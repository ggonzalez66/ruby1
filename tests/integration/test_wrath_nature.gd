extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D

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

func block(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	arena.add_child(body)
	return body

func dummy(at: Vector2) -> Node2D:
	var target: Node2D = load("res://training_dummy.tscn").instantiate()
	target.max_health = 100
	target.position = at
	arena.add_child(target)
	return target

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	block(Vector2(0, 50), Vector2(30000, 100))
	block(Vector2(500, -250), Vector2(20, 500))
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(6)
	var style: Node = root.get_node("Ferocity")
	var wrath: Node2D = player.wrath
	var sound: Node = root.get_node("Sfx")
	print("== Carga, agacharse y ventana de cuatro segundos")
	Input.action_press("move_down")
	await frames(65)
	check(wrath.state == wrath.State.IDLE and player.animated_sprite.animation == player.ANIMATION_CROUCH, "sin SSS solo se agacha, sin consumir estilo")
	var collider: CollisionShape2D = player.get_node("CollisionShape2D")
	check(collider.shape.size == Vector2(20, 28), "agacharse no altera las colisiones ni los inputs existentes")
	style._set_points(650)
	await frames(20)
	check(sound.is_looping("wrath_charge"), "la carga mantiene su sonido de energía")
	Input.action_release("move_down")
	await frames(2)
	check(wrath.state == wrath.State.IDLE and style.points > 600, "soltar antes del segundo cancela sin gastar SSS")
	await frames(8)
	check(not sound.is_looping("wrath_charge"), "cancelar la carga apaga su bucle sin dejar audio colgado")
	Input.action_press("move_down")
	await frames(64)
	Input.action_release("move_down")
	check(wrath.is_ready() and style.points == 0 and style.special_name == "Wrath of Nature", "un segundo consume todo SSS y cambia el indicador")
	check(sound.last_played.has("wrath_ready"), "completar la carga tiene su confirmación sonora")
	check(wrath.ready_left > 3.8, "la ventana de cuatro segundos empieza después de cargar")
	await frames(8)
	check(not sound.is_looping("wrath_charge"), "completar la carga también apaga su bucle")
	player.current_health = 100
	player.invulnerability_timer = 0.0
	player.velocity.x = 240
	player.take_damage(10, player.position + Vector2(-20, 0))
	check(player.current_health == 90 and player.hurt_lock_timer == 0 and player.velocity.x == 240, "preparado: recibe daño sin interrumpirse ni perder el impulso")
	player.velocity = Vector2.ZERO
	var shot: Area2D = load("res://projectile.gd").new()
	shot.position = player.position + Vector2(15, -14)
	arena.add_child(shot)
	await frames(3)
	check(not is_instance_valid(shot), "el aura destruye proyectiles durante la preparación")
	wrath.tick(4.1)
	check(wrath.state == wrath.State.IDLE and style.points == 0 and style.special_name == "", "caducar consume la preparación sin recuperar ferocidad")

	print("== Captura en stasis y rotura conjunta contra pared")
	player._respawn_player()
	player.liquid_beast = true
	player.current_health = 40
	var first := dummy(Vector2(120, -2))
	var second := dummy(Vector2(250, -2))
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(350, -2)
	arena.add_child(boss)
	boss.set_physics_process(false)
	await frames(3)
	style._set_points(650)
	wrath.arm()
	check(wrath.launch(Vector2.RIGHT), "heavy con dirección inicia la ultimate")
	check(sound.is_looping("wrath_rush"), "el avance mantiene un sonido continuo")
	for i in range(90):
		await frames(1)
		if wrath.state != wrath.State.RUSH:
			break
	check(wrath.state == wrath.State.RECOIL and player.position.x < 490, "el avance se detiene en la pared")
	check(sound.last_played.has("wrath_hit"), "capturar enemigos dispara el sonido propio de impacto")
	check(arena.get_node_or_null("JadeFireBurst") != null, "chocar con terreno crea una explosión de fuego jade")
	check(wrath.captured.size() == 3 and first.ruby_core.stolen and second.ruby_core.stolen and boss.ruby_core.stolen, "atraviesa normales y jefe con vida y toma sus tres Rubies")
	check(first.current_health == 100 and boss.current_health == 100 and first.process_mode == Node.PROCESS_MODE_DISABLED, "siguen vivos en stasis hasta romper sus Rubies")
	player.take_damage(999, player.position)
	var stopped := player.position
	player.return_to_checkpoint(50)
	check(not player.dead and player.current_health == 40 and player.position == stopped, "avance y ejecución son invulnerables, también ante pinchos")
	await frames(4)
	check(player.position.x < stopped.x, "al chocar retrocede un poco antes de romperlos")
	await frames(5)
	check(not sound.is_looping("wrath_rush"), "el sonido continuo se apaga al detenerse")
	for i in range(90):
		await frames(1)
		if wrath.state == wrath.State.IDLE:
			break
	check(first.current_health == 0 and second.current_health == 0 and boss.is_defeated(), "al fragmentar los Rubies mueren juntos, incluido el jefe")
	check(player.current_health > 40 and style.points == 0, "absorbe su energía y termina con ferocidad cero")
	check(player.animated_sprite.animation not in [player.ANIMATION_WRATH_RUSH, player.ANIMATION_WRATH_CHEW] and player.animated_sprite.self_modulate.a == 1.0, "la recuperación devuelve a Viridy normal")
	check(sound.last_played.has("wrath_launch") and sound.last_played.has("wrath_impact") and sound.last_played.has("wrath_shatter"), "salida, choque y rotura tienen sonidos propios")

	print("== Ocho direcciones, límites y cancelación segura")
	player.set_physics_process(false)
	for axis in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
		player.position = Vector2(2000, -300)
		style._set_points(650)
		wrath.arm()
		wrath.launch(axis)
		wrath.tick(0.02)
		check(wrath.direction.is_equal_approx(axis.normalized()) and player.velocity.normalized().is_equal_approx(axis.normalized()), "trayectoria recta %s" % axis)
		wrath.cancel()
	player.position = Vector2(2000, -300)
	style._set_points(650)
	wrath.arm()
	wrath.max_distance = 120
	wrath.launch(Vector2.RIGHT)
	wrath.tick(0.5)
	check(wrath.state == wrath.State.RECOIL and wrath.distance <= 120.1, "el límite de distancia evita una carga infinita sin terreno")
	wrath.cancel()
	wrath.max_distance = 4800
	var held := dummy(Vector2(2150, -300))
	style._set_points(650)
	wrath.arm()
	wrath.launch(Vector2.RIGHT)
	wrath._capture_segment(Vector2(2000, -314), Vector2(2200, -314))
	check(held.ruby_core.stolen, "puede tomar un núcleo en pleno aire")
	wrath.cancel()
	check(not held.ruby_core.locked and not held.ruby_core.stolen and held.process_mode != Node.PROCESS_MODE_DISABLED and held.current_health == 100, "cancelar libera la stasis y no deja enemigos bloqueados")
	block(Vector2(4000, -500), Vector2(600, 20))
	for axis in [Vector2.UP, Vector2.DOWN]:
		player.position = Vector2(4000, -250)
		style._set_points(650)
		wrath.arm()
		wrath.launch(axis)
		for tick in range(20):
			wrath.tick(0.03)
			if wrath.state == wrath.State.RECOIL:
				break
		check(wrath.state == wrath.State.RECOIL and wrath.recoil.dot(axis) < 0, "suelo/techo detiene la carga %s y rebota hacia atrás" % axis)
		wrath.cancel()
	player.position = Vector2(6000, -250)
	style._set_points(650)
	wrath.arm()
	wrath.max_distance = 20000
	wrath.max_rush_duration = 0.05
	wrath.launch(Vector2.RIGHT)
	wrath.tick(0.06)
	check(wrath.state == wrath.State.RECOIL, "el límite de tiempo también detiene el ataque sin colisión")
	wrath.cancel()
	wrath.max_distance = 4800
	wrath.max_rush_duration = 3.0
	print("== Heavy en pleno avance frena y ejecuta ahí")
	player.liquid_beast = true
	player.position = Vector2(8000, -2)
	var caught := dummy(Vector2(8150, -2))
	caught.set_physics_process(false)
	await frames(2)
	style._set_points(650)
	wrath.arm()
	wrath.launch(Vector2.RIGHT)
	for i in range(30):
		wrath.tick(1.0 / 60.0)
		if not wrath.captured.is_empty():
			break
	var braked_at := player.position.x
	Input.action_press("heavy_attack")
	wrath.tick(1.0 / 60.0)
	Input.action_release("heavy_attack")
	check(wrath.state == wrath.State.RECOIL and wrath.recoil.dot(Vector2.RIGHT) > 0.0, "heavy durante el avance frena deslizando hacia delante")
	for i in range(60):
		wrath.tick(1.0 / 60.0)
		if wrath.state == wrath.State.IDLE:
			break
	check(caught.current_health == 0 and caught.ruby_core.broken and player.position.x < braked_at + 60.0, "frena ahí mismo y ejecuta los Rubies capturados")
	await frames(6)
	check(not sound.is_looping("wrath_rush"), "frenar apaga el sonido del avance")
	print("== Desde el suelo no se apunta hacia abajo ni hacia atrás; en el aire sí")
	var directions := {"move_right": Vector2.RIGHT, "move_left": Vector2.LEFT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}
	for entry in [[Vector2(1, 1), false], [Vector2.DOWN, false], [Vector2(-1, 1), false], [Vector2.LEFT, false], [Vector2(1, -1), true], [Vector2.UP, true], [Vector2(-1, -1), true], [Vector2.DOWN, true, true]]:
		player.position = Vector2(9000, -2)
		player.facing = 1
		style._set_points(650)
		wrath.arm()
		wrath.begin_aim()
		wrath.landed = entry.size() < 3
		for action in directions:
			var axis: Vector2 = directions[action]
			if axis.dot(entry[0]) > 0.5:
				Input.action_press(action)
		wrath.tick(0.01)
		for action in directions:
			Input.action_release(action)
		var taken: bool = wrath.direction.is_equal_approx(entry[0].normalized())
		check(taken == entry[1], "%s %s: %s" % ["aire" if entry.size() >= 3 else "suelo", entry[0], "permitido" if entry[1] else "bloqueado"])
		wrath.cancel()
	player.position = Vector2(6000, -300)
	player.set_physics_process(true)
	style._set_points(650)
	wrath.arm()
	Input.action_press("move_up")
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("move_up")
	Input.action_release("heavy_attack")
	check(wrath.state == wrath.State.AIM and player.attack_mode == player.ATTACK_NONE, "heavy abre la selección y no activa un uppercut")
	check(sound.last_played.has("wrath_aim"), "la ventana de dirección tiene anticipación sonora")
	await frames(33)
	check(wrath.state == wrath.State.RUSH and wrath.direction == Vector2.UP, "conserva la dirección elegida aunque se suelte antes de salir")
	wrath.cancel()

	print("== Heavy solo, dirección tardía y facing por defecto")
	for facing_direction in [-1, 1]:
		player.position = Vector2(6000, -300)
		player.facing = facing_direction
		style._set_points(650)
		wrath.arm()
		Input.action_press("heavy_attack")
		await frames(2)
		Input.action_release("heavy_attack")
		var held_position := player.position
		check(wrath.state == wrath.State.AIM and wrath.invulnerable(), "heavy prepara la salida con invulnerabilidad")
		player.invulnerability_timer = 0.0
		player.current_health = 100
		player.take_damage(10, player.position + Vector2(-20, 0))
		check(player.current_health == 100 and player.hurt_lock_timer == 0 and wrath.state == wrath.State.AIM, "durante selección no recibe daño")
		await frames(6)
		check(wrath.state == wrath.State.AIM and player.position == held_position, "la anticipación mantiene el lugar sin lanzar prematuramente")
		await frames(12)
		check(wrath.state == wrath.State.AIM, "la selección sigue abierta después de los antiguos 0,25 segundos")
		await frames(14)
		check(wrath.state == wrath.State.RUSH and wrath.direction == Vector2(facing_direction, 0), "sin dirección lanza hacia facing %d" % facing_direction)
		wrath.cancel()

	player.position = Vector2(6000, -300)
	style._set_points(650)
	wrath.arm()
	wrath.ready_left = 0.02
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	check(wrath.state == wrath.State.AIM, "confirmar al final de READY reserva toda la ventana de dirección")
	Input.action_press("move_left")
	Input.action_press("move_up")
	await frames(5)
	Input.action_release("move_left")
	Input.action_press("move_right")
	await frames(3)
	Input.action_release("move_right")
	Input.action_release("move_up")
	await frames(24)
	check(wrath.state == wrath.State.RUSH and wrath.direction.is_equal_approx(Vector2(1, -1).normalized()), "elige y corrige una diagonal después del heavy, sin segundo botón")
	Input.action_press("move_down")
	await frames(2)
	Input.action_release("move_down")
	check(wrath.direction.is_equal_approx(Vector2(1, -1).normalized()), "la dirección deja de cambiar al comenzar el avance")
	wrath.cancel()
	style._set_points(650)
	wrath.arm()
	wrath.begin_aim()
	wrath.cancel()
	await frames(2)
	check(not wrath.controls_movement() and not style.style_locked and player.animated_sprite.animation != player.ANIMATION_CROUCH, "reiniciar durante selección libera el control y la pose")
	player.set_physics_process(false)
	player.position = Vector2(2000, -300)
	var packed_a := dummy(Vector2(2010, -300))
	var packed_b := dummy(Vector2(2018, -300))
	await frames(2)
	style._set_points(650)
	wrath.arm()
	wrath.launch(Vector2.RIGHT)
	wrath._capture_segment(Vector2(1990, -328), Vector2(2030, -328))
	var impact_voices: Array = sound.players.filter(func(voice): return voice.playing and voice.stream == sound.streams["wrath_hit"])
	check(packed_a.ruby_core.stolen and packed_b.ruby_core.stolen and impact_voices.size() >= 2, "dos enemigos en el mismo tick producen dos impactos sonoros")
	wrath.cancel()
	await frames(8)
	check(not sound.is_looping("wrath_rush"), "cancelar Wrath detiene el audio del avance")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
