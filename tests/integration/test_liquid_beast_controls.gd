extends SceneTree

var checks := 0
var fails := 0
var player: CharacterBody2D
var arena: Node2D
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("OK " if ok else "FAIL ", label)
func button(id: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = id
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func trigger(id: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = id
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func reset(beast := false) -> void:
	for id in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_Y]:
		button(id, false)
	trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "heavy_attack", "roar", "dash", "transform", "throw_knife", "weapon_throw"]:
		Input.action_release(action)
	player._respawn_player()
	player.weapons.equip(&"sword")
	player.position = Vector2(0, -2)
	player.liquid_beast = beast
	root.get_node("Ferocity").reset()
	await frames(6)
func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(12000, 100)
	floor_body.position.y = 50
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	arena.add_child(player)
	await reset()
	button(JOY_BUTTON_B, true)
	await frames(2)
	check(not player.liquid_beast, "B deja de transformar")
	button(JOY_BUTTON_B, false)
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(2)
	check(player.liquid_beast and player.has_knife and not is_instance_valid(player.thrown_knife), "RB solo transforma sin lanzar")
	await frames(40)
	check(player.liquid_beast, "Mantener RB no alterna repetidamente")
	button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await frames(2)
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(2)
	check(not player.liquid_beast, "Nueva pulsación RB vuelve a Viridy")
	await reset()
	# Both press orders within the same physics frame must choose Aim + throw.
	for aim_first in [true, false]:
		await reset()
		if aim_first:
			trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
		button(JOY_BUTTON_RIGHT_SHOULDER, true)
		if not aim_first:
			trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await frames(2)
		check(not player.liquid_beast and not player.has_knife and is_instance_valid(player.thrown_knife), "LT + RB simultáneos priorizan lanzamiento, orden %s" % aim_first)
		trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
		await frames(35)
		check(not player.liquid_beast, "Soltar LT con RB mantenido no transforma")
		button(JOY_BUTTON_RIGHT_SHOULDER, false)
		trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await frames(2)
		button(JOY_BUTTON_RIGHT_SHOULDER, true)
		await frames(100)
		check(player.has_knife and not player.liquid_beast, "LT + RB recupera sin transformar")
	await reset(true)
	trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(2)
	check(player.liquid_beast and not player.weapons.aim and player.has_knife, "LT + RB en bestia no transforma accidentalmente ni lanza")
	await reset(true)
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	await frames(2)
	check(not player.roar_active and not player.is_perfect_shine() and not player.is_roar_aura_active(), "LB en bestia no activa parry ni guardia")
	var health: int = player.current_health
	player.take_damage(1, player.position + Vector2(30, 0))
	check(player.current_health == health - 1, "LB no concede invulnerabilidad a la bestia")
	await reset()
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	await frames(2)
	check(player.roar_active and player.is_perfect_shine(), "Viridy conserva el parry con LB")
	await reset()
	player._start_sprint(1)
	player.velocity.x = player.sprint_speed
	player.long_jump_active = true
	player.frontflip_active = true
	player.backflip_chain_timer = 0.15
	player.long_jump_chain_timer = 0.15
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(2)
	check(player.liquid_beast and not player.is_sprinting and not player.frontflip_active and not player.long_jump_active and player.backflip_chain_timer == 0 and player.long_jump_chain_timer == 0, "Transformarse limpia carrera, flips y ventanas pendientes")
	check(absf(player.velocity.x) <= player.max_speed, "Transformarse no conserva velocidad de sprint")
	await reset(true)
	Input.action_press("move_right")
	trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(player.dash_timer > 0, "RT permite dash en bestia")
	await frames(35)
	check(player.beast_running and is_equal_approx(player.velocity.x, player.sprint_speed) and not player.is_sprinting and not player._uses_sprint_movement(), "Mantener RT tras dash corre como bestia a velocidad de carrera")
	button(JOY_BUTTON_A, true)
	await frames(10)
	button(JOY_BUTTON_A, false)
	check(not player.is_on_floor() and not player.frontflip_active and not player.backflip_active and not player.long_jump_active, "Salto corriendo es un salto normal, sin salto largo")
	check(player.velocity.x > player.max_speed, "El salto corriendo conserva la velocidad de carrera")
	var jumps: int = player.air_jumps_remaining
	await frames(2)
	button(JOY_BUTTON_A, true)
	await frames(2)
	check(player.air_jumps_remaining < jumps and not player.frontflip_active and not player.backflip_active, "Doble salto con RT mantenido no hace flips")
	button(JOY_BUTTON_A, false)
	for _i in 120:
		await frames(1)
		if player.is_on_floor():
			break
	await frames(5)
	check(player.is_on_floor() and player.beast_running and is_equal_approx(player.velocity.x, player.sprint_speed), "Aterriza y sigue corriendo con RT")
	trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await frames(30)
	check(not player.beast_running and absf(player.velocity.x) <= player.max_speed + 0.01, "Soltar RT vuelve a caminar")
	Input.action_release("move_right")
	await reset(true)
	player.position.y = -300
	await frames(2)
	trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(player.dash_timer > 0, "Bestia también dashea en el aire")
	await frames(25)
	check(not player.is_sprinting and not player.frontflip_active and not player.long_jump_active, "Dash aéreo con RT no activa la carrera de Viridy")
	# All entry points must reject the move without spending a jump.
	jumps = player.air_jumps_remaining
	player._start_backflip()
	player._perform_frontflip()
	player._start_sprint(1)
	check(not player.frontflip_active and not player.backflip_active and not player.is_sprinting and player.air_jumps_remaining == jumps, "Entradas directas no reintroducen flips ni consumen saltos")
	trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await reset()
	Input.action_press("move_right")
	await frames(30)
	check(not player.beast_running and absf(player.velocity.x) <= player.max_speed + 0.01, "Viridy caminando no hereda la carrera de bestia")
	Input.action_release("move_right")
	for state in ["closed", "open", "dying"]:
		await reset(true)
		var target = load("res://training_dummy.tscn").instantiate()
		target.position = Vector2(35, -2)
		target.max_health = 30
		arena.add_child(target)
		target.set_physics_process(false)
		await frames(2)
		if state == "open":
			target.ruby_core.register_parry()
		elif state == "dying":
			target.take_hit(Vector2.ZERO, 1, 999)
		Input.action_press("move_up")
		button(JOY_BUTTON_Y, true)
		await frames(2)
		button(JOY_BUTTON_Y, false)
		Input.action_release("move_up")
		if state == "closed":
			check(player.execution_core == null and target.current_health < 30, "Uppercut en bestia daña un núcleo cerrado sin ejecutar")
		else:
			check(player.execution_core == target.ruby_core, "Uppercut por input reclama núcleo " + state)
		for _i in 80:
			await frames(1)
			if player.execution_core == null and player.attack_mode == player.ATTACK_NONE:
				break
		check(not player.frontflip_active and not player.is_sprinting and player.execution_air_exit == player.ExecutionAirExit.NONE, "Salida de uppercut/ejecución sin flip ni carrera: " + state)
		target.queue_free()
		await frames(2)
	# Saved defaults and remapping retain both actions on the contextual button.
	var menu = load("res://pause_menu.gd").new()
	menu.testing_mode = true
	arena.add_child(menu)
	await frames(2)
	var config := ConfigFile.new()
	config.set_value("input", "version", 6)
	config.set_value("joypad", "transform", ["b:1"])
	config.set_value("joypad", "weapon_throw", ["b:10"])
	config.set_value("keyboard", "attack", [KEY_K])
	config.save(menu.SETTINGS_PATH)
	menu._load_settings()
	for action in ["transform", "weapon_throw"]:
		check(InputMap.action_get_events(action).any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_SHOULDER), "Migración v6 mantiene RB en " + action)
	check(InputMap.action_get_events("attack").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_K), "Migración conserva teclado personalizado")
	menu.remap_device = menu.Device.JOYPAD
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	menu._assign_event("transform", rb)
	check(InputMap.action_get_events("weapon_throw").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_SHOULDER), "Remap de transformación permite RB compartido")
	menu._save_settings()
	menu._load_settings()
	check(InputMap.action_get_events("transform").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_SHOULDER), "Guardar y cargar v7 conserva transformación en RB")
	arena.queue_free()
	await frames(3)
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
