extends CanvasLayer

# Menú de pausa (Esc / Start): reanudar, volumen de música, tutoriales sí/no y remapeo de teclado y mando.
# Funciona con el juego pausado. Los ajustes se guardan en user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const TUTORIAL_SIGN := preload("res://tutorial_sign.gd")
const MAIN_MENU := "res://main_menu.tscn"
# Al cambiar el esquema por defecto se sube la versión: los controles guardados con una
# versión anterior se ignoran (el volumen sí se conserva). Se migran las versiones 2 y 3:
# Select pasa a taunt y, desde la 2, "Lanza jade / Soul pull" vuelve a LT.
const INPUT_VERSION := 4
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

const OVERLAY_COLOR := Color(0.01, 0.04, 0.03, 0.62)
const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.95)
const PANEL_BORDER := Color(0.55, 0.82, 0.45, 0.9)
const BUTTON_COLOR := Color(0.1, 0.2, 0.15)
const BUTTON_HOVER := Color(0.17, 0.33, 0.23)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
const WAITING_COLOR := Color(1.0, 0.85, 0.4)

enum Device { KEYBOARD, JOYPAD }

# En el menú principal solo se usa su página de opciones: no pausa ni se abre con Pausa, y al volver
# de las opciones se cierra (señal closed).
signal closed
@export var menu_mode := false
@export var testing_mode := false

# Acciones que se pueden remapear, en el orden en que aparecen.
const REMAP_ACTIONS := [
	["move_left", "Izquierda"], ["move_right", "Derecha"], ["move_up", "Arriba"], ["move_down", "Abajo"],
	["jump", "Saltar"], ["attack", "Ataque ligero"], ["heavy_attack", "Ataque pesado"], ["dash", "Dash / correr"],
	["throw_knife", "Lanza jade / Soul pull"], ["roar", "Rugido"], ["pause", "Pausa"], ["taunt", "Taunt / pose orgullosa"],
	["toggle_hitbox_visuals", "Ver hitboxes"], ["frame_pause", "Pausa de frame"], ["slow_motion", "Cámara lenta"],
]
# En el mando, el stick izquierdo de estas acciones es fijo: el remapeo cambia el botón (d-pad).
const STICK_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const JOY_BUTTON_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Select", 5: "Guide", 6: "Start", 7: "L3", 8: "R3",
	9: "LB", 10: "RB", 11: "D-pad ↑", 12: "D-pad ↓", 13: "D-pad ←", 14: "D-pad →",
}
const MOUSE_BUTTON_NAMES := {1: "Clic izquierdo", 2: "Clic derecho", 3: "Clic central", 4: "Rueda ↑", 5: "Rueda ↓", 8: "Botón lateral 1", 9: "Botón lateral 2"}
const JOY_AXIS_NAMES := {0: "Stick izq. X", 1: "Stick izq. Y", 2: "Stick der. X", 3: "Stick der. Y", 4: "LT", 5: "RT"}

var root_control: Control
var main_page: VBoxContainer
var options_page: VBoxContainer
var remap_page: VBoxContainer
var remap_title: Label
var remap_rows: VBoxContainer
var resume_button: Button
var checkpoint_button: Button
var restart_stage_button: Button
var music_slider: HSlider
var music_value_label: Label
var sfx_slider: HSlider
var sfx_value_label: Label
var tutorials_button: Button
var vibration_button: Button
var input_viewer_button: Button
var fill_ferocity_button: Button
# Pausa de frame (P): congela el juego justo donde está, sin menú, para inspeccionar ese frame
# (con H se ven las hitboxes). Otra P lo reanuda.
var frame_paused := false
var frame_label: Label
# Cámara lenta (RB por defecto): todo el juego a TimeControl.SLOW_SCALE hasta volver a pulsarlo.
var slow_label: Label

var remap_device := Device.KEYBOARD
var waiting_action := ""
var waiting_button: Button
var row_buttons := {}
var default_events := {}

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store_default_events()
	_build()
	_load_settings()
	root_control.visible = false

