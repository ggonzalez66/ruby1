extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30000, 100)
	collider.shape = shape
	floor_body.position.y = 50
	floor_body.add_child(collider)
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position.y = -2
	arena.add_child(player)
	await frames(6)
	print("== Dash attack y combo de carrera durante cooldown")
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(25)
	await tap("attack")
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED and player.running_attack_cooldown_timer > 0.0, "el primer ataque corriendo sigue siendo el dash attack")
	for tick in range(50):
		await frames(1)
		if not player._is_attack_active() and player.attack_cooldown_timer <= 0.0:
			break
	check(player.running_attack_cooldown_timer > 0.1, "el ataque normal se recupera antes del cooldown del dash attack")
	for hit in [1, 2, 3]:
		await tap("attack")
		if hit > 1:
			for tick in range(30):
				if player.light_combo_step == hit:
					break
				await frames(1)
		check(player.attack_mode == player.ATTACK_SLASH and player.light_combo_step == hit, "durante el cooldown sale el hit %d del combo" % hit)
		check(player.is_sprinting and player.velocity.x >= player.sprint_speed - 1, "el hit %d conserva la corrida" % hit)
		if hit == 1:
			# La recarga puede terminar durante el combo; el hit 2/3 no debe convertirse en un dash.
			player.running_attack_cooldown_timer = 0.01
			await frames(2)
	for tick in range(60):
		await frames(1)
		if not player._is_attack_active() and player.attack_cooldown_timer <= 0.0:
			break
	await tap("attack")
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED, "cerrado el combo y terminado el cooldown vuelve el dash attack")
	for action in ["dash", "move_right", "attack"]:
		Input.action_release(action)
	print("== Capturas sin buffers de acción")
	for action in ["jump", "attack", "heavy_attack", "dash", "roar", "throw_knife"]:
		player._respawn_player()
		player.position = Vector2(0, -2)
		await frames(5)
		var enemy: Node2D = load("res://training_dummy.tscn").instantiate()
		enemy.position = Vector2(40, -2)
		enemy.max_health = 20
		arena.add_child(enemy)
		enemy.current_health = 1
		enemy.set_physics_process(false)
		player.attack_mode = player.ATTACK_HEAVY_GROUND
		player.attack_targets_hit.clear()
		player._hit_area(enemy)
		await frames(3)
		await tap(action)
		check(player.execution_core == enemy.ruby_core, "%s durante captura no interrumpe el Ruby" % action)
		for tick in range(60):
			await frames(1)
			if player.execution_core == null:
				break
		await frames(2)
		check(player.attack_mode == player.ATTACK_NONE and player.jump_buffer_timer == 0.0 and player.combo_buffer == &"" and player.dash_timer <= 0.0 and not player.roar_active and player.has_knife and player.air_jumps_remaining == player.max_air_jumps, "%s durante captura se descarta al terminar" % action)
		enemy.queue_free()
	print("== Impacto común de crítico y remate, sin romper antes el núcleo")
	player._respawn_player()
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(400, -2)
	boss.max_health = 105
	arena.add_child(boss)
	boss.set_physics_process(false)
	await frames(5)
	boss.ruby_core.register_parry(1)
	boss.ruby_core.register_parry(2)
	boss.ruby_core.register_parry(3)
	check(boss.ruby_core.claim(player), "se puede reclamar el Ruby del jefe abierto")
	var before_critical: Array = arena.get_children()
	var sounds: Node = root.get_node("Sfx")
	var hurt_before: int = int(sounds.last_played.get("boss_hurt", -1))
	boss.ruby_core.complete(player)
	var critical_shards := 0
	for child in arena.get_children():
		if child not in before_critical and child.get_child_count() == 16 and child.get_child(0) is Line2D:
			critical_shards += 1
	check(critical_shards == 1 and boss.ruby_core.visible and not boss.ruby_core.broken and boss.ruby_core.cracks == 1, "el crítico emite la explosión de 16 fragmentos y conserva el Ruby agrietado")
	var critical_mix := false
	var completion_mix := false
	for voice in sounds.players:
		if voice.stream == sounds.streams["guard_break"] and is_equal_approx(voice.volume_db, float(sounds.MIX["guard_break"][0]) + 1.0) and voice.pitch_scale > 1.19 and voice.pitch_scale < 1.31:
			critical_mix = true
		if voice.stream == sounds.streams["enemy_die"] and is_equal_approx(voice.volume_db, float(sounds.MIX["enemy_die"][0]) + 4.0) and voice.pitch_scale > 0.64 and voice.pitch_scale < 0.76:
			completion_mix = true
	check(critical_mix, "el crítico usa el sonido de rotura con la misma mezcla y tono del remate")
	check(completion_mix and int(sounds.last_played.get("boss_hurt", -1)) == hurt_before, "el crítico suma la finalización grave de la ejecución y sustituye el sonido de golpe normal")
	boss.take_hit(player.position, 1, 999)
	check(is_equal_approx(boss.ruby_core.open_time, 5.0), "el jefe a cero abre cinco segundos de remate")
	boss.ruby_core._physics_process(4.99)
	check(boss.current_health == 0 and boss.ruby_core.is_open(), "la ventana de remate sigue abierta hasta completar cinco segundos")
	boss.ruby_core._physics_process(0.02)
	check(boss.current_health == 21 and not boss.ruby_core.is_open(), "recuperar el 20 % usa la vida máxima del jefe, incluso con máximos distintos de 100")
	await frames(5)
	boss.take_hit(player.position, 1, 999)
	check(boss.ruby_core.claim(player), "el jefe que vuelve a cero permite rematar")
	var before_final: Array = arena.get_children()
	boss.ruby_core.complete(player)
	var final_shards := 0
	for child in arena.get_children():
		if child not in before_final and child.get_child_count() == 16 and child.get_child(0) is Line2D:
			final_shards += 1
	check(final_shards == critical_shards and boss.ruby_core.broken and not boss.ruby_core.visible, "el remate usa la misma explosión y sí rompe/oculta el Ruby")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
