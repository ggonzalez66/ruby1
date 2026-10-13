extends CanvasLayer

# Pantalla de "Demo completada" al derrotar al guardián: mensaje de felicitación con los
# logros más destacados y las estadísticas de la partida.

const OVERLAY_COLOR := Color(0.01, 0.04, 0.03, 0.78)
const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.97)
const PANEL_BORDER := Color(1.0, 0.82, 0.35, 0.95)
const TITLE_COLOR := Color(1.0, 0.9, 0.55)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
const LABEL_COLOR := Color(0.7, 0.85, 0.66)

var root_control: Control
var message_label: Label
var stats_grid: GridContainer
var continue_button: Button

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"demo_complete")
	_build()
	root_control.visible = false

func show_results() -> void:
	message_label.text = Stats.congratulation_message()
	_fill_stats()
	root_control.visible = true
	get_tree().paused = true
	continue_button.grab_focus()

func _fill_stats() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var rows := [
		["Tiempo total", Stats.format_time(Stats.total_time)],
		["Combate contra el guardián", Stats.format_time(Stats.boss_fight_time)],
		["Dummies derrotados", Stats.get_count("dummies_killed")],
		["Parries", Stats.get_count("parries")],
		["Proyectiles devueltos", Stats.get_count("projectiles_reflected")],
		["Ataques bloqueados por el guardián", Stats.get_count("blocked")],
		["Cuchillos lanzados", Stats.get_count("knife_throws")],
		["Backflips", Stats.get_count("backflips")],
		["Frontflips", Stats.get_count("frontflips")],
		["Bunnyhops", Stats.get_count("bunnyhops")],
		["Running walljumps", Stats.get_count("running_walljumps")],
		["Mantles", Stats.get_count("mantles")],
		["Rugidos", Stats.get_count("roars")],
		["Tiempo corriendo", Stats.format_time(Stats.running_time)],
		["Tiempo de wallride", Stats.format_time(Stats.wallride_time)],
		["Tiempo quieto", Stats.format_time(Stats.idle_time)],
		["Golpes al sol (inmortal)", Stats.get_count("sun_hits_dealt")],
		["Veces quemado por el sol", Stats.get_count("sun_hits_taken")],
		["Daño recibido", Stats.get_count("damage_taken")],
		["Muertes", Stats.get_count("deaths")],
	]
	for row in rows:
		var name_label := _label(str(row[0]), 15, LABEL_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(name_label)
		var value_label := _label(str(row[1]), 15, TEXT_COLOR)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_grid.add_child(value_label)

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
	panel.custom_minimum_size = Vector2(680, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := _label("DEMO COMPLETADA", 34, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	message_label = _label("", 18, TEXT_COLOR)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(560, 0)
	column.add_child(message_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(stats_grid)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	continue_button = _button("Seguir jugando", _continue)
	buttons.add_child(continue_button)
	buttons.add_child(_button("Último checkpoint", _retry_from_checkpoint))
	buttons.add_child(_button("Reiniciar todo", _restart))

func _continue() -> void:
	root_control.visible = false
	get_tree().paused = false

func _retry_from_checkpoint() -> void:
	# Vuelve al último checkpoint con el guardián y los dummies restaurados para pelear otra vez.
	root_control.visible = false
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player._respawn_player()

func _restart() -> void:
	root_control.visible = false
	get_tree().paused = false
	Stats.reset()
	get_tree().reload_current_scene()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "focus", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.2, 0.15) if state == "normal" else Color(0.2, 0.32, 0.18)
		box.border_color = PANEL_BORDER if state != "normal" else Color(0.45, 0.4, 0.2)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(on_pressed)
	return button
