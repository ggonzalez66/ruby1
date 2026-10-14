extends Node2D

# Menú principal: Subir Torre (la torre de 6 pisos), Entrar al Gauntlet (los tres guardianes en una
# arena abierta), Opciones (las mismas del menú de pausa) y Salir. De fondo, la jungla desplazándose.

const TOWER_SCENE := "res://main.tscn"
const GAUNTLET_SCENE := "res://gauntlet.tscn"
const JUNGLE_SCRIPT := preload("res://jungle_background.gd")
const PAUSE_MENU_SCRIPT := preload("res://pause_menu.gd")
const MUSIC_SCRIPT := preload("res://music_player.gd")

const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.9)
const PANEL_BORDER := Color(0.55, 0.82, 0.45, 0.9)
const BUTTON_COLOR := Color(0.1, 0.2, 0.15)
const BUTTON_HOVER := Color(0.17, 0.33, 0.23)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
const TITLE_COLOR := Color(1.0, 0.86, 0.45)
const DRIFT_SPEED := 40.0

var camera: Camera2D
var menu_root: Control
var first_button: Button
var options_menu: CanvasLayer

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	# La jungla de fondo necesita una cámara para el parallax: avanza despacio hacia la derecha.
	var jungle: ParallaxBackground = JUNGLE_SCRIPT.new()
	jungle.altitude_offset = 0.35
	add_child(jungle)
	camera = Camera2D.new()
	camera.position = Vector2(0, -260)
	add_child(camera)
	camera.make_current()
	var music := AudioStreamPlayer.new()
	music.set_script(MUSIC_SCRIPT)
	music.bus = &"Music"
	music.volume_db = -6.0
	add_child(music)
	_build()
	options_menu = PAUSE_MENU_SCRIPT.new()
	options_menu.menu_mode = true
	add_child(options_menu)
	options_menu.closed.connect(_on_options_closed)
	first_button.grab_focus.call_deferred()

func _process(delta: float) -> void:
	camera.position.x += DRIFT_SPEED * delta

# ---------- Acciones

func _start(scene: String) -> void:
	# Partida nueva: estadísticas y estilo desde cero.
	Stats.reset()
	Ferocity.reset()
	get_tree().change_scene_to_file(scene)

func _open_options() -> void:
	menu_root.visible = false
	options_menu.open_options()

func _on_options_closed() -> void:
	menu_root.visible = true
	first_button.grab_focus()

func _quit() -> void:
	get_tree().quit()

# ---------- Interfaz

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.04, 0.03, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var title := _label("RENGAR", 84, TITLE_COLOR, 14)
	column.add_child(title)
	var subtitle := _label("La torre de los guardianes", 22, TEXT_COLOR, 6)
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	column.add_child(spacer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, PANEL_BORDER, 20))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(panel)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(340, 0)
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	first_button = _button("Subir Torre", _start.bind(TOWER_SCENE))
	buttons.add_child(first_button)
	buttons.add_child(_button("Entrar al Gauntlet", _start.bind(GAUNTLET_SCENE)))
	buttons.add_child(_button("Opciones", _open_options))
	buttons.add_child(_button("Salir", _quit))

func _label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", outline)
	return label

func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(BUTTON_COLOR, Color(0.3, 0.5, 0.3), 8))
	button.add_theme_stylebox_override("hover", _box(BUTTON_HOVER, PANEL_BORDER, 8))
	button.add_theme_stylebox_override("focus", _box(BUTTON_HOVER, PANEL_BORDER, 8))
	button.add_theme_stylebox_override("pressed", _box(PANEL_BORDER.darkened(0.4), PANEL_BORDER, 8))
	button.pressed.connect(on_pressed)
	return button

func _box(fill: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(margin)
	return box
