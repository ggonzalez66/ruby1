extends SceneTree
# Intenta saltarse el primer foso sin voladores con los recursos aéreos disponibles.
# El foso inicial es el menor: también prueba spin + uppercut + doble salto encadenados.
var player: CharacterBody2D
var fails := 0
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in range(n):
		Engine.time_scale = 1.0
		await physics_frame
func release_all() -> void:
	for a in ["move_right", "move_left", "move_up", "jump", "attack", "heavy_attack"]:
		Input.action_release(a)
func run() -> void:
	var level: Node = load("res://sky_stairs.tscn").instantiate()
	root.add_child(level)
	for flyer in get_nodes_in_group(&"training_dummies"):
		flyer.queue_free()
	await frames(4)
	player = get_first_node_in_group(&"player")
	Input.action_press("dash")
	await frames(20)
	var destination: Node2D = level.get_node("Seg1Land")
	var destination_edge: float = destination.position.x - destination.size.x * 0.5
	for start in ["long_jump", "screw", "uppercut"]:
		release_all()
		player._cancel_all_states()
		player.position = Vector2(380, -2)
		player.facing = 1
		player.hurt_lock_timer = 0
		player.block_stun_timer = 0
		player.velocity = Vector2.ZERO
		player.current_health = 99999
		player.attack_cooldown_timer = 0
		player.running_attack_cooldown_timer = 0
		await frames(4)
		# Vacía los overlaps del intento anterior antes de fijar la salida definitiva.
		player.position = Vector2(380, -2)
		player.velocity = Vector2.ZERO
		await frames(2)
		Input.action_press("move_right")
		player._start_sprint(1)
		player.dash_timer = 0
		player.velocity.x = 1240
		match start:
			"long_jump":
				player.bunnyhop_bonus = 560
				player._launch_long_jump()
			"screw":
				player.attack_mode = player.ATTACK_GROUND_CHARGED
				player._start_spin_attack()
			"uppercut":
				player._start_uppercut_attack(false)
		var crossed := false
		var farthest := player.position.x
		for tick in range(480):
			await frames(1)
			Input.action_release("jump")
			Input.action_release("attack")
			Input.action_release("heavy_attack")
			Input.action_release("move_up")
			farthest = maxf(farthest, player.position.x)
			if player.position.x >= destination_edge:
				crossed = true
				break
			if player.position.x < 400 or player.position.y > 370:
				break
			if player.velocity.y >= 0 and not player._is_attack_active():
				if player.air_jumps_remaining > 0:
					Input.action_press("jump")
				elif player.air_uppercut_available:
					Input.action_press("move_up")
					Input.action_press("heavy_attack")
				elif player.running_attack_cooldown_timer <= 0:
					Input.action_press("attack")
			elif player.attack_mode == player.ATTACK_LIGHT_CHARGED_AIR:
				Input.action_press("jump")
		print("%s sin rebotes: %s (x máxima %.0f, destino %.0f)" % [start, "FAIL" if crossed else "OK", farthest, destination_edge])
		if crossed:
			fails += 1
	release_all()
	Input.action_release("dash")
	print("RESULTADO: %d/3 OK" % (3 - fails))
	quit(1 if fails else 0)
