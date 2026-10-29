extends SceneTree

var checks := 0
var fails := 0

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

func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await frames(8)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.global_position = Vector2(2300, -2)
	await frames(4)
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(2700, -2)
	current_scene.add_child(boss)
	boss.set_physics_process(false)
	var core: Node2D = boss.ruby_core

	print("== Ruby: vida dentro, postura en el perímetro")
	var radius: float = core.core_radius()
	check(radius > 11.0 and core.health_polygon(radius, 0.0).is_empty(), "Ruby más grande y sin relleno claro a cero de vida")
	for ratio in [0.25, 0.5, 0.75, 1.0]:
		var polygon: PackedVector2Array = core.health_polygon(radius, ratio)
		var top := radius
		for point in polygon:
			top = minf(top, point.y)
		check(is_equal_approx(top, radius * (1.0 - ratio * 2.0)), "el relleno rojo conserva el %.0f%% inferior" % (ratio * 100.0))
	core.register_parry(100)
	var outline: PackedVector2Array = core.posture_outline(radius + 5.0, core.posture / core.POSTURE_MAX)
	var length := 0.0
	for i in range(1, outline.size()):
		length += outline[i - 1].distance_to(outline[i])
	var full_length := Vector2((radius + 5.0) * 0.65, radius + 5.0).length() * 4.0
	check(is_equal_approx(length / full_length, 2.0 / 3.0), "un parry consume un tercio del perímetro amarillo")
	core.register_parry(101)
	core.register_parry(102)
	check(core.is_open() and core.posture_outline(radius, core.posture / core.POSTURE_MAX).size() == 1, "tres parries vacían el contorno y abren el núcleo")
	boss.reset_dummy()

	print("== Giros: avance, dirección fijada y proyección de la espada")
	for plane in [boss.SpinPlane.VERTICAL, boss.SpinPlane.HORIZONTAL]:
		boss.position = Vector2(2700, -2)
		player.position = Vector2(2300, -2)
		boss._start_super_windup(plane)
		var direction: int = boss.facing
		player.position.x = 3000
		boss._boss_process(0.2, player)
		check(boss.facing == direction and boss.spin_direction == direction, "giro %d: cruzar al jefe durante el aviso no cambia su dirección" % plane)
		boss._start_super_spin()
		var before: float = boss.position.x
		boss._boss_process(0.1, player)
		check(is_equal_approx(boss.position.x - before, direction * boss.super_advance_speed * 0.1) and boss.facing == direction, "giro %d: avanza despacio en la dirección anunciada" % plane)
		var rendered: Vector2 = boss.sword_pivot.to_global(Vector2(boss.BLADE_LENGTH, 0))
		var collision_tip: Vector2 = boss.visual.to_global(boss._spin_tip(boss.spin_angle))
		check(rendered.distance_to(collision_tip) < 0.01, "giro %d: dibujo y segmento del parry coinciden" % plane)
		var vertical_tip: Vector2 = boss._spin_tip(PI * 0.5) - boss._spin_pivot_position()
		check(is_equal_approx(vertical_tip.y, boss.BLADE_LENGTH * boss._spin_depth()), "giro %d: plano de giro y alcance vertical coherentes" % plane)
		boss._end_super_spin()
		check(boss.sword_pivot.scale.is_equal_approx(Vector2.ONE) and boss.sword_pivot.z_index == 0, "giro %d: la espada recupera su transformación normal" % plane)
		boss.reset_dummy()
		player.position = boss.position + Vector2(80, 0)
		player.current_health = player.max_health
		player.invulnerability_timer = 0.0
		boss._start_super_windup(plane)
		boss._start_super_spin()
		for tick in range(15):
			boss._boss_process(0.05, player)
			if player.current_health < player.max_health:
				break
		check(player.current_health < player.max_health, "giro %d: la hoja proyectada puede golpear al jugador real" % plane)
		boss.reset_dummy()

	print("== Combo: capas y espejo independiente del facing")
	for direction in [-1, 1]:
		player.facing = direction
		player._update_facing_visual()
		for hit in [1, 2, 3]:
			player.light_combo_step = hit
			player.attack_timer = 0.08
			player._effect_claw_slash()
			check(player.claw_slash_sprite.z_index > 0 and player.claw_slash_sprite.flip_h == (hit == 3), "lado %d, hit %d: slash delante y espejo solo en el remate" % [direction, hit])
	player._effect_charged_lunge()
	check(not player.claw_slash_sprite.flip_h and player.claw_slash_sprite.z_index < 0, "el dash limpia el espejo y conserva la mano visible")
	player._cancel_all_states()
	player._respawn_player()
	player.position = Vector2(2300, -2)
	await frames(5)

	print("== Hexágonos de parry y transición al Metatrón")
	player._start_roar()
	player._update_roar_aura()
	var center: Vector2 = player.get_roar_center()
	check(player.roar_aura.visible and player.roar_aura.formation == 0.0 and player.roar_aura.rotation == 0.0 and player._is_roar_invincible(), "el inicio muestra los hexágonos con el parry activo")
	check(player.parry_reaches(center + Vector2(player.roar_radius - 1.0, -3), center + Vector2(player.roar_radius - 1.0, 3)), "el contorno conserva el radio real del parry")
	var covered := true
	var parry_hexagon: PackedVector2Array = player.roar_aura.parry_outline()
	for angle in range(36):
		covered = covered and Geometry2D.is_point_in_polygon(Vector2.from_angle(TAU * angle / 36.0) * (player.roar_radius - 0.01), parry_hexagon)
	check(covered and parry_hexagon.size() == 7, "el hexágono de contorno rodea toda la cobertura circular")
	player.roar_elapsed = player.roar_explosive_duration - 0.001
	player._update_roar_aura()
	check(player.roar_aura.formation == 0.0, "los hexágonos permanecen completos durante toda la ventana de parry")
	player.roar_elapsed = 0.30
	player.roar_explosive_timer = 0.0
	player._update_roar_aura()
	check(player.roar_aura.formation == 1.0 and player.roar_aura.rotation > 0.0 and player.roar_aura.modulate.a < 0.5 and not player._is_roar_invincible(), "después aparece el Metatrón translúcido y giratorio sin extender i-frames")
	player._end_roar()

	print("== Select: taunt, no reinicio")
	player.current_health = 81
	Input.action_press("taunt")
	await frames(2)
	check(player.proud_active and player.proud_roar_timer > 0 and player.current_health == 81, "Select activa la pose orgullosa inmediatamente sin reiniciar")
	Input.action_release("taunt")
	await frames(2)
	check(player.proud_active, "al soltar Select continúa la pose")
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	check(not player.proud_active, "moverse cancela el taunt sin bloqueo de acciones")

	print("== Pausa: checkpoint y etapa completa")
	var menu: CanvasLayer = current_scene.get_node("PauseMenu")
	player.spawn_position = Vector2(2400, -2)
	player.position = Vector2(2500, -2)
	menu._open()
	check(paused and menu.checkpoint_button.visible and menu.restart_stage_button.visible, "en torre la pausa ofrece ambos reinicios")
	menu._restart_checkpoint()
	check(not paused and player.position == Vector2(2400, -2) and player.current_health == player.max_health, "checkpoint restaura posición guardada y vida")
	var scene_path: String = current_scene.scene_file_path
	menu._open()
	menu._restart_stage()
	await frames(8)
	player = get_first_node_in_group(&"player")
	check(current_scene.scene_file_path == scene_path and player.spawn_position != Vector2(2400, -2), "reiniciar etapa recarga el mapa y elimina el checkpoint anterior")
	check(root.get_node("RunSession").elapsed < 0.3, "reiniciar etapa inicia un cronómetro nuevo")
	change_scene_to_file("res://gauntlet.tscn")
	await frames(8)
	menu = current_scene.get_node("PauseMenu")
	menu._open()
	check(not menu.checkpoint_button.visible and menu.restart_stage_button.visible, "Gauntlet ofrece reiniciar etapa, sin checkpoint")
	menu._resume()
	print("== Migración de controles guardados")
	var had_settings := FileAccess.file_exists(menu.SETTINGS_PATH)
	var previous_settings := FileAccess.get_file_as_string(menu.SETTINGS_PATH) if had_settings else ""
	var legacy := ConfigFile.new()
	legacy.set_value("input", "version", 3)
	legacy.set_value("keyboard", "attack", [KEY_K])
	legacy.set_value("joypad", "respawn", ["b:4"])
	legacy.save(menu.SETTINGS_PATH)
	menu._load_settings()
	check(InputMap.action_get_events("attack").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_K), "migrar mantiene una tecla de ataque personalizada")
	check(InputMap.action_get_events("taunt").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_BACK), "Select pasa a taunt al cargar controles antiguos")
	menu._save_settings()
	legacy.load(menu.SETTINGS_PATH)
	check(legacy.get_value("input", "version") == menu.INPUT_VERSION and not InputMap.has_action("respawn"), "se guarda la versión nueva sin acción directa de reinicio")
	legacy.set_value("input", "version", 5)
	legacy.set_value("joypad", "slow_motion", ["b:10"])
	legacy.save(menu.SETTINGS_PATH)
	menu._load_settings()
	check(not InputMap.action_get_events("slow_motion").any(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion), "Migrar v5 libera mando de cámara lenta")
	check(InputMap.action_get_events("weapon_throw").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_SHOULDER), "Migrar v5 asigna RB a lanzamiento")
	if had_settings:
		var restored := FileAccess.open(menu.SETTINGS_PATH, FileAccess.WRITE)
		restored.store_string(previous_settings)
		restored.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.SETTINGS_PATH))
	root.get_node("RunSession")._clear_run()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