func _input(event: InputEvent) -> void:
	# Mientras espera una tecla/botón para remapear, se queda con la siguiente pulsación.
	if waiting_action == "":
		return
	var captured := _capture_event(event)
	if captured == null:
		return
	get_viewport().set_input_as_handled()
	if captured is InputEventKey and captured.physical_keycode == KEY_ESCAPE and remap_device == Device.JOYPAD:
		_stop_waiting()
		return
	if captured is InputEventKey and captured.physical_keycode == KEY_ESCAPE and remap_device == Device.KEYBOARD and waiting_action != "pause":
		_stop_waiting()
		return
	_assign_event(waiting_action, captured)
	_stop_waiting()
	_refresh_row_texts()
	_save_settings()

func _refresh_row_texts() -> void:
	# Otras filas pueden haber perdido su tecla/botón al resolver un conflicto.
	for action in row_buttons:
		var button: Button = row_buttons[action]
		if is_instance_valid(button):
			button.text = _binding_text(action)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().has_group(&"gauntlet_finish_confirmation"):
		return
	if RunSession.countdown_active or (is_instance_valid(RunSession.records_panel) and RunSession.records_panel.visible):
		return
	if menu_mode:
		_menu_mode_input(event)
		return
	if event.is_action_pressed("frame_pause") and not root_control.visible:
		get_viewport().set_input_as_handled()
		_toggle_frame_pause()
		return
	if event.is_action_pressed("slow_motion") and not root_control.visible:
		get_viewport().set_input_as_handled()
		TimeControl.toggle()
		return
	if frame_paused and event.is_action_pressed("toggle_hitbox_visuals"):
		# Con el juego congelado Rengar no procesa entradas: las hitboxes se cambian desde aquí.
		get_viewport().set_input_as_handled()
		var player := get_tree().get_first_node_in_group(&"player")
		if player and player.has_method("toggle_hitbox_debug"):
			player.toggle_hitbox_debug()
		return
	var back: bool = event.is_action_pressed("pause") or (get_tree().paused and event.is_action_pressed("ui_cancel"))
	if not back:
		return
	get_viewport().set_input_as_handled()
	if not get_tree().paused or frame_paused:
		_open()
	elif remap_page.visible:
		_show_options_page()
	elif options_page.visible:
		_show_main_page()
	else:
		_resume()

func _menu_mode_input(event: InputEvent) -> void:
	if not root_control.visible or not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if remap_page.visible:
		_show_options_page()
	else:
		_show_main_page()

func open_options() -> void:
	root_control.visible = true
	_show_options_page()

func _on_slow_motion_changed(slow: bool) -> void:
	slow_label.visible = slow and not menu_mode

func _toggle_frame_pause() -> void:
	frame_paused = not frame_paused
	get_tree().paused = frame_paused
	frame_label.visible = frame_paused

func _open() -> void:
	frame_paused = false
	frame_label.visible = false
	get_tree().paused = true
	root_control.visible = true
	_show_main_page()

func _resume() -> void:
	root_control.visible = false
	get_tree().paused = false

func _restart_checkpoint() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if not is_instance_valid(player) or not player.respawn_enabled:
		return
	_resume()
	player._respawn_player()

func _restart_stage() -> void:
	_resume()
	RunSession._clear_run()
	Engine.time_scale = TimeControl.base_scale()
	get_tree().reload_current_scene()

func _go_to_main_menu() -> void:
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	get_tree().change_scene_to_file(MAIN_MENU)

func _go_to_level_testing() -> void:
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	get_tree().change_scene_to_file("res://level_testing.tscn")

func _show_main_page() -> void:
	if menu_mode:
		_stop_waiting()
		root_control.visible = false
		closed.emit()
		return
	options_page.visible = false
	remap_page.visible = false
	main_page.visible = true
	var player := get_tree().get_first_node_in_group(&"player")
	checkpoint_button.visible = is_instance_valid(player) and player.respawn_enabled
	restart_stage_button.visible = testing_mode or (get_tree().current_scene != null and get_tree().current_scene.scene_file_path in RunSession.MODES)
	resume_button.grab_focus()

