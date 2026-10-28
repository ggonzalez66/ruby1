extends SceneTree
var checks := 0
var fails := 0
var player: CharacterBody2D
var arena: Node2D
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("OK " if ok else "FAIL ", label)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	player = load("res://playerr.tscn").instantiate()
	arena.add_child(player)
	await frames(3)
	player.set_physics_process(false)
	var enemy = load("res://training_dummy.tscn").instantiate()
	enemy.max_health = 1000
	enemy.position = Vector2(30, -20)
	arena.add_child(enemy)
	await frames(2)
	enemy.set_physics_process(false)
	for id in [&"unarmed", &"sword", &"axe", &"hammer", &"glaive"]:
		player.weapons.equip(id)
		player.attack_mode = player.ATTACK_SPIN
		player.attack_timer = player.spin_attack_duration
		player.attack_targets_hit.clear()
		player._set_attack_active(true)
		var health: int = enemy.current_health
		player._hit_area(enemy)
		var first: int = enemy.current_health
		player._hit_area(enemy)
		check(enemy.current_health == first, str(id) + " no duplica impacto en un pulso")
		player.common_moves.tick(player.spin_attack_duration * 0.6)
		player._hit_area(enemy)
		check((enemy.current_health < first) == (id in [&"sword", &"glaive"]), str(id) + " segundo pulso correcto")
		check(first < health, str(id) + " causa daño")
		player._cancel_all_states()
	player.weapons.equip(&"hammer")
	player.attack_mode = player.ATTACK_HEAVY
	player.attack_timer = 0
	player._set_attack_active(true)
	player._hit_area(enemy)
	await frames(2)
	check(player.attack_mode == player.ATTACK_HEAVY, "Martillo no rebota al contactar")
	check(player.common_moves.carried.has(enemy), "Martillo captura enemigo")
	player._cancel_all_states()
	check(player.common_moves.carried.is_empty() and not enemy.is_physics_processing(), "Cancelación restaura estado físico anterior")
	player.weapons.equip(&"glaive")
	player.attack_mode = player.ATTACK_SPIN
	player.attack_timer = player.spin_attack_duration
	player._set_attack_active(true)
	check(player.common_moves.reach > 1.0, "Guja amplía el giro")
	player._cancel_all_states()
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 100)
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(4000, 100)
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	player.weapons.equip(&"axe")
	player.position = Vector2(0, -250)
	enemy.position = Vector2(0, -140)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	Input.action_press("move_down")
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	Input.action_release("move_down")
	var caught := false
	for i in 100:
		caught = caught or player.common_moves.carried.has(enemy)
		await frames(1)
	check(caught, "Dive por input arrastra enemigo en la caída")
	check(player.is_on_floor() and player.common_moves.carried.is_empty(), "Dive termina en suelo y libera enemigo")
	check(enemy.global_position.y > -100, "El enemigo desciende junto al jugador")
	player._cancel_all_states()
	player.weapons.equip(&"hammer")
	player.set_physics_process(false)
	enemy.position = Vector2(-80, 30)
	await frames(2)
	var before_aoe: int = enemy.current_health
	player.attack_mode = player.ATTACK_HEAVY
	player._set_attack_active(true)
	player._land_heavy_attack_on_floor()
	check(enemy.current_health < before_aoe, "Explosión daña un objetivo cercano no capturado")
	var barrier := StaticBody2D.new()
	barrier.collision_layer = 2
	barrier.position = Vector2(-40, 0)
	var barrier_shape := CollisionShape2D.new()
	barrier_shape.shape = RectangleShape2D.new()
	barrier_shape.shape.size = Vector2(10, 100)
	barrier.add_child(barrier_shape)
	arena.add_child(barrier)
	await frames(2)
	before_aoe = enemy.current_health
	player.attack_mode = player.ATTACK_HEAVY
	player._set_attack_active(true)
	player._land_heavy_attack_on_floor()
	check(enemy.current_health == before_aoe, "Pared bloquea explosión")
	player.weapons.equip(&"sword")
	player.set_physics_process(true)
	Input.action_press("throw_knife")
	await frames(2)
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	Input.parse_input_event(rb)
	Input.flush_buffered_events()
	await frames(2)
	check(not player.has_knife, "RB real lanza arma en Aim")
	check(not root.get_node("TimeControl").slow_motion, "RB no activa cámara lenta")
	rb.pressed = false
	Input.parse_input_event(rb)
	Input.flush_buffered_events()
	await frames(8)
	rb = InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	Input.parse_input_event(rb)
	Input.flush_buffered_events()
	await frames(90)
	check(player.has_knife and player.weapons.current_weapon() == &"sword", "RB real recupera la misma espada")
	rb.pressed = false
	Input.parse_input_event(rb)
	Input.action_release("throw_knife")
	arena.queue_free()
	await frames(2)
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
