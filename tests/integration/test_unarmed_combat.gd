extends SceneTree

var checks := 0
var fails := 0
var level: Node2D
var player: CharacterBody2D
var F: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func release() -> void:
	for action in ["attack", "heavy_attack", "jump", "dash", "throw_knife", "roar", "move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)

func reset(at := Vector2(0, -2)) -> void:
	release()
	player._respawn_player()
	player.position = at
	player.facing = 1
	player._update_facing_visual()
	F.reset()
	await frames(6)

func enemy(at: Vector2, health := 100) -> Area2D:
	var target := load("res://training_dummy.tscn").instantiate() as Area2D
	target.position = at
	target.max_health = health
	target.shoot_interval = 0.0
	level.add_child(target)
	return target

func _run() -> void:
	F = root.get_node("Ferocity")
	level = Node2D.new()
	root.add_child(level)
	var floor := StaticBody2D.new()
	floor.collision_layer = 2
	floor.position = Vector2(0, 40)
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(8000, 80)
	floor.add_child(collision)
	level.add_child(floor)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	level.add_child(player)
	await frames(10)
	check(player.has_knife and player.get("weapons") == null and player.get("liquid_beast") == null, "Viridy empieza con la lanza jade, sin armas ni forma bestia")
	# Pulsaciones reales y buffer: cinco golpes, luego fin de cadena.
	var steps := []
	await tap("attack")
	for i in range(5):
		steps.append(player.combo.step)
		if i < 4:
			await tap("attack")
		var old: int = player.combo.step
		for _j in range(60):
			await frames(1)
			if not player.combo.active or player.combo.step != old:
				break
	check(steps == [0, 1, 2, 3, 4], "Ligero encadena 3 zarpazos + 2 patadas")
	check(not player.combo.active, "La cadena de cinco termina sin repetirse")
	# El pesado en el suelo es la embestida única, no un string.
	await reset()
	await tap("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND and player.velocity.x > player.max_speed, "Pesado en el suelo: embestida hacia delante")
	check(player.animated_sprite.animation == player.ANIMATION_GROUND_HEAVY and player.animated_sprite.sprite_frames.get_frame_texture(player.ANIMATION_GROUND_HEAVY, 0).atlas == player.LIQUID_BEAST_SHEET, "La embestida usa la cabeza de la bestia")
	# La embestida tiene 1 s de reutilización en el suelo.
	for _i in range(65):
		await frames(1)
	await tap("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND and not player.combo.active, "Repetir pesado vuelve a embestir, sin cadena de patadas")
	await reset(Vector2(0, -300))
	await tap("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY and player.animated_sprite.animation == player.ANIMATION_HEAVY_AERIAL, "Pesado aéreo: picada con la cabeza de la bestia")
	# Aire: sin golpear a nadie el combo no sostiene; conectando sí.
	await reset(Vector2(0, -400))
	await tap("attack")
	var air_y: float = player.position.y
	await tap("attack")
	await frames(15)
	check(player.position.y - air_y > 35.0, "Sin golpear a nadie, el combo ligero aéreo no sostiene")
	for i in range(8):
		await tap("attack")
		await frames(6)
	check(player.is_on_floor() or player.position.y > air_y + 200.0, "Repetir ligeros en el vacío no permite volar")
	await reset(Vector2(0, -400))
	var aerial = enemy(player.position + Vector2(55, 0), 40)
	aerial.set_physics_process(false)
	await frames(2)
	await tap("attack")
	await frames(8)
	air_y = player.position.y
	await tap("attack")
	await frames(15)
	check(player.combo.air_stall and player.position.y - air_y < 35.0 and not player.is_on_floor(), "Tras conectar en el aire, el combo ligero mantiene aerial stall")
	aerial.queue_free()
	# Aim (LT) + RT lanza la lanza; un toque de LT con la lanza clavada la recupera.
	await reset()
	# Mando sin stick derecho: apunta hacia donde mira Viridy.
	var hints: Node = root.get_node("InputHints")
	hints.device = hints.Device.JOYPAD
	Input.action_press("throw_knife")
	Input.action_press("move_right")
	await frames(10)
	check(player.combo.aim and player.has_knife and not player.is_sprinting and absf(player.velocity.x) <= player.max_speed, "Mantener Aim permite caminar, impide correr y no lanza solo")
	await tap("dash")
	check(not player.has_knife and is_instance_valid(player.thrown_knife) and player.dash_timer <= 0.0, "Aim + RT lanza la lanza sin hacer dash")
	release()
	await frames(2)
	await tap("attack")
	check(player.combo.active, "Sin la lanza se sigue atacando")
	player._cancel_all_states()
	await tap("throw_knife")
	check(is_instance_valid(player.thrown_knife) and not player.thrown_knife.is_returning(), "Con la lanza aún en vuelo, LT no la recupera")
	for _i in range(90):
		await frames(1)
		if player.thrown_knife.state == player.thrown_knife.State.STUCK_WORLD:
			break
	check(player.thrown_knife.state == player.thrown_knife.State.STUCK_WORLD, "La lanza se clava en el terreno")
	Input.action_press("throw_knife")
	await frames(2)
	check(player.thrown_knife.is_returning() and not player.combo.aim, "Un toque de LT con la lanza clavada la recupera, sin abrir Aim")
	for _i in range(90):
		await frames(1)
		if player.has_knife:
			break
	await frames(2)
	check(player.has_knife and not player.combo.aim, "Recuperada, mantener LT no reabre Aim hasta volver a pulsarlo")
	release()
	await frames(2)
	# Estados del rubí y ejecución por pesado.
	await reset()
	var target := enemy(Vector2(70, -2), 10)
	await frames(2)
	target.take_hit(Vector2.ZERO, 1, 8)
	check(not target.ruby_core.is_open(), "Poca vida no equivale a OPEN")
	target.ruby_core.register_parry()
	check(target.ruby_core.is_open() and not target.ruby_core.dying, "Parry produce OPEN independiente de la vida")
	await frames(125)
	check(not target.ruby_core.is_open() and target.visible, "OPEN expira a los dos segundos; enemigo sigue vivo")
	target.take_hit(Vector2.ZERO, 1, 20)
	check(target.ruby_core.dying and target.visible and not target.ruby_core.is_open(), "A cero entra en DYING, visible y ejecutable")
	await frames(180)
	check(target.visible and target.ruby_core.dying, "DYING permanece tres segundos")
	await frames(65)
	check(not target.visible and target.ruby_core.broken, "A los cuatro segundos el ruby explota")
	target.queue_free()
	await reset()
	target = enemy(Vector2(90, -2), 100)
	target.set_physics_process(false)
	await frames(2)
	target.ruby_core.register_parry()
	await tap("heavy_attack")
	var captured: bool = player.execution_core != null
	for _i in range(60):
		await frames(1)
		captured = captured or player.execution_core != null
		if target.ruby_core.broken:
			break
	check(captured and target.ruby_core.broken and not target.visible, "Parry + pesado de Viridy ejecuta un OPEN con vida llena")
	target.queue_free()
	# El pesado que deja a cero no ejecuta en el mismo impacto: primero DYING, luego otro pesado.
	await reset()
	target = enemy(Vector2(90, -2), 3)
	target.set_physics_process(false)
	await frames(2)
	await tap("heavy_attack")
	await frames(2)
	check(target.ruby_core.dying and player.execution_core == null, "El pesado que lo deja a cero lo pone en DYING sin ejecutarlo")
	for _i in range(40):
		await frames(1)
	player.position = Vector2(0, -2)
	player.facing = 1
	player._update_facing_visual()
	player.ground_heavy_cooldown_timer = 0.0
	player.attack_cooldown_timer = 0.0
	await frames(1)
	await tap("heavy_attack")
	captured = false
	for _i in range(60):
		await frames(1)
		captured = captured or player.execution_core != null
		if target.ruby_core.broken:
			break
	check(captured and target.ruby_core.broken, "El siguiente pesado ejecuta al enemigo en DYING")
	target.queue_free()
	release()
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
