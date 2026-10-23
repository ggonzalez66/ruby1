extends SceneTree

var checks := 0
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func ui_frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func _run() -> void:
	change_scene_to_file("res://gauntlet.tscn")
	await frames(12)
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.set_physics_process(false)
	director.round_number = 3
	director._start_wave()
	await frames(3)
	var chaser: Node2D
	var hawk: Node2D
	var shooter: Node2D
	var shield: Node2D
	for enemy in director.enemies:
		var script_path: String = enemy.get_script().resource_path
		check(enemy.ruby_core.spawn_grace_left > 1.8 and enemy.ruby_core.holds_actor(), "%s aparece con dos segundos de preparación" % script_path.get_file())
		match script_path.get_file():
			"chaser_dummy.gd":
				if chaser == null:
					chaser = enemy
			"hawk.gd": hawk = enemy
			"training_dummy.gd": shooter = enemy
			"shield_bearer.gd": shield = enemy
	check(chaser != null and hawk != null and shooter != null and shield != null, "la preparación cubre los cuatro tipos de enemigo")
	player.position = chaser.global_position + Vector2(30, -2)
	hawk.position = player.position + Vector2(0, -200)
	hawk.home = hawk.position
	var health: int = player.current_health
	var shot_time: float = shooter.shoot_timer
	await frames(60)
	check(chaser.state == chaser.State.IDLE and hawk.state == hawk.State.PATROL and is_equal_approx(shooter.shoot_timer, shot_time), "durante la preparación no persiguen, se lanzan ni preparan disparos")
	check(player.current_health == health and get_nodes_in_group(&"projectiles").is_empty(), "no golpean al aparecer aunque Viridy esté al lado")
	check(director.counter_label.text.contains("PREPARACIÓN"), "el HUD muestra el tiempo de preparación")
	await frames(80)
	check(chaser.ruby_core.spawn_grace_left == 0.0 and chaser.state != chaser.State.IDLE and hawk.state != hawk.State.PATROL, "al terminar el margen vuelven a detectar y combatir")
	director._clear_wave()
	director.phase = director.Phase.BOSS_INTRO
	director.phase_timer = 0.0
	await frames(3)
	var bosses: Array = current_scene.get_node("BossSpawner").bosses
	check(not bosses.is_empty(), "aparecen los guardianes")
	for boss in bosses:
		check(boss.ruby_core.spawn_grace_left > 1.8 and not boss.combat_started, "los guardianes también tienen preparación al aparecer")
	current_scene.get_node("BossSpawner").clear_bosses()
	director.phase = director.Phase.BOSS
	director.on_bosses_defeated()
	await frames(30)
	var portal: Area2D = director.portals.filter(func(p): return p.label_text == "TERMINAR")[0]
	check(portal.confirm_finish, "el portal de terminar requiere confirmación")
	player.position = portal.position + Vector2(0, -2)
	await frames(4)
	check(portal.confirmation != null and paused and not portal.used, "caer físicamente en TERMINAR solo abre el diálogo y pausa")
	check(director.phase == director.Phase.PORTALS and not root.get_node("RunSession").finished, "la run sigue activa hasta confirmar")
	check(root.gui_get_focus_owner() == portal.cancel_button, "Seguir jugando tiene el foco por defecto")
	var elapsed: float = root.get_node("RunSession").elapsed
	await ui_frames(8)
	check(is_equal_approx(root.get_node("RunSession").elapsed, elapsed), "el cronómetro se detiene mientras decides")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape)
	await ui_frames()
	check(portal.confirmation == null and not paused and not portal.used, "Escape cancela y reanuda sin consumir el portal")
	portal._on_body_entered(player)
	await ui_frames()
	check(portal.confirmation == null, "no vuelve a abrirse mientras sigues dentro del portal")
	portal._on_body_exited(player)
	portal._on_body_entered(player)
	await ui_frames()
	check(portal.confirmation != null, "tras salir y volver a entrar se puede decidir otra vez")
	portal.cancel_button.pressed.emit()
	check(portal.confirmation == null and not paused, "el botón Seguir jugando también cancela")
	portal._on_body_exited(player)
	portal._on_body_entered(player)
	await ui_frames()
	portal.finish_button.pressed.emit()
	var confirmed_used: bool = portal.used
	await ui_frames()
	check(confirmed_used and director.phase == director.Phase.DONE and root.get_node("RunSession").finished, "solo Terminar run confirma el final")
	var screen: Node = get_first_node_in_group(&"demo_complete")
	check(screen.root_control.visible, "la confirmación abre los resultados")
	paused = false
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
