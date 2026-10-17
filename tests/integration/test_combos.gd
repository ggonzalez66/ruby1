extends SceneTree

# Uppercut más generoso que levanta al enemigo, rebote del heavy aéreo que devuelve el uppercut y buffer
# de combos (dash attack -> giro -> heavy aéreo, dash attack -> giro -> uppercut -> heavy aéreo,
# uppercut -> dash attack -> giro -> heavy aéreo).
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_combos.gd

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

func tap_up_heavy() -> void:
	Input.action_press("move_up")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	Input.action_release("move_up")

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.has_knife = true
	await frames(5)

func make_chaser(at: Vector2) -> Area2D:
	var chaser: Area2D = Area2D.new()
	chaser.set_script(load("res://chaser_dummy.gd"))
	chaser.position = at
	level.add_child(chaser)
	return chaser

# Avanza n frames y devuelve los modos de ataque por los que pasó.
func watch_modes(n: int) -> Array:
	var seen := []
	for i in range(n):
		await frames(1)
		if not player.attack_mode in seen:
			seen.append(player.attack_mode)
	return seen

func start_sprinting() -> void:
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(20)

func _run() -> void:
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

	print("== Uppercut: dura más y levanta al enemigo")
	await reset()
	check(player.light_uppercut_duration >= 0.2, "el uppercut golpea durante %.2f s (antes 0.08)" % player.light_uppercut_duration)
	var chaser := make_chaser(GROUND + Vector2(34, 0))
	await frames(2)
	var health_before: int = chaser.current_health
	await tap_up_heavy()
	await frames(int(player.UPPERCUT_LAUNCH_RISE * 60.0) + 4)
	check(chaser.current_health < health_before, "le pega")
	check(chaser.global_position.y < GROUND.y - player.UPPERCUT_LAUNCH_HEIGHT * 0.8, "lo levanta (%.0f px por encima del suelo)" % (GROUND.y - chaser.global_position.y))
	check((chaser.global_position.x - player.global_position.x) * player.facing > 10.0, "y queda delante de Viridy")
	await frames(int(player.UPPERCUT_LAUNCH_HANG * 60.0) - 8)
	check(chaser.launched and chaser.global_position.y < GROUND.y - 100.0, "flota un momento en el aire")
	await frames(90)
	check(not chaser.launched and abs(chaser.global_position.y - GROUND.y) < 6.0 and chaser.state != chaser.State.DEAD, "luego cae al suelo sin reventar")
	chaser.queue_free()

	print("== Rebote del heavy aéreo: devuelve el uppercut")
	await reset(GROUND + Vector2(0, -300))
	player.air_uppercut_available = false
	player.attack_mode = player.ATTACK_HEAVY
	player._bounce_out_of_heavy_attack(true)
	check(player.air_uppercut_available, "tras rebotar en un enemigo se puede volver a hacer el uppercut en el aire")

	print("== Combo: dash attack -> giro -> heavy aéreo (con buffer)")
	await reset()
	await start_sprinting()
	await tap("attack")
	await frames(2)
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED, "dash attack")
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "giro")
	# El pesado se pulsa pronto, antes de que el giro abra su ventana: queda guardado.
	await tap("heavy_attack")
	check(player.attack_mode == player.ATTACK_SPIN and player.combo_buffer == &"heavy", "el pesado pulsado pronto queda en el buffer")
	var seen: Array = await watch_modes(20)
	check(player.ATTACK_HEAVY in seen, "y sale el heavy aéreo al abrirse la ventana")

	print("== Combo: dash attack -> giro -> uppercut -> heavy aéreo")
	await reset()
	await start_sprinting()
	await tap("attack")
	await frames(2)
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "giro")
	await tap_up_heavy()
	seen = await watch_modes(20)
	check(player.ATTACK_UPPERCUT in seen, "del giro sale el uppercut")
	await tap("heavy_attack")
	seen = await watch_modes(25)
	check(player.ATTACK_HEAVY in seen, "y del uppercut, el heavy aéreo")

	print("== Combo: uppercut -> dash attack -> giro -> heavy aéreo")
	await reset()
	await tap_up_heavy()
	await frames(2)
	check(player.attack_mode == player.ATTACK_UPPERCUT, "uppercut")
	await tap("attack")
	seen = await watch_modes(20)
	check(player.ATTACK_LIGHT_CHARGED_AIR in seen, "del uppercut sale el dash attack aéreo")
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "saltando: el giro")
	await tap("heavy_attack")
	seen = await watch_modes(25)
	check(player.ATTACK_HEAVY in seen, "y el heavy aéreo")

	print("== El buffer caduca")
	await reset()
	player.combo_buffer = &"heavy"
	player.combo_buffer_timer = 0.05
	player.attack_cooldown_timer = 5.0
	await frames(8)
	check(player.combo_buffer == &"", "una acción guardada que no pudo salir se descarta a los %.1f s" % player.COMBO_BUFFER_TIME)

	release_all()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
