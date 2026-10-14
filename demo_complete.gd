extends CanvasLayer

# Pantalla de "Demo completada" al derrotar al guardián: felicitación, medallero (las
# conseguidas en dorado, las pendientes en negro con su nombre como pista) y estadísticas.

const OVERLAY_COLOR := Color(0.01, 0.04, 0.03, 0.8)
const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.97)
const PANEL_BORDER := Color(1.0, 0.82, 0.35, 0.95)
const TITLE_COLOR := Color(1.0, 0.9, 0.55)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
const LABEL_COLOR := Color(0.7, 0.85, 0.66)
const LOCKED_TEXT := Color(0.45, 0.5, 0.45)

# Medalla dibujada: cinta, disco con borde y estrella. Bloqueada = silueta negra.
class MedalIcon extends Control:
	var earned := false

	func _init(is_earned: bool) -> void:
		earned = is_earned
		custom_minimum_size = Vector2(44, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 30.0)
		var dark := Color(0.06, 0.06, 0.07)
		var ribbon_left := Color(0.75, 0.18, 0.2) if earned else dark
		var ribbon_right := Color(0.2, 0.35, 0.8) if earned else dark
		draw_colored_polygon(PackedVector2Array([center + Vector2(-12, -28), center + Vector2(-2, -28), center + Vector2(4, -10), center + Vector2(-6, -10)]), ribbon_left)
		draw_colored_polygon(PackedVector2Array([center + Vector2(2, -28), center + Vector2(12, -28), center + Vector2(6, -10), center + Vector2(-4, -10)]), ribbon_right)
		var rim := Color(0.62, 0.38, 0.06) if earned else Color(0.22, 0.22, 0.22)
		var disc := Color(1.0, 0.78, 0.2) if earned else dark
		draw_circle(center, 16.0, rim)
		draw_circle(center, 13.0, disc)
		var star := PackedVector2Array()
		for index in range(10):
			var radius: float = 8.0 if index % 2 == 0 else 3.5
			var angle: float = -PI * 0.5 + PI * index / 5.0
			star.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(star, Color(1.0, 0.97, 0.75) if earned else Color(0.14, 0.14, 0.15))
		if earned:
			# Brillo.
			draw_circle(center + Vector2(-6, -6), 3.0, Color(1.0, 1.0, 1.0, 0.55))

# Título de la pantalla (cada escenario pone el suyo).
@export var title_text := "DEMO COMPLETADA"
# Escena de la etapa siguiente: si hay, el primer botón es "Siguiente etapa" (las estadísticas siguen).
@export var next_scene := ""
# Pantalla del final del juego: solo se puede volver al menú principal.
@export var final_screen := false
# Mensaje bajo el título ("" = la felicitación de siempre).
@export var message_text := ""

const MAIN_MENU := "res://main_menu.tscn"

var root_control: Control
var message_label: Label
var medals_grid: GridContainer
var medals_title: Label
var stats_grid: GridContainer
var continue_button: Button

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"demo_complete")
	_build()
	root_control.visible = false

func show_results() -> void:
	message_label.text = message_text if message_text != "" else Stats.congratulation_message()
	_fill_medals()
	_fill_stats()
	root_control.visible = true
	get_tree().paused = true
	continue_button.grab_focus()

func _fill_medals() -> void:
	for child in medals_grid.get_children():
		child.queue_free()
	var medals: Array = Stats.medals()
	var earned_count := 0
	for medal in medals:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(98, 0)
		cell.add_theme_constant_override("separation", 2)
		cell.tooltip_text = "%s\n%s" % [medal.name, medal.description]
		var icon := MedalIcon.new(medal.earned)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var name_label := _label(medal.name, 11, TEXT_COLOR if medal.earned else LOCKED_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(98, 0)
		cell.add_child(name_label)
		medals_grid.add_child(cell)
		if medal.earned:
			earned_count += 1
	medals_title.text = "MEDALLAS  %d / %d" % [earned_count, medals.size()]

func _fill_stats() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var rows := [
		["Tiempo total", Stats.format_time(Stats.total_time)],
		["Combate contra el guardián", Stats.format_time(Stats.boss_fight_time)],
		["Dummies derrotados", Stats.get_count("dummies_killed")],
		["Ferocity máxima", Ferocity.RANKS[Stats.get_count("ferocity_peak")]["letter"]],
		["Parries", Stats.get_count("parries")],
		["Vida recuperada", Stats.get_count("health_healed")],
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
		var name_label := _label(str(row[0]), 13, LABEL_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(name_label)
		var value_label := _label(str(row[1]), 13, TEXT_COLOR)
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
	panel.custom_minimum_size = Vector2(1000, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := _label(title_text, 32, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	message_label = _label("", 20, TEXT_COLOR)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)

	# Medallero.
	var medals_box := VBoxContainer.new()
	medals_box.add_theme_constant_override("separation", 6)
	body.add_child(medals_box)
	medals_title = _label("MEDALLAS", 16, TITLE_COLOR)
	medals_box.add_child(medals_title)
	var medals_scroll := ScrollContainer.new()
	medals_scroll.custom_minimum_size = Vector2(530, 330)
	medals_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	medals_box.add_child(medals_scroll)
	medals_grid = GridContainer.new()
	medals_grid.columns = 5
	medals_grid.add_theme_constant_override("h_separation", 6)
	medals_grid.add_theme_constant_override("v_separation", 8)
	medals_scroll.add_child(medals_grid)

	# Estadísticas.
	var stats_box := VBoxContainer.new()
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_box.add_theme_constant_override("separation", 6)
	body.add_child(stats_box)
	stats_box.add_child(_label("ESTADÍSTICAS", 16, TITLE_COLOR))
	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size = Vector2(0, 330)
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_box.add_child(stats_scroll)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 18)
	stats_grid.add_theme_constant_override("v_separation", 3)
	stats_scroll.add_child(stats_grid)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	if final_screen:
		continue_button = _button("Menú principal", _main_menu)
		buttons.add_child(continue_button)
		return
	if next_scene != "":
		continue_button = _button("Siguiente etapa", _next_stage)
		buttons.add_child(continue_button)
		buttons.add_child(_button("Seguir jugando", _continue))
	else:
		continue_button = _button("Seguir jugando", _continue)
		buttons.add_child(continue_button)
	buttons.add_child(_button("Último checkpoint", _retry_from_checkpoint))
	buttons.add_child(_button("Reiniciar todo", _restart))
	buttons.add_child(_button("Menú principal", _main_menu))

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

func _next_stage() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(next_scene)

func _main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU)

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
