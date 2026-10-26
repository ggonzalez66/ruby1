extends Node2D

# Añadir aquí cada nueva etapa de prueba. Este catálogo no inicia la progresión del roguelike.
const LEVELS := [
	{
		"title": "Santuario",
		"description": "El Árbol Madre · Laguna y senderos entre raíces",
		"scene": "res://sanctuary.tscn",
	},
]
const MAIN_MENU := "res://main_menu.tscn"
const JUNGLE := preload("res://jungle_background.gd")
var level_buttons: Array[Button] = []
var back_button: Button

func _ready() -> void:
	RunSession._clear_run()
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	add_child(JUNGLE.new())
	var camera := Camera2D.new()
	camera.position = Vector2(0, -240)
	add_child(camera)
	Music.play_menu_music()
	_build_menu()
	level_buttons[0].grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

func _open_level(scene: String) -> void:
	Stats.reset()
	Ferocity.reset()
	get_tree().change_scene_to_file(scene)

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.05, 0.04, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("102d25"), Color("8cb674"), 28))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label("LEVEL TESTING", 32, Color("edf4ce")))
	column.add_child(_label("Lugares del próximo viaje", 17, Color("a3c9a2")))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(520, 215)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var levels := VBoxContainer.new()
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.add_theme_constant_override("separation", 12)
	scroll.add_child(levels)
	for entry in LEVELS:
		var button := _button(entry.title + "\n" + entry.description, _open_level.bind(entry.scene))
		button.custom_minimum_size.y = 88
		button.add_theme_font_size_override("font_size", 18)
		levels.add_child(button)
		level_buttons.append(button)
	back_button = _button("Volver al menú", _back)
	column.add_child(back_button)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("edf4ce"))
	button.add_theme_stylebox_override("normal", _box(Color("1c4233"), Color("44664b"), 12))
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, _box(Color("315d40"), Color("c4d891"), 12))
	button.focus_entered.connect(func(): Sfx.play("ui_move"))
	button.pressed.connect(func(): Sfx.play("ui_select"))
	button.pressed.connect(action)
	return button

func _box(fill: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(margin)
	return box
