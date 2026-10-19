extends SceneTree

# Música (INFUSE en el menú que sigue en la partida y rotación sin las canciones con copyright),
# vibración del mando y visor de inputs.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_ajustes.gd

var fails := 0
var checks := 0

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func check(c: bool, label: String) -> void:
	checks += 1
	print("  OK   " if c else "  FAIL ", label)
	if not c:
		fails += 1

func _run() -> void:
	var music: AudioStreamPlayer = root.get_node("Music")
	var rumble: Node = root.get_node("Rumble")
	var viewer: CanvasLayer = root.get_node("InputViewer")
	var hints: Node = root.get_node("InputHints")
	var sfx: Node = root.get_node("Sfx")

	print("== Música")
	var banned := ["big_blue", "dream_land", "mute_city", "rude_buster", "testing_song"]
	var clean := true
	for track in music.tracks:
		for name in banned:
			clean = clean and not track.begins_with(name)
	check(clean and music.tracks.size() >= 4 and music.MENU_TRACK in music.tracks, "rotación sin canciones con copyright: %s" % str(music.tracks))
	music.stop()
	music.current = ""
	var menu: Node = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames(5)
	check(music.playing and music.current == music.MENU_TRACK, "el menú pone INFUSE (%s)" % music.current)
	var position_before: float = music.get_playback_position()
	menu.queue_free()
	var level: Node = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	check(music.playing and music.current == music.MENU_TRACK, "al empezar la partida sigue sonando INFUSE")
	music.finished.emit()
	await frames(2)
	check(music.playing and music.current != music.MENU_TRACK and music.current in music.tracks, "al terminar pasa a otra al azar (%s)" % music.current)
	var seen := {}
	for i in range(30):
		var previous: String = music.current
		music._play_next()
		seen[music.current] = true
		if music.current == previous:
			seen["repetida"] = true
	check(not seen.has("repetida") and seen.has(music.MENU_TRACK), "nunca repite la misma seguida y INFUSE vuelve a salir")

	print("== Vibración del mando")
	rumble.enabled = true
	rumble.last_pattern = ""
	hints.device = hints.Device.JOYPAD
	sfx.play("hit_heavy")
	check(rumble.last_pattern == "hit_heavy", "con mando, un golpe pesado vibra")
	rumble.last_pattern = ""
	hints.device = hints.Device.KEYBOARD
	sfx.last_played.clear()
	sfx.play("hit_heavy")
	check(rumble.last_pattern == "", "con teclado no")
	rumble.enabled = false
	hints.device = hints.Device.JOYPAD
	sfx.last_played.clear()
	sfx.play("hurt")
	check(rumble.last_pattern == "", "ni con la vibración desactivada en Opciones")
	rumble.enabled = true
	sfx.last_played.clear()
	sfx.play("step")
	check(rumble.last_pattern == "", "los pasos no vibran")

	print("== Visor de inputs")
	viewer.set_enabled(true)
	hints.device = hints.Device.JOYPAD
	hints.device_changed.emit()
	await frames(3)
	check(viewer.visible and viewer.panel.size == viewer.PAD_SIZE, "con mando muestra el mando (%s)" % str(viewer.panel.size))
	hints.device = hints.Device.KEYBOARD
	hints.device_changed.emit()
	await frames(3)
	check(viewer.panel.size == viewer.KEYS_SIZE, "con teclado, las teclas")
	var screen: Vector2 = viewer.get_viewport().get_visible_rect().size
	check(viewer.panel.position.x + viewer.panel.size.x > screen.x - 30.0 and viewer.panel.position.x > screen.x * 0.5 and viewer.panel.position.y + viewer.panel.size.y > screen.y - 30.0, "abajo a la derecha")
	viewer.set_enabled(false)
	check(not viewer.visible, "y se oculta al desactivarlo")

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
