extends SceneTree

# Shine con bloqueo y durabilidad, perfect devolución, rotura y recarga, shine knife con recall,
# shine enemigo, riposte del dash attack, colores y ventajas SS/SSS y hitbox del heavy en picado.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_shine_shield.gd

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

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	await frames(5)
	Engine.time_scale = 1.0

func latent_roar() -> void:
	# Rugido mantenido, ya pasadas las frames explosivas (solo aura latente).
	Input.action_press("roar")
	await frames(14)

func make_chaser(at: Vector2) -> Area2D:
	var chaser: Area2D = Area2D.new()
	chaser.set_script(load("res://chaser_dummy.gd"))
	chaser.position = at
	level.add_child(chaser)
	return chaser

func shoot_at_player(from: Vector2, shooter: Node2D) -> Area2D:
	var shot: Area2D = load("res://projectile.gd").new()
	shot.velocity = (player.global_position + Vector2(0, -16) - from).normalized() * 460.0
	shot.shooter = shooter
	level.add_child(shot)
	shot.global_position = from
	return shot

func _run() -> void:
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")
	var hud: Node = level.get_node("HUD")

	print("== Bloqueo en frames latentes")
	await reset()
	player.parry_uses_aura_radius = false
	var chaser := make_chaser(GROUND + Vector2(80, 2))
	chaser.max_lunge = 0.0
	await latent_roar()
	var blocked := false
	for i in range(80):
		await frames(1)
		if player.block_stun_timer > 0.0:
			blocked = true
			break
	check(blocked, "un golpe con el shine mantenido (sin parry) se bloquea")
	check(player.current_health == player.max_health, "no quita vida (%d)" % player.current_health)
	check(is_equal_approx(player.shine_durability, player.shine_max_durability - player.shine_block_cost), "gasta durabilidad (%.0f)" % player.shine_durability)
	check(player.velocity.x <= -500.0 and player.roar_active, "empuja lejos (knockback doble) sin apagar el shine (vx %.0f)" % player.velocity.x)
	release_all()
	await tap("jump")
	await tap("attack")
	await frames(1)
	check(player.block_stun_timer > 0.0 and player.velocity.y >= 0.0 and player.attack_mode == player.ATTACK_NONE, "durante el empuje no se puede saltar ni atacar")
	player._end_roar()
	await tap("roar")
	await frames(1)
	check(player.roar_active and player.block_stun_timer > 0.0, "se puede hacer shine pero no cancela el empuje")
	release_all()
	await frames(20)
	chaser.queue_free()
	await reset()
	player.block_stun_timer = player.block_stun_time
	player.velocity.x = 300.0
	await tap("dash")
	check(player.block_stun_timer == 0.0 and player.dash_timer > 0.0, "el dash saca del empuje")
	await frames(20)
	# El parry cancela el empuje y recupera durabilidad.
	await reset()
	player.parry_uses_aura_radius = true
	player.shine_durability = 50.0
	player.block_stun_timer = player.block_stun_time
	chaser = make_chaser(GROUND + Vector2(130, 2))
	chaser.max_lunge = 0.0
	var parried := false
	for i in range(80):
		await frames(1)
		if chaser.state == chaser.State.SWING and not player.roar_active:
			player.block_stun_timer = player.block_stun_time
			Input.action_press("roar")
		if chaser.state == chaser.State.STAGGER:
			parried = true
			break
	release_all()
	check(parried and player.block_stun_timer == 0.0, "un parry cancela el empuje")
	check(player.shine_durability >= 50.0 + player.shine_parry_restore - 0.5, "parrear no gasta: recupera durabilidad (%.0f)" % player.shine_durability)
	chaser.queue_free()
	await frames(30)

	print("== Proyectiles y devolución perfecta")
	await reset()
	var dummy: Node2D = load("res://training_dummy.tscn").instantiate()
	dummy.position = GROUND + Vector2(420, 2)
	dummy.max_health = 99
	level.add_child(dummy)
	await frames(2)
	await latent_roar()
	var shot := shoot_at_player(GROUND + Vector2(150, -16), dummy)
	for i in range(30):
		await frames(1)
		if shot.reflected:
			break
	check(shot.reflected and shot.shine_level == 1, "devuelto con el shine mantenido")
	check(is_equal_approx(player.shine_durability, player.shine_max_durability - player.shine_reflect_cost), "gasta durabilidad (%.0f)" % player.shine_durability)
	var normal_speed: float = shot.velocity.length()
	release_all()
	await frames(40)
	await reset()
	shot = shoot_at_player(GROUND + Vector2(70, -16), dummy)
	Input.action_press("roar")
	for i in range(10):
		await frames(1)
		if shot.reflected:
			break
	check(shot.reflected and shot.shine_level == 2, "en las frames del parry: devolución perfecta (nivel %d)" % shot.shine_level)
	check(player.shine_durability == player.shine_max_durability, "no gasta durabilidad")
	check(shot.velocity.length() > normal_speed * 1.3, "sale con más fuerza (%.0f vs %.0f)" % [shot.velocity.length(), normal_speed])
	release_all()
	await frames(40)

	print("== Rotura y recarga")
	await reset()
	player._change_shine_durability(-60.0)
	check(player.roar_aura.wear_material.get_shader_parameter("glow_amount") > 0.4, "con menos durabilidad el Metatrón se enrojece")
	check(abs(hud.shine_ratio - 0.4) < 0.01, "la barra del HUD lo refleja (%.2f)" % hud.shine_ratio)
	player._change_shine_durability(-60.0)
	check(player.shine_broken and hud.shine_broken, "a cero se rompe")
	await tap("roar")
	check(not player.roar_active, "roto: no hay shine")
	var waited := 0
	while player.shine_broken and waited < 600:
		await frames(1)
		waited += 1
	check(not player.shine_broken and player.shine_durability >= player.shine_min_to_use - 0.5, "se recarga hasta el mínimo y vuelve (%.1f s)" % (waited / 60.0))
	await tap("roar")
	check(player.roar_active, "y se puede volver a hacer shine")
	release_all()
	await frames(20)

	print("== Shine knife: el recall siempre rebota")
	var bounced := 0
	var tries := 0
	for distance in [180.0, 223.0, 260.0, 297.0, 335.0, 371.0, 410.0, 455.0]:
		await reset()
		var target: Node2D = load("res://training_dummy.tscn").instantiate()
		target.max_health = 999
		target.position = GROUND + Vector2(distance, 2)
		level.add_child(target)
		await frames(2)
		await tap("throw_knife")
		await frames(30)
		var knife: Node2D = player.thrown_knife
		if knife == null or knife.state != knife.State.STUCK_ENEMY:
			target.queue_free()
			continue
		tries += 1
		Input.action_press("roar")
		await frames(16)
		await tap("throw_knife")
		for i in range(60):
			await frames(1)
			if not is_instance_valid(knife) or knife.player_shines > 0:
				break
		if is_instance_valid(knife) and knife.player_shines > 0:
			bounced += 1
		release_all()
		target.queue_free()
		await frames(40)
		if is_instance_valid(player.thrown_knife):
			player.thrown_knife.queue_free()
			player.on_knife_caught()
	check(tries >= 6 and bounced == tries, "rebota en %d de %d recalls" % [bounced, tries])

	print("== Shine enemigo")
	await reset()
	var shooter: Node2D = load("res://training_dummy.tscn").instantiate()
	shooter.shoot_interval = 99.0
	shooter.shine_chance = 1.0
	shooter.position = GROUND + Vector2(400, 2)
	level.add_child(shooter)
	await frames(2)
	var camera := player.get_node("Camera2D") if player.has_node("Camera2D") else get_root().get_viewport().get_camera_2d()
	var trauma_before: float = camera.get("trauma") if camera.get("trauma") != null else 0.0
	shooter.try_shine(null)
	check(Engine.time_scale < 1.0, "hitstop al shinear el enemigo")
	var trauma_after: float = camera.get("trauma") if camera.get("trauma") != null else 0.0
	check(trauma_after > trauma_before, "y golpe de cámara (%.2f)" % trauma_after)
	await frames(30)
	Engine.time_scale = 1.0
	shooter.queue_free()

	print("== Riposte del dash attack")
	await reset()
	var victim: Node2D = load("res://training_dummy.tscn").instantiate()
	victim.max_health = 99
	victim.position = GROUND + Vector2(150, 2)
	level.add_child(victim)
	await frames(2)
	player.current_health = 50
	victim.position = GROUND + Vector2(330, 2)
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(12)
	player.riposte_timer = player.riposte_duration
	await tap("attack")
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED and player.riposte_attack, "el dash attack consume el riposte")
	await frames(15)
	check(player.current_health == 50, "el riposte conserva daño, pero su curación pasa a las ejecuciones (%d)" % player.current_health)
	check(99 - victim.current_health >= player.DAMAGE_GROUND_CHARGED * 2, "con doble daño (%d)" % (99 - victim.current_health))
	release_all()
	victim.queue_free()
	await frames(40)

	print("== Colores de rango")
	check(F.RANKS[4]["color"] == Color(1.0, 0.86, 0.4) and F.RANKS[5]["color"] == Color(1.0, 0.32, 0.22) and F.RANKS[6]["color"] == Color(1.0, 0.18, 0.4), "S dorado, SS rojo, SSS rosa")

	print("== Ventajas SS y SSS")
	await reset(Vector2(2300, -300))
	var air_dummy: Node2D = load("res://training_dummy.tscn").instantiate()
	air_dummy.aerial = true
	air_dummy.max_health = 999
	air_dummy.position = Vector2(2300, -150)
	level.add_child(air_dummy)
	await frames(2)
	F._set_points(550.0)
	player.current_health = 50
	Input.action_press("move_down")
	await tap("heavy_attack")
	Input.action_release("move_down")
	for i in range(40):
		await frames(1)
		if player.attack_mode != player.ATTACK_HEAVY:
			break
	check(F.rank == 5 and player.current_health == 50 + player.rank_heal, "SS: el heavy aéreo cura al conectar (%d)" % player.current_health)
	air_dummy.queue_free()
	await frames(40)
	# SSS: i-frames en el heavy aéreo y destrucción de proyectiles.
	await reset(Vector2(2300, -400))
	F._set_points(650.0)
	player.current_health = 100
	await tap("heavy_attack")
	await frames(2)
	player.take_damage(20, player.global_position + Vector2(50, 0), null)
	check(F.rank == 6 and player.current_health == 100 and player.attack_mode == player.ATTACK_HEAVY, "SSS: el heavy aéreo tiene i-frames")
	var near_shot := shoot_at_player(player.global_position + Vector2(40, -10), null)
	await frames(3)
	check(not is_instance_valid(near_shot) or near_shot.is_queued_for_deletion(), "SSS: el heavy aéreo destruye proyectiles")
	await frames(40)
	await reset()
	F._set_points(650.0)
	var ground_shot := shoot_at_player(GROUND + Vector2(70, -16), null)
	await tap("heavy_attack")
	await frames(3)
	check(not is_instance_valid(ground_shot) or ground_shot.is_queued_for_deletion(), "SSS: el heavy terrestre destruye proyectiles")
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	check(not player._has_sss_iframes(), "pero el heavy terrestre no da i-frames")
	await frames(30)
	await reset()
	F._set_points(650.0)
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(12)
	await tap("attack")
	await frames(2)
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN and player._has_sss_iframes(), "SSS: el giro del dash attack da i-frames")
	release_all()
	await frames(40)

	print("== Hitbox del heavy en picado")
	for offset in [-45.0, 0.0, 45.0]:
		await reset(Vector2(2300, -320))
		var below: Node2D = load("res://training_dummy.tscn").instantiate()
		below.aerial = true
		below.max_health = 999
		below.position = Vector2(2300 + offset, -120)
		level.add_child(below)
		await frames(2)
		Input.action_press("move_down")
		await tap("heavy_attack")
		Input.action_release("move_down")
		var hit := false
		for i in range(40):
			await frames(1)
			if below.current_health < 999:
				hit = true
				break
		check(hit, "picado sobre un volador %+.0f px de los pies: lo golpea" % offset)
		below.queue_free()
		await frames(30)

	release_all()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
