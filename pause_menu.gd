extends CanvasLayer

# Menú de pausa (ESC): reanudar y opciones de sonido. Funciona con el juego pausado.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"

const OVERLAY_COLOR := Color(0.01, 0.04, 0.03, 0.62)
const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.95)
const PANEL_BORDER := Color(0.55, 0.82, 0.45, 0.9)
const BUTTON_COLOR := Color(0.1, 0.2, 0.15)
const BUTTON_HOVER := Color(0.17, 0.33, 0.23)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)

var root_control: Control
var main_page: VBoxContainer
var options_page: VBoxContainer
var resume_button: Button
var music_slider: HSlider
var music_value_label: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_settings()
	root_control.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not get_tree().paused:
		_open()
	elif options_page.visible:
		_show_main_page()
	else:
		_resume()

func _open() -> void:
	get_tree().paused = true
	root_control.visible = true
	_show_main_page()

func _resume() -> void:
	root_control.visible = false
	get_tree().paused = false

func _show_main_page() -> void:
	options_page.visible = false
	main_page.visible = true
	resume_button.grab_focus()

func _show_options_page() -> void:
	main_page.visible = false
	options_page.visible = true
	music_slider.grab_focus()

func _build() -> void:
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
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, PANEL_BORDER, 24))
	center.add_child(panel)

	var pages := VBoxContainer.new()
	panel.add_child(pages)

	# Página principal.
	main_page = VBoxContainer.new()
	main_page.add_theme_constant_override("separation", 12)
	pages.add_child(main_page)
	main_page.add_child(_title("PAUSA"))
	resume_button = _button("Reanudar", _resume)
	main_page.add_child(resume_button)
	main_page.add_child(_button("Opciones", _show_options_page))

	# Página de opciones.
	options_page = VBoxContainer.new()
	options_page.add_theme_constant_override("separation", 12)
	pages.add_child(options_page)
	options_page.add_child(_title("OPCIONES"))
	var section := _label("Sonido", 18, Color(0.7, 0.9, 0.62))
	options_page.add_child(section)

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

	options_page.add_child(_button("Volver", _show_main_page))
	options_page.visible = false

func _on_music_volume_changed(value: float) -> void:
	_apply_music_volume(value / 100.0)
	music_value_label.text = "%d%%" % int(value)
	_save_settings()

func _apply_music_volume(linear: float) -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(linear, 0.0001)))

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume: float = 1.0
	if config.load(SETTINGS_PATH) == OK:
		volume = clamp(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	music_slider.set_value_no_signal(volume * 100.0)
	music_value_label.text = "%d%%" % int(volume * 100.0)
	_apply_music_volume(volume)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_volume", music_slider.value / 100.0)
	config.save(SETTINGS_PATH)

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
