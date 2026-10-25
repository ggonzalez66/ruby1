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

func mark(enemy: Node2D, speed := Vector2(950, -260)) -> Node2D:
	var spear: Node2D = load("res://knife.gd").new()
	arena.add_child(spear)
	spear.launch(player, enemy.global_position + enemy.impact_offset, speed)
	player.thrown_knife = spear
	player.has_knife = false
	spear._stick_in_enemy(enemy)
	spear.set_physics_process(false)
	return spear

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.size = Vector2(30000, 100)
	floor_body.position = Vector2(0, 50)
	floor_body.collision_layer = 2
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(5)
	print("== Quemadura no letal sin hitstun")
	var enemy: Area2D = load("res://chaser_dummy.gd").new()
	enemy.max_health = 10
	enemy.position = Vector2(400, -2)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.state = enemy.State.TELEGRAPH
	enemy.state_timer = 1.0
	enemy.knock_velocity = 0.0
	var spear := mark(enemy)
	check(spear.state == spear.State.MARKED and spear.sprite.visible and enemy.current_health == 10, "la lanza queda clavada sin daño instantáneo")
	check(is_equal_approx(spear.sprite.rotation, Vector2(950, -260).angle()) and spear.sprite.position.x < 0, "mantiene el ángulo de entrada y deja el asta fuera del objetivo")
	spear._physics_process(0.49)
	check(enemy.current_health == 10, "no hay daño antes del primer intervalo")
	spear._physics_process(0.02)
	check(enemy.current_health == 9, "el fuego causa un punto después de medio segundo")
	check(enemy.state == enemy.State.TELEGRAPH and enemy.state_timer == 1.0 and enemy.knock_velocity == 0.0, "el DoT no interrumpe, empuja ni retrasa el ataque")
	spear._physics_process(10.0)
	check(enemy.current_health == 1 and enemy.visible and not enemy.ruby_core.broken, "múltiples ticks nunca matan ni rompen el Ruby")
	check(enemy.ruby_core.is_open(), "la poca vida causada por fuego habilita la ejecución habitual")
	spear._physics_process(10.0)
	check(enemy.current_health == 1, "a un punto de vida se mantiene el mínimo")
	spear.recall()
	check(player.execution_core == enemy.ruby_core, "recall del enemigo quemado y open inicia la ejecución")
	await frames(35)
	check(enemy.current_health == 0 and not enemy.visible, "la ejecución sí termina la baja")
	player._respawn_player()
	await frames(3)
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(800, -2)
	boss.max_health = 100
	boss.shine_chance = 0.0
	arena.add_child(boss)
	boss.set_physics_process(false)
	spear = mark(boss)
	spear._physics_process(0.5)
	check(boss.current_health == 99, "el jefe también recibe quemadura")
	boss.current_health = 2
	spear._physics_process(4.0)
	check(boss.current_health == 1 and not boss.ruby_core.final_open and not boss.defeated, "la quemadura no abre remate ni mata al jefe")
	boss.current_health = 50
	boss.ruby_core.open_time = 2.5
	boss.ruby_core.claim(player)
	spear._physics_process(2.0)
	check(boss.current_health == 50, "captura y crítico suspenden el DoT")
	boss.ruby_core.release_claim(player)
	spear._physics_process(0.25)
	check(boss.current_health == 50, "liberar la captura no acumula daño atrasado")
	spear._physics_process(0.26)
	check(boss.current_health == 49, "la quemadura retoma su intervalo al liberarse")
	spear._release()
	await frames(2)
	boss.ruby_core.open_time = 0.0
	boss.ruby_core.claim_wrath(player)
	check(boss.ruby_core.apply_spirit_burn(500) == 0 and boss.current_health == 49, "la stasis de Wrath no recibe daño periódico")
	boss.ruby_core.release_claim(player)
	boss.current_health = 0
	boss.ruby_core.enter_final_open()
	check(boss.ruby_core.apply_spirit_burn(500) == 0 and boss.current_health == 0, "un jefe ya a cero no revive ni pierde su remate por fuego")
	boss.reset_dummy()
	var original_material: Material = boss.flash_polys[0].material
	spear = mark(boss)
	spear._physics_process(0.5)
	var before: int = boss.current_health
	spear.recall()
	spear._physics_process(0.2)
	check(boss.current_health == before and spear.state == spear.State.SOUL_PULL and not spear.sprite.visible, "el recall consume la lanza y hace pull sin un tick extra")
	await frames(2)
	check(boss.flash_polys[0].material == original_material, "consumir la marca restaura el cuerpo del enemigo")
	spear = mark(boss)
	player._respawn_player()
	await frames(3)
	check(not is_instance_valid(spear) and boss.flash_polys[0].material == original_material, "reiniciar elimina lanza, llamas y tintado")
	print("== Presentación e inputs conservados")
	player.position = Vector2(0, -2)
	await frames(3)
	Input.action_press("throw_knife")
	await frames(2)
	Input.action_release("throw_knife")
	check(is_instance_valid(player.thrown_knife) and player.animated_sprite.animation == player.ANIMATION_KNIFE_THROW, "el input real reproduce el lanzamiento nuevo")
	check(player.animated_sprite.sprite_frames.get_frame_count(player.ANIMATION_KNIFE_THROW) == 4, "la animación contiene cuatro poses nuevas")
	check(player.thrown_knife.velocity.x == player.knife_throw_forward.x and player.thrown_knife.life > 3.9, "se conserva velocidad horizontal y tiempo de vuelo")
	player.attack_cooldown_timer = 0.0
	player._start_heavy_attack(false)
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND, "el lanzamiento no bloquea el heavy")
	player._respawn_player()
	var session: Node = root.get_node("RunSession")
	session.player = player
	session.ghost = Sprite2D.new()
	session.ghost.material = ShaderMaterial.new()
	session.ghost.material.shader = load("res://shaders/charge_glow.gdshader")
	arena.add_child(session.ghost)
	session.best_frames = [[0.0, 400.0, -2.0, "knife_throw", 0, 0.225, 0.225, 0.0, -40.0, 0.3, false]]
	session.record = {"best": 2.0}
	session.elapsed = 0.0
	session._update_ghost()
	check(session.ghost.scale.is_equal_approx(Vector2.ONE * 0.18) and is_zero_approx(session.ghost.rotation), "un fantasma antiguo normaliza escala y orientación de la nueva jabalina")
	session._clear_run()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