func _show_options_page() -> void:
	_stop_waiting()
	main_page.visible = false
	remap_page.visible = false
	options_page.visible = true
	fill_ferocity_button.visible = not menu_mode and get_tree().get_first_node_in_group(&"player") != null
	fill_ferocity_button.disabled = Ferocity.style_locked
	music_slider.grab_focus()

func _show_remap_page(device: Device) -> void:
	remap_device = device
	remap_title.text = "MAPEAR TECLADO" if device == Device.KEYBOARD else "MAPEAR CONTROL"
	options_page.visible = false
	remap_page.visible = true
	_rebuild_remap_rows()

# ---------- Construcción de la interfaz

func _build() -> void:
	frame_label = Label.new()
	frame_label.text = "PAUSA DE FRAME  ·  P reanuda  ·  H hitboxes"
	frame_label.add_theme_font_size_override("font_size", 16)
	frame_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	frame_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	frame_label.add_theme_constant_override("outline_size", 6)
	frame_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	frame_label.position = Vector2(-190, -40)
	frame_label.visible = false
	add_child(frame_label)
	slow_label = Label.new()
	slow_label.text = "CÁMARA LENTA  ×%s" % str(TimeControl.SLOW_SCALE)
	slow_label.add_theme_font_size_override("font_size", 16)
	slow_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	slow_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	slow_label.add_theme_constant_override("outline_size", 6)
	slow_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	slow_label.position = Vector2(-80, 64)
	slow_label.visible = TimeControl.slow_motion and not menu_mode
	add_child(slow_label)
	TimeControl.changed.connect(_on_slow_motion_changed)
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var overlay := ColorRect.new()
	overlay.color = OVERLAY_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, PANEL_BORDER, 24))
	center.add_child(panel)

	var pages := VBoxContainer.new()
	panel.add_child(pages)

	# Página principal.
	main_page = _page(pages)
	main_page.add_child(_title("PAUSA"))
	resume_button = _button("Reanudar", _resume)
	main_page.add_child(resume_button)
	checkpoint_button = _button("Reiniciar desde Checkpoint", _restart_checkpoint)
	main_page.add_child(checkpoint_button)
	restart_stage_button = _button("Reiniciar Etapa", _restart_stage)
	main_page.add_child(restart_stage_button)
	main_page.add_child(_button("Opciones", _show_options_page))
	if testing_mode:
		main_page.add_child(_button("Level Testing", _go_to_level_testing))
	main_page.add_child(_button("Menú principal", _go_to_main_menu))

	# Página de opciones.
	options_page = _page(pages)
	options_page.add_child(_title("OPCIONES"))
	options_page.add_child(_label("Sonido", 18, Color(0.7, 0.9, 0.62)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	options_page.add_child(row)
	var music_label := _label("Volumen música", 16, TEXT_COLOR)
	music_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(music_label)
	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_slider.value_changed.connect(_on_music_volume_changed)
	row.add_child(music_slider)
	music_value_label = _label("100%", 16, TEXT_COLOR)
	music_value_label.custom_minimum_size = Vector2(48, 0)
	music_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(music_value_label)
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	options_page.add_child(sfx_row)
	var sfx_label := _label("Volumen efectos", 16, TEXT_COLOR)
	sfx_label.custom_minimum_size = Vector2(130, 0)
	sfx_row.add_child(sfx_label)
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(sfx_slider)
	sfx_value_label = _label("100%", 16, TEXT_COLOR)
	sfx_value_label.custom_minimum_size = Vector2(48, 0)
	sfx_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(sfx_value_label)
	options_page.add_child(_label("Juego", 18, Color(0.7, 0.9, 0.62)))
	tutorials_button = _button("", _toggle_tutorials)
	options_page.add_child(tutorials_button)
	vibration_button = _button("", _toggle_vibration)
	options_page.add_child(vibration_button)
	input_viewer_button = _button("", _toggle_input_viewer)
	options_page.add_child(input_viewer_button)
	fill_ferocity_button = _button("Llenar ferocidad", Ferocity.fill_for_testing)
	fill_ferocity_button.visible = not menu_mode
	options_page.add_child(fill_ferocity_button)
	_refresh_tutorials_button()
	options_page.add_child(_label("Controles", 18, Color(0.7, 0.9, 0.62)))
	options_page.add_child(_button("Mapear teclado", _show_remap_page.bind(Device.KEYBOARD)))
	options_page.add_child(_button("Mapear control", _show_remap_page.bind(Device.JOYPAD)))
	options_page.add_child(_button("Volver", _show_main_page))

	# Página de remapeo (teclado o mando).
	remap_page = _page(pages)
	remap_title = _title("MAPEAR TECLADO")
	remap_page.add_child(remap_title)
	var hint := _label("Elige una acción y pulsa la nueva tecla, clic o botón (Esc cancela)", 13, Color(0.7, 0.85, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remap_page.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	remap_page.add_child(scroll)
	remap_rows = VBoxContainer.new()
	remap_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remap_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(remap_rows)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	remap_page.add_child(buttons)
	var reset := _button("Restablecer", _reset_device_defaults)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(reset)
	var back := _button("Volver", _show_options_page)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(back)

	options_page.visible = false
	remap_page.visible = false

func _rebuild_remap_rows() -> void:
	for child in remap_rows.get_children():
		child.queue_free()
	row_buttons.clear()
	var first: Button
	for entry in REMAP_ACTIONS:
		var action: String = entry[0]
		if remap_device == Device.JOYPAD and action in ["toggle_hitbox_visuals", "frame_pause"]:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		remap_rows.add_child(row)
		var name_label := _label(entry[1], 15, TEXT_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var binding := _button(_binding_text(action), Callable())
		binding.custom_minimum_size = Vector2(170, 32)
		binding.add_theme_font_size_override("font_size", 14)
		binding.pressed.connect(_start_waiting.bind(action, binding))
		row.add_child(binding)
		row_buttons[action] = binding
		if first == null:
			first = binding
	if first:
		first.grab_focus.call_deferred()

# ---------- Remapeo

func _start_waiting(action: String, button: Button) -> void:
	_stop_waiting()
	waiting_action = action
	waiting_button = button
	button.text = "Pulsa una tecla..." if remap_device == Device.KEYBOARD else "Pulsa un botón..."
	button.add_theme_color_override("font_color", WAITING_COLOR)

func _stop_waiting() -> void:
	if waiting_button and is_instance_valid(waiting_button):
		waiting_button.text = _binding_text(waiting_action)
		waiting_button.add_theme_color_override("font_color", TEXT_COLOR)
	waiting_action = ""
	waiting_button = null

func _capture_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey and event.pressed and not event.echo:
		if remap_device == Device.KEYBOARD or event.physical_keycode == KEY_ESCAPE:
			var key := InputEventKey.new()
			key.physical_keycode = event.physical_keycode
			return key
	if remap_device == Device.KEYBOARD and event is InputEventMouseButton and event.pressed:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		return mouse
	if remap_device != Device.JOYPAD:
		return null
	if event is InputEventJoypadButton and event.pressed:
		var button := InputEventJoypadButton.new()
		button.button_index = event.button_index
		return button
	if event is InputEventJoypadMotion and abs(event.axis_value) > 0.6:
		var motion := InputEventJoypadMotion.new()
		motion.axis = event.axis
		motion.axis_value = sign(event.axis_value)
		return motion
	return null

func _assign_event(action: String, new_event: InputEvent) -> void:
	# Quita esa misma tecla/botón de otras acciones para no tener dos acciones en el mismo input.
	for entry in REMAP_ACTIONS:
		var other: String = entry[0]
		for existing in InputMap.action_get_events(other):
			if _same_input(existing, new_event):
				InputMap.action_erase_event(other, existing)
	for existing in InputMap.action_get_events(action):
		if _is_remappable(action, existing):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, new_event)

func _is_remappable(action: String, event: InputEvent) -> bool:
	if remap_device == Device.KEYBOARD:
		return event is InputEventKey or event is InputEventMouseButton
	if event is InputEventJoypadMotion and action in STICK_ACTIONS and event.axis <= 1:
		return false
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
	return false

func _binding_text(action: String) -> String:
	var names := []
	for event in InputMap.action_get_events(action):
		if not _is_remappable(action, event):
			continue
		names.append(_event_name(event))
	var text := " / ".join(names) if not names.is_empty() else "—"
	if remap_device == Device.JOYPAD and action in STICK_ACTIONS:
		text += " (+ stick)"
	return text

func _event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)
	if event is InputEventMouseButton:
		return MOUSE_BUTTON_NAMES.get(event.button_index, "Ratón %d" % event.button_index)
	if event is InputEventJoypadButton:
		return JOY_BUTTON_NAMES.get(event.button_index, "Botón %d" % event.button_index)
	if event is InputEventJoypadMotion:
		var axis_name: String = JOY_AXIS_NAMES.get(event.axis, "Eje %d" % event.axis)
		if event.axis >= 4:
			return axis_name
		return "%s %s" % [axis_name, "+" if event.axis_value > 0.0 else "-"]
	return "?"

func _restore_joypad_default(action: String) -> void:
	# Deja la acción con sus botones de mando por defecto y se los quita a otras acciones que los usen.
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
			InputMap.action_erase_event(action, existing)
	for event in default_events[action]:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			for entry in REMAP_ACTIONS:
				for other in InputMap.action_get_events(entry[0]):
					if _same_input(other, event):
						InputMap.action_erase_event(entry[0], other)
			InputMap.action_add_event(action, event.duplicate())

func _store_default_events() -> void:
	for entry in REMAP_ACTIONS:
		var copies := []
		for event in InputMap.action_get_events(entry[0]):
			copies.append(event.duplicate())
		default_events[entry[0]] = copies

func _reset_device_defaults() -> void:
	_stop_waiting()
	for entry in REMAP_ACTIONS:
		var action: String = entry[0]
		for existing in InputMap.action_get_events(action):
			if _is_remappable(action, existing):
				InputMap.action_erase_event(action, existing)
		for event in default_events[action]:
			if _is_remappable(action, event):
				InputMap.action_add_event(action, event.duplicate())
	_rebuild_remap_rows()
	_save_settings()

# ---------- Volumen

func _on_music_volume_changed(value: float) -> void:
	_apply_music_volume(value / 100.0)
	music_value_label.text = "%d%%" % int(value)
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	_apply_bus_volume(SFX_BUS, value / 100.0)
	sfx_value_label.text = "%d%%" % int(value)
	Sfx.play("ui_move")
	_save_settings()

func _toggle_tutorials() -> void:
	TUTORIAL_SIGN.enabled = not TUTORIAL_SIGN.enabled
	_refresh_tutorials_button()
	_save_settings()

func _refresh_tutorials_button() -> void:
	tutorials_button.text = "Tutoriales: %s" % ("Sí" if TUTORIAL_SIGN.enabled else "No")
	vibration_button.text = "Vibración del mando: %s" % ("Sí" if Rumble.enabled else "No")
	input_viewer_button.text = "Visor de inputs: %s" % ("Sí" if InputViewer.enabled else "No")

func _toggle_vibration() -> void:
	Rumble.enabled = not Rumble.enabled
	if Rumble.enabled:
		Rumble.pulse(0.4, 0.4, 0.15, "prueba")
	_refresh_tutorials_button()
	_save_settings()

func _toggle_input_viewer() -> void:
	InputViewer.set_enabled(not InputViewer.enabled)
	_refresh_tutorials_button()
	_save_settings()

func _apply_music_volume(linear: float) -> void:
	_apply_bus_volume(MUSIC_BUS, linear)

func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(linear, 0.0001)))

# ---------- Guardado

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume: float = 1.0
	var sfx_volume: float = 1.0
	if config.load(SETTINGS_PATH) == OK:
		volume = clamp(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		sfx_volume = clamp(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
		TUTORIAL_SIGN.enabled = bool(config.get_value("game", "tutorials", true))
		Rumble.enabled = bool(config.get_value("game", "vibration", true))
		InputViewer.set_enabled(bool(config.get_value("game", "input_viewer", false)))
		var saved_version := int(config.get_value("input", "version", 1))
		if saved_version == INPUT_VERSION:
			_load_bindings(config)
		elif saved_version in [2, 3]:
			_load_bindings(config)
			if saved_version == 2:
				_restore_joypad_default("throw_knife")
			# El antiguo reinicio deja de ser una acción directa. Select queda libre para taunt.
			_restore_joypad_default("taunt")
	music_slider.set_value_no_signal(volume * 100.0)
	music_value_label.text = "%d%%" % int(volume * 100.0)
	_apply_music_volume(volume)
	sfx_slider.set_value_no_signal(sfx_volume * 100.0)
	sfx_value_label.text = "%d%%" % int(sfx_volume * 100.0)
	_apply_bus_volume(SFX_BUS, sfx_volume)
	_refresh_tutorials_button()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_volume", music_slider.value / 100.0)
	config.set_value("audio", "sfx_volume", sfx_slider.value / 100.0)
	config.set_value("game", "tutorials", TUTORIAL_SIGN.enabled)
	config.set_value("game", "vibration", Rumble.enabled)
	config.set_value("game", "input_viewer", InputViewer.enabled)
	config.set_value("input", "version", INPUT_VERSION)
	for entry in REMAP_ACTIONS:
		var action: String = entry[0]
		var keys := []
		var pad := []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(event.physical_keycode)
			elif event is InputEventMouseButton:
				keys.append("m:%d" % event.button_index)
			elif event is InputEventJoypadButton:
				pad.append("b:%d" % event.button_index)
			elif event is InputEventJoypadMotion:
				pad.append("a:%d:%d" % [event.axis, int(sign(event.axis_value))])
		config.set_value("keyboard", action, keys)
		config.set_value("joypad", action, pad)
	config.save(SETTINGS_PATH)

func _load_bindings(config: ConfigFile) -> void:
	for entry in REMAP_ACTIONS:
		var action: String = entry[0]
		if config.has_section_key("keyboard", action):
			for existing in InputMap.action_get_events(action):
				if existing is InputEventKey or existing is InputEventMouseButton:
					InputMap.action_erase_event(action, existing)
			for code in config.get_value("keyboard", action):
				if code is String and String(code).begins_with("m:"):
					var mouse := InputEventMouseButton.new()
					mouse.button_index = int(String(code).substr(2))
					InputMap.action_add_event(action, mouse)
				else:
					var key := InputEventKey.new()
					key.physical_keycode = int(code)
					InputMap.action_add_event(action, key)
		if config.has_section_key("joypad", action):
			for existing in InputMap.action_get_events(action):
				if existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
					InputMap.action_erase_event(action, existing)
			for text in config.get_value("joypad", action):
				var parts: PackedStringArray = String(text).split(":")
				if parts[0] == "b":
					var button := InputEventJoypadButton.new()
					button.button_index = int(parts[1])
					InputMap.action_add_event(action, button)
				elif parts[0] == "a" and parts.size() == 3:
					var motion := InputEventJoypadMotion.new()
					motion.axis = int(parts[1])
					motion.axis_value = float(parts[2])
					InputMap.action_add_event(action, motion)

# ---------- Helpers de estilo

func _page(parent: Node) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	parent.add_child(page)
	return page

func _title(text: String) -> Label:
	var label := _label(text, 28, TEXT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(BUTTON_COLOR, Color(0.3, 0.5, 0.3), 8))
	button.add_theme_stylebox_override("hover", _box(BUTTON_HOVER, PANEL_BORDER, 8))
	button.add_theme_stylebox_override("focus", _box(BUTTON_HOVER, PANEL_BORDER, 8))
	button.add_theme_stylebox_override("pressed", _box(PANEL_BORDER.darkened(0.4), PANEL_BORDER, 8))
	button.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	button.pressed.connect(func() -> void: Sfx.play("ui_select"))
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button

func _box(color: Color, border: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.5
	style.content_margin_bottom = margin * 0.5
	return style
