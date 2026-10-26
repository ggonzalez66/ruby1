extends SceneTree

var checks := 0
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func ui_press(action: String) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER if action == "ui_accept" else KEY_ESCAPE
	event.physical_keycode = event.keycode
	event.pressed = true
	root.push_input(event)
	await frames(2)
	event.pressed = false
	root.push_input(event)
	await frames(7)

func release_movement() -> void:
	for action in ["move_left", "move_right", "jump", "dash"]:
		Input.action_release(action)

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var session: Node = root.get_node("RunSession")
	var previous_storage: String = session.storage_directory
	session.storage_directory = "user://sanctuary_records_test"
	print("== Entrada desde el menú con input de interfaz")
	change_scene_to_file("res://main_menu.tscn")
	await frames(10)
	var button: Button
	for item in current_scene.first_button.get_parent().get_children():
		if item.text == "Level Testing":
			button = item
	check(button != null, "Level Testing aparece en el menú principal")
	check(button.get_global_rect().end.y <= root.size.y and current_scene.first_button.get_parent().get_children()[-1].get_global_rect().end.y <= root.size.y, "las siete opciones caben en la ventana")
	button.grab_focus()
	await ui_press("ui_accept")
	check(current_scene.scene_file_path == "res://level_testing.tscn", "aceptar abre el selector de etapas")
	if current_scene.scene_file_path != "res://level_testing.tscn":
		quit(1)
		return
	check(current_scene.level_buttons.size() == 1 and current_scene.level_buttons[0].text.begins_with("Santuario"), "el selector presenta el santuario")
	check(not session.running and not session.countdown_active, "el selector no inicia un modo cronometrado")
	await ui_press("ui_accept")
	await frames(25)
	check(current_scene.scene_file_path == "res://sanctuary.tscn", "aceptar carga el santuario jugable")
	if current_scene.scene_file_path != "res://sanctuary.tscn":
		quit(1)
		return
	var sanctuary: Node2D = current_scene
	var player: CharacterBody2D = sanctuary.player
	check(player.is_on_floor() and player.position.distance_to(sanctuary.SPAWN) < 15, "Viridy aparece sobre la isla del Árbol Madre")
	check(not session.running and not session.countdown_active and session.samples.is_empty(), "la exploración no crea cuenta atrás, grabación ni récord")
	check(get_nodes_in_group(&"ruby_enemies").is_empty(), "el santuario permite explorar sin enemigos")
	print("== Movilidad real sin cambios al jugador")
	var health: int = player.current_health
	var origin := player.position
	Input.action_press("move_right")
	await frames(16)
	check(player.position.x > origin.x + 50, "el input de movimiento desplaza a Viridy")
	Input.action_press("jump")
	await frames(6)
	check(player.velocity.y < 0 and player.position.y < origin.y - 20, "se conserva el salto desde la isla")
	Input.action_release("jump")
	await frames(5)
	Input.action_press("jump")
	await frames(3)
	check(player.velocity.y < 0 and player.air_jumps_remaining == 0, "se conserva el salto aéreo para recorrer las ramas")
	release_movement()
	player._respawn_player()
	player.position = Vector2(2300, 100)
	await frames(45)
	check(player.is_on_floor() and absf(player.position.y - 260) < 5 and player.current_health == health, "la laguna tiene un fondo seguro y no inflige daño")
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(90)
	release_movement()
	check(player.position.x < 1900 and player.position.y < 80 and player.current_health == health, "se puede salir del agua por la orilla usando la movilidad normal")
	player._respawn_player()
	player.position = Vector2(1168, -2)
	Input.action_press("move_right")
	await frames(10)
	check(player.is_on_wall(), "las rocas del circuito tienen colisión para trepar")
	var wall_position := player.position
	Input.action_press("jump")
	await frames(6)
	check(player.position.y < wall_position.y - 20, "el salto junto a la pared permite subir por las rocas")
	release_movement()
	for point in [Vector2(35, -52), Vector2(6365, -82)]:
		player._respawn_player()
		player.position = point
		var action := "move_left" if point.x < 100 else "move_right"
		Input.action_press(action)
		await frames(35)
		Input.action_release(action)
		check(current_scene == sanctuary and player.position.x >= 0 and player.position.x <= 6400, "los límites contienen al jugador sin avanzar de etapa: %s" % action)
	player.position = Vector2(3000, 900)
	await frames(4)
	check(player.position.distance_to(sanctuary.SPAWN) < 20, "una caída fuera del recinto recupera al jugador en el árbol")
	print("== Pausa, reinicio y navegación de vuelta")
	await ui_press("pause")
	check(paused and sanctuary.pause_menu.restart_stage_button.visible, "la pausa permite reiniciar esta etapa de prueba")
	var return_button: Button
	for item in sanctuary.pause_menu.main_page.get_children():
		if item is Button and item.text == "Level Testing":
			return_button = item
	check(return_button != null, "la pausa ofrece volver al selector de pruebas")
	sanctuary.pause_menu.restart_stage_button.pressed.emit()
	await frames(20)
	check(not paused and current_scene.scene_file_path == "res://sanctuary.tscn" and get_nodes_in_group(&"player").size() == 1, "reiniciar recarga solo el santuario y mantiene un único jugador")
	current_scene.pause_menu._open()
	for item in current_scene.pause_menu.main_page.get_children():
		if item is Button and item.text == "Level Testing":
			item.grab_focus()
	await ui_press("ui_accept")
	check(not paused and current_scene.scene_file_path == "res://level_testing.tscn", "aceptar en pausa vuelve al selector sin dejar el juego pausado")
	await ui_press("ui_cancel")
	check(current_scene.scene_file_path == "res://main_menu.tscn", "cancelar en el selector vuelve al menú principal")
	check(not DirAccess.dir_exists_absolute(session.storage_directory), "las pruebas del santuario no escriben archivos de récords")
	session.storage_directory = previous_storage
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
