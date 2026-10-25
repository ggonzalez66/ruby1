extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D
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
	for action in ["jump", "dash", "move_left", "move_right", "move_up", "move_down", "attack", "heavy_attack", "roar"]:
		Input.action_release(action)

func reset_player() -> void:
	release_all()
	player._cancel_all_states()
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.attack_cooldown_timer = 0.0
	player.ground_heavy_cooldown_timer = 0.0
	player.dash_cooldown_timer = 0.0
	player.facing = 1
	await frames(4)

func _run() -> void:
	style = root.get_node("Ferocity")
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.position = Vector2(0, 50)
	floor_body.size = Vector2(30000, 100)
	floor_body.collision_layer = 2
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position.y = -2
	arena.add_child(player)
	await frames(6)

	print("== Velocidad y estilo gradual")
	check(style.speed_bonus_rate(320, 560) == 0 and style.speed_bonus_rate(560, 560) == 0, "caminar y carrera base no conceden el bonus extra")
	var low: float = style.speed_bonus_rate(680, 560)
	var high: float = style.speed_bonus_rate(1240, 560)
	check(low > 0 and high > low and style.speed_bonus_rate(10000, 560) == 24, "el bonus crece con velocidad y tiene techo")
	style.reset()
	style._set_points(99)
	style.add_speed(1.0, 1240, 560)
	check(style.rank == 1 and style.points > 100, "la alta velocidad permite progresar gradualmente de rango")
	style._set_points(498)
	style.add_speed(10.0, 3000, 560)
	check(style.rank == 4 and style.points < 500, "la velocidad sola no alcanza SS")
	var meter: PanelContainer = load("res://speed_hud.gd").new()
	arena.add_child(meter)
	player.velocity = Vector2(-1240, 300)
	meter._update_reading()
	check(meter.displayed_speed == 1240 and meter.value_label.text == "140 km/h" and meter.bonus_label.text == "+", "el medidor muestra velocidad real y bonus en ambos sentidos")
	player.velocity = Vector2(0, 1400)
	meter._update_reading()
	check(meter.displayed_speed == 0 and meter.bonus_label.text == "", "la caída vertical no se cuenta como velocidad de carrera")

	print("== Uppercut original, flip normal, stall")
	await reset_player()
	player._start_uppercut_attack(false)
	var saw_rise := false
	var saw_flip := false
	var saw_stall := false
	var flip_started_rising := false
	var stall_falling := false
	for i in range(90):
		await frames(1)
		saw_rise = saw_rise or (not player._is_attack_active() and player.animated_sprite.animation == &"uppercut" and player.velocity.y < 0)
		saw_flip = saw_flip or player.animated_sprite.animation == &"frontflip"
		flip_started_rising = flip_started_rising or (player.execution_air_exit == player.ExecutionAirExit.UPPERCUT_FLIP and player.velocity.y < -20.0)
		if player.animated_sprite.animation == &"aerial_stall":
			saw_stall = true
			stall_falling = player.velocity.y > 0
			break
	check(saw_rise and saw_flip and saw_stall and flip_started_rising and stall_falling, "sube en pose de uppercut, empieza el flip antes del ápice y entra cayendo en stall")

	print("== Screw: lanzamiento y bunnyhop")
	await reset_player()
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(20)
	player.attack_mode = player.ATTACK_GROUND_CHARGED
	player.velocity.x = player.charged_ground_lunge_speed
	player._start_spin_attack()
	var launch_speed: float = player.velocity.x
	check(launch_speed >= player.spin_launch_speed and launch_speed > player.charged_ground_lunge_speed, "el screw gana velocidad desde el inicio")
	player._effect_spin()
	var stroke: Line2D = player.effect_strokes[0][1]
	var min_radius := INF
	var max_radius := 0.0
	for point in stroke.points:
		var radius: float = (point - Vector2(0, 2)).length()
		min_radius = minf(min_radius, radius)
		max_radius = maxf(max_radius, radius)
	check(max_radius - min_radius > 30, "el VFX se enrolla en espiral con radio creciente")
	await frames(22)
	check(not player._is_attack_active() and absf(player.velocity.x) >= launch_speed - 1 and player.animated_sprite.animation == &"aerial_stall", "al acabar conserva el impulso y el stall (%s, vx %.0f)" % [player.animated_sprite.animation, player.velocity.x])
	for i in range(90):
		await frames(1)
		if player.is_on_floor():
			break
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(player.long_jump_active and absf(player.velocity.x) > launch_speed, "aterrizar y saltar encadena bunnyhop con más velocidad")

	print("== Parry: voz y ondas iniciales")
	await reset_player()
	player._start_roar()
	var waves := arena.get_node_or_null("RoarShockwaves")
	check(waves != null and waves.get_child_count() == 3, "el inicio del parry lanza tres shockwaves")
	check(root.get_node("Sfx").last_played.has("shine") and root.get_node("Sfx").last_played.has("roar_parry"), "rugido superpuesto al sonido del shine")
	player._end_roar()
	await frames(25)
	check(not is_instance_valid(waves), "las ondas se liberan tras la ventana inicial")
	print("== Agachado: escala, suelo y movimiento")
	await reset_player()
	style.reset()
	Input.action_press("move_right")
	await frames(10)
	check(player.velocity.x > 0 and player.animated_sprite.animation == player.ANIMATION_WALK, "camina antes de agacharse")
	Input.action_press("move_down")
	await frames(3)
	var crouch_at := player.position
	check(player.is_crouching() and player.velocity.x == 0 and player.animated_sprite.animation == player.ANIMATION_CROUCH, "abajo detiene la caminata y entra en agachado")
	await frames(10)
	check(player.position.is_equal_approx(crouch_at), "mantener dirección mientras se agacha no desplaza al personaje")
	var crouch_scale: Vector2 = player.animated_sprite.scale
	var crouch_position: Vector2 = player.animated_sprite.position
	player._align_character_animation(player.ANIMATION_JUMP_SQUAT)
	check(crouch_scale.is_equal_approx(player.animated_sprite.scale) and crouch_position.is_equal_approx(player.animated_sprite.position), "el agachado conserva el tamaño y apoyo de su pose original de salto")
	player._update_character_animation()
	check(player.get_node("CollisionShape2D").shape.size == Vector2(20, 28), "se conserva la caja de colisión")
	Input.action_release("move_down")
	await frames(5)
	check(player.velocity.x > 0 and not player.is_crouching(), "soltar abajo permite retomar la caminata")
	Input.action_press("dash")
	await frames(22)
	style._set_points(650)
	Input.action_press("move_down")
	await frames(6)
	check(player.is_sprinting and player.velocity.x > player.max_speed and player.animated_sprite.animation == player.ANIMATION_SPRINT, "abajo durante la corrida mantiene su velocidad y animación")
	check(not player.is_crouching() and player.wrath.state == player.wrath.State.IDLE, "correr no permite agacharse ni cargar Wrath")
	Input.action_release("dash")
	await frames(1)
	check(not player.is_crouching() and player.animated_sprite.animation != player.ANIMATION_CROUCH, "la frenada de carrera tampoco se convierte en agachado")
	await reset_player()
	style.reset()
	Input.action_press("move_down")
	await frames(2)
	Input.action_press("jump")
	await frames(4)
	Input.action_release("jump")
	check(not player.is_on_floor() and not player.is_crouching() and player.animated_sprite.animation != player.ANIMATION_CROUCH, "saltar cancela el agachado y abajo no fuerza la pose en el aire")
	await frames(8)
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY, "abajo no bloquea el heavy aéreo")

	release_all()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
