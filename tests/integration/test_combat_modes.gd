extends SceneTree

# Golpe del shine que empuja sin interrumpir, stop del shine enemigo, combo sin cuchillo, perseguidores
# pegados contra el parry/bloqueo, guardián pesado (arco y súper giro), pausa de frame, Gauntlet por
# oleadas con portales, Escalera al Cielo (fusión con el sol), menú principal y medallas.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_combat_modes.gd

var level: Node
var player: CharacterBody2D
var F: Node
var St: Node
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

func make_chaser(at: Vector2) -> Area2D:
	var chaser: Area2D = Area2D.new()
	chaser.set_script(load("res://chaser_dummy.gd"))
	chaser.position = at
	level.add_child(chaser)
	return chaser

func _run() -> void:
	F = root.get_node("Ferocity")
	St = root.get_node("Stats")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

	print("== Golpe del shine: empuja sin interrumpir")
	await reset()
	var chaser := make_chaser(GROUND + Vector2(200, 2))
	for i in range(60):
		await frames(1)
		if chaser.state == chaser.State.TELEGRAPH:
			break
	chaser.global_position.x = GROUND.x + 40.0
	await tap("roar")
	await frames(1)
	check(chaser.state == chaser.State.TELEGRAPH, "el perseguidor sigue con su ataque (estado %d)" % chaser.state)
	check(chaser.knock_velocity >= player.shine_push_strength * 0.9, "y sale empujado el triple (%.0f)" % chaser.knock_velocity)
	var zaps := level.get_children().filter(func(n): return n.get_script() == load("res://electric_fx.gd"))
	check(not zaps.is_empty(), "electrocutado con rayos amarillos")
	release_all()
	chaser.queue_free()
	await frames(40)

	print("== Stop del shine enemigo")
	await reset()
	var shooter: Node2D = load("res://training_dummy.tscn").instantiate()
	shooter.shoot_interval = 99.0
	shooter.shine_chance = 1.0
	shooter.position = GROUND + Vector2(400, 2)
	level.add_child(shooter)
	await frames(2)
	shooter.try_shine(null)
	var stop_ms: int = player.hitstop_end_msec - Time.get_ticks_msec()
	check(stop_ms >= int(player.hitstop_deflect * 1.2 * 1000.0) - 20, "el stop dura el doble que antes (%d ms)" % stop_ms)
	await frames(30)
	Engine.time_scale = 1.0
	shooter.queue_free()

	print("== Combo sin cuchillo")
	await reset()
	await tap("throw_knife")
	await frames(5)
	check(not player.has_knife, "sin cuchillo")
	var steps := []
	for i in range(3):
		await tap("attack")
		await frames(1)
		steps.append(player.light_combo_step)
		await frames(14)
	check(steps == [1, 2, 3], "el combo de 3 golpes sale igual (%s)" % [steps])
	check(not is_instance_valid(player.knife_missing_cue), "sin aviso de cuchillo para el combo")
	await frames(30)
	await tap("throw_knife")
	await frames(60)

	print("== Perseguidores pegados: parry y bloqueo")
	for dx in [-8.0, 0.0, 12.0, 30.0, 60.0]:
		for mode in ["bloqueo", "parry"]:
			await reset()
			# Para el bloqueo, el shine ya está en frames latentes cuando aparece el perseguidor (si no,
			# el golpe del shine lo empuja lejos antes de que ataque).
			if mode == "bloqueo":
				Input.action_press("roar")
				await frames(14)
			chaser = make_chaser(GROUND + Vector2(dx, 2))
			chaser.max_lunge = 0.0
			await frames(1)
			chaser._face(player)
			chaser.state = chaser.State.TELEGRAPH
			chaser.state_timer = 0.2
			var hp: int = player.current_health
			var outcome := "nada"
			for i in range(40):
				if mode == "parry" and chaser.state == chaser.State.SWING and not player.roar_active:
					Input.action_press("roar")
				await frames(1)
				if player.current_health < hp:
					outcome = "golpeado"
					break
				if player.block_stun_timer > 0.0 and mode == "bloqueo":
					outcome = "bloqueo"
					break
				if chaser.state == chaser.State.STAGGER:
					outcome = "parry"
					break
			release_all()
			check(outcome == mode, "perseguidor a %+.0f px, %s: %s" % [dx, mode, outcome])
			chaser.queue_free()
			await frames(10)

	print("== Guardián pesado: arco del golpe al suelo")
	await reset(Vector2(7100, -5502))
	var spawner: Node = level.get_node("BossSpawner")
	spawner.forced_boss = 0
	await reset(Vector2(7100, -5502))
	var heavy: Node2D = spawner.bosses[0]
	heavy.position.x = 6900
	heavy._face(player)
	heavy.combo_step = 2
	heavy._start_telegraph(heavy.COMBO[2])
	var crescent: Node2D = null
	for i in range(90):
		await frames(1)
		for node in get_nodes_in_group(&"projectiles"):
			if node.get_script() == load("res://shockwave.gd"):
				crescent = node
		if crescent:
			break
	check(crescent != null, "el golpe al suelo lanza el arco")
	if crescent:
		var spawn_ahead: float = (crescent.global_position.x - heavy.global_position.x) * heavy.facing
		check(spawn_ahead > 120.0 and spawn_ahead < heavy.BLADE_LENGTH + 26.0, "nace cerca de la punta, no después (%.0f px)" % spawn_ahead)
		check(crescent.direction == heavy.facing, "va hacia donde mira el guardián")
		check(crescent.height > 104.0 and crescent.height < 200.0, "más alto que un salto, se salta con doble salto (%.0f)" % crescent.height)
		check(crescent.COLOR_FILL.b > crescent.COLOR_FILL.r, "es azul")
	await frames(60)
	# Parry del golpe al suelo: el arco nace dentro del aura y se devuelve.
	await reset(Vector2(7100, -5502))
	heavy = spawner.bosses[0]
	heavy.position.x = 6900
	heavy.resist_chance = 0.0
	player.global_position.x = heavy.global_position.x + 190.0 * heavy.facing * -1.0 if false else 6900.0 + 185.0
	await frames(2)
	heavy._face(player)
	heavy.combo_step = 2
	heavy._start_telegraph(heavy.COMBO[2])
	crescent = null
	var roared := false
	for i in range(90):
		if not roared and heavy.state == heavy.State.SWING:
			Input.action_press("roar")
			roared = true
		await frames(1)
		for node in get_nodes_in_group(&"projectiles"):
			if node.get_script() == load("res://shockwave.gd"):
				crescent = node
		if crescent and crescent.reflected:
			break
	release_all()
	check(crescent != null and crescent.reflected, "al parrear el golpe, el arco se devuelve")
	await frames(60)

	print("== Guardián pesado: súper giro")
	await reset(Vector2(7100, -5502))
	heavy = spawner.bosses[0]
	heavy.position.x = 6950
	heavy.combat_started = true
	heavy.super_charge = 0.0
	await frames(30)
	check(heavy.super_charge > 0.0 and heavy.super_charge < 1.0, "se va cargando con el tiempo (%.2f)" % heavy.super_charge)
	heavy.super_charge = 1.0
	heavy.state = heavy.State.IDLE
	heavy.state_timer = 0.0
	player.invulnerability_timer = 0.0
	var saw_windup := false
	var saw_ghosts := false
	var hits := 0
	var last_hp: int = player.current_health
	for i in range(200):
		await frames(1)
		if heavy.state == heavy.State.SUPER_WINDUP:
			saw_windup = saw_windup or heavy.warning_label.visible
			saw_ghosts = saw_ghosts or heavy.ghost_root.visible
		if player.current_health < last_hp:
			hits += 1
			last_hp = player.current_health
			player.invulnerability_timer = 0.0
		if heavy.state == heavy.State.SUPER_RECOVER:
			break
	check(saw_windup and saw_ghosts, "avisa con ! y espadas fantasma")
	check(hits >= 2, "golpea varias veces (%d)" % hits)
	check(heavy.state == heavy.State.SUPER_RECOVER and heavy.state_timer > 2.0, "al terminar queda agotado (%.1f s)" % heavy.state_timer)
	check(not heavy.try_block(player.global_position), "mientras está agotado no bloquea")
	await frames(10)
	# Parry del súper giro: resiste mucho; si aturde, el doble.
	heavy.state = heavy.State.SUPER_SPIN
	heavy.super_resist_chance = 0.0
	heavy.on_deflected(player)
	check(heavy.state == heavy.State.STAGGER and is_equal_approx(heavy.state_timer, heavy.stagger_time * 2.0), "aturdido por parry: el doble de tiempo (%.1f s)" % heavy.state_timer)
	await frames(30)

	print("== Pausa de frame")
	await reset()
	var menu: CanvasLayer = level.get_node("PauseMenu")
	menu._toggle_frame_pause()
	check(paused and menu.frame_label.visible and not menu.root_control.visible, "P congela el juego sin menú")
	var frozen: Vector2 = player.global_position
	await process_frame
	await process_frame
	var h_event := InputEventAction.new()
	h_event.action = "toggle_hitbox_visuals"
	h_event.pressed = true
	menu._unhandled_input(h_event)
	check(player.show_hitbox_debug and debug_collisions_hint, "con H se ven las hitboxes estando congelado")
	menu._unhandled_input(h_event)
	check(player.global_position == frozen, "Rengar no se mueve en la pausa")
	menu._toggle_frame_pause()
	check(not paused and not menu.frame_label.visible, "otra P lo reanuda")
	check(InputMap.has_action("frame_pause"), "acción frame_pause (tecla P)")

	print("== Medallas y menú")
	var leon: Array = St.ACHIEVEMENTS.filter(func(a): return a[2] == "Leon Scott Kennedy")
	check(not leon.is_empty() and String(leon[0][3]).begins_with("Unnecessary backflips"), "Leon: %s" % (leon[0][3] if not leon.is_empty() else "-"))
	level.queue_free()
	level = null
	change_scene_to_file("res://main_menu.tscn")
	await frames(10)
	var labels: Array = current_scene.first_button.get_parent().get_children().map(func(b): return b.text)
	check(labels == ["Subir Torre", "Entrar al Gauntlet", "Escalera al Cielo", "Opciones", "Salir"], "menú: %s" % [labels])
	check(current_scene.runner_material != null and F.RANKS[current_scene.RUN_RANK]["letter"] == "SSS", "el corredor usa el color de SSS")

	print("== Gauntlet por oleadas")
	current_scene._start("res://gauntlet.tscn")
	await frames(15)
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	spawner = current_scene.get_node("BossSpawner")
	check(director != null and director.phase == director.Phase.WAVE and spawner.bosses.is_empty(), "empieza con una oleada, sin guardián")
	var first_wave: int = director.enemies.size()
	check(first_wave >= 3, "oleada 1: %d enemigos" % first_wave)
	await frames(30)
	check(director.counter_label.text.contains("OLEADA 1") and director.counter_label.text.contains("ENEMIGOS: %d" % first_wave), "junto al reloj: %s" % director.counter_label.text)
	check(director.phase == director.Phase.WAVE, "no pasa al guardián con enemigos vivos")
	for round_index in range(2):
		for enemy in director.enemies:
			if is_instance_valid(enemy):
				enemy.take_hit(Vector2.ZERO, 1, 999)
		await frames(5)
		check(director.phase == director.Phase.BOSS_INTRO, "ronda %d: con todos muertos se prepara el guardián" % (round_index + 1))
		await frames(170)
		check(director.phase == director.Phase.BOSS and not spawner.bosses.is_empty(), "aparece el guardián (%d)" % spawner.bosses.size())
		for boss in spawner.bosses:
			boss.take_hit(Vector2.ZERO, 1, 9999)
		await frames(130)
		check(director.phase == director.Phase.PORTALS and director.portals.size() == 2, "al ganar, dos portales")
		var demo: Node = get_first_node_in_group(&"demo_complete")
		check(not demo.root_control.visible, "todavía sin pantalla de fin")
		if round_index == 0:
			var right_portal: Node2D = director.portals.filter(func(p): return p.label_text == "SEGUIR")[0]
			check(right_portal.global_position.x > director.portals.filter(func(p): return p.label_text == "TERMINAR")[0].global_position.x, "SEGUIR a la derecha, TERMINAR a la izquierda")
			right_portal.entered.emit()
			await frames(5)
			check(director.round_number == 2 and director.phase == director.Phase.WAVE and director.enemies.size() > first_wave, "SEGUIR: ronda 2 con más enemigos (%d)" % director.enemies.size())
		else:
			director.portals.filter(func(p): return p.label_text == "TERMINAR")[0].entered.emit()
			await frames(5)
			check(demo.root_control.visible and demo.continue_button.text == "Menú principal" and demo.message_label.text.contains("2"), "TERMINAR: pantalla de fin con medallas (%s)" % demo.message_label.text)
	paused = false

	print("== Gauntlet: morir termina la partida")
	change_scene_to_file("res://gauntlet.tscn")
	await frames(15)
	director = get_first_node_in_group(&"gauntlet_director")
	player = get_first_node_in_group(&"player")
	check(not player.respawn_enabled, "la tecla de reinicio está desactivada")
	player.take_damage(999, player.global_position + Vector2(40, 0))
	await frames(5)
	check(player.dead, "Rengar muere")
	Input.action_press("respawn")
	await frames(2)
	Input.action_release("respawn")
	check(player.dead, "R no lo revive (sin checkpoint)")
	var end_demo: Node = get_first_node_in_group(&"demo_complete")
	check(not end_demo.root_control.visible, "la pantalla no sale al instante")
	await frames(170)
	var end_buttons: Array = end_demo.continue_button.get_parent().get_children().filter(func(b): return not b.is_queued_for_deletion()).map(func(b): return b.text)
	check(end_demo.root_control.visible and end_demo.title_label.text == "FIN DEL GAUNTLET" and end_demo.message_label.text == "Oleadas sobrevividas: 0", "tras un momento: %s / %s" % [end_demo.title_label.text, end_demo.message_label.text])
	check(end_buttons == ["Empezar de nuevo", "Menú principal"], "botones: %s" % [end_buttons])
	end_demo.restart_scene()
	await frames(15)
	player = get_first_node_in_group(&"player")
	check(current_scene.scene_file_path == "res://gauntlet.tscn" and not player.dead and not paused, "Empezar de nuevo recarga el Gauntlet")

	print("== Escalera al Cielo")
	change_scene_to_file("res://sky_stairs.tscn")
	await frames(15)
	player = get_first_node_in_group(&"player")
	var spawners := current_scene.find_children("*", "", true, false).filter(func(n): return n.has_method("spawn_round"))
	check(spawners.is_empty() and get_nodes_in_group(&"boss").is_empty(), "sin guardianes ni combate")
	var flyers := get_nodes_in_group(&"training_dummies")
	check(flyers.size() >= 20 and flyers.all(func(d): return d.aerial and d.shoot_interval <= 0.0), "solo voladores para rebotar (%d)" % flyers.size())
	var sun: Node2D = current_scene.get_node("Sun")
	check(sun.goal_style == "sun", "al final, el sol")
	player.global_position = sun.global_position + Vector2(-250, -2)
	await frames(10)
	Input.action_press("move_right")
	for i in range(120):
		await frames(1)
		if not player.is_physics_processing():
			break
	Input.action_release("move_right")
	await frames(260)
	var final_demo: Node = get_first_node_in_group(&"demo_complete")
	check(final_demo.root_control.visible and final_demo.title_text == "ESCALERA AL CIELO" and final_demo.continue_button.text == "Menú principal", "al fundirse con el sol: etapa completada")
	paused = false

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
