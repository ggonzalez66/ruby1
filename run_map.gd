extends Node2D

# Mapa de la run (RunState) al estilo Slay the Spire: un panal de hexágonos entre el Árbol Madre (abajo) y
# la Torre con el sol (arriba). Viridy está en su hexágono y elige uno vecino sin visitar (de lado o hacia
# arriba) con izquierda/derecha y lo confirma con salto/aceptar, o con el ratón. Cada territorio es un
# enfrentamiento (fábrica), una fuente de curación o el zorro comerciante. A la izquierda la leyenda, a la
# derecha la vida, los rubíes y las mejoras. Cancelar dos veces abandona la run (vuelta al Árbol Madre).

const IDLE_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_idle.png")
const IDLE_REGION := Rect2(0, 0, 543, 616)
const RADIUS := 36.0
const BACKGROUND_TOP := Color(0.05, 0.12, 0.1)
const BACKGROUND_BOTTOM := Color(0.12, 0.2, 0.13)
const TITLE_COLOR := Color(1.0, 0.86, 0.5)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
const TYPE_COLORS := {
	"start": Color(0.32, 0.42, 0.3),
	"fight": Color(0.44, 0.3, 0.26),
	"fountain": Color(0.2, 0.42, 0.45),
	"shop": Color(0.55, 0.36, 0.14),
	"tower": Color(0.5, 0.18, 0.24),
}
const VISITED_TINT := Color(0.16, 0.17, 0.16)
const AVAILABLE_BORDER := Color(1.0, 0.9, 0.55)
const LINE_COLOR := Color(0.05, 0.08, 0.06)
const MOVE_TIME := 0.35
const ABANDON_WINDOW := 2.5

var hex_width := RADIUS * sqrt(3.0)
var origin := Vector2.ZERO
var selected := Vector2i(-1, -1)
var moves: Array = []
var time := 0.0
var token_position := Vector2.ZERO
var moving := false
var abandon_timer := 0.0
var layer: CanvasLayer
var info_label: Label
var upgrades_label: Label
var health_bar: ProgressBar
var health_label: Label
var hint_label: Label
var selection_label: Label

func _ready() -> void:
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	Engine.time_scale = TimeControl.base_scale()
	# Abierto directamente (editor o pruebas): empieza una run nueva.
	if not RunState.active:
		RunState.start_run()
	Music.play_game_music()
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	moves = RunState.available_moves()
	_sort_moves()
	selected = moves[0] if not moves.is_empty() else Vector2i(-1, -1)
	token_position = cell_position(RunState.current)
	_refresh_ui()

func _sort_moves() -> void:
	moves.sort_custom(func(a, b): return cell_position(a).x < cell_position(b).x)

func _layout() -> void:
	var size := get_viewport_rect().size
	# El panal (7 columnas, 6 filas y la Torre) centrado; el Árbol Madre queda abajo y la Torre bajo el título.
	origin = Vector2(size.x * 0.5 - hex_width * 3.25, size.y - 158.0)
	token_position = cell_position(RunState.current)
	queue_redraw()

func cell_position(cell: Vector2i) -> Vector2:
	if cell == RunState.TOWER_CELL:
		return origin + Vector2(hex_width * 3.5, -RADIUS * 9.9)
	return origin + Vector2(hex_width * (cell.x + 0.5 * (cell.y % 2)), -RADIUS * 1.5 * cell.y)

func _process(delta: float) -> void:
	time += delta
	if abandon_timer > 0.0:
		abandon_timer = maxf(abandon_timer - delta, 0.0)
		if abandon_timer == 0.0:
			_refresh_hint()
	if not moving:
		_update_mouse()
	queue_redraw()

func _update_mouse() -> void:
	var mouse := get_global_mouse_position()
	for cell in moves:
		if mouse.distance_to(cell_position(cell)) < RADIUS * (1.3 if cell == RunState.TOWER_CELL else 0.9):
			if cell != selected:
				selected = cell
				Sfx.play("ui_move")
				_refresh_ui()
			return

func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if abandon_timer > 0.0:
			RunState.return_to_hub()
		else:
			abandon_timer = ABANDON_WINDOW
			hint_label.text = "Pulsa otra vez para abandonar la run y volver al Árbol Madre"
		return
	if moves.is_empty():
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_step_selection(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_step_selection(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		choose(selected)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_mouse()
		if get_global_mouse_position().distance_to(cell_position(selected)) < RADIUS * 1.3:
			choose(selected)

func _step_selection(direction: int) -> void:
	var index := moves.find(selected)
	selected = moves[wrapi(index + direction, 0, moves.size())]
	Sfx.play("ui_move")
	_refresh_ui()

func choose(cell: Vector2i) -> void:
	if moving or not cell in moves:
		return
	moving = true
	Sfx.play("ui_select")
	var tween := create_tween()
	tween.tween_property(self, "token_position", cell_position(cell), MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): RunState.enter(cell))

# ---------- Dibujo

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([BACKGROUND_TOP, BACKGROUND_TOP, BACKGROUND_BOTTOM, BACKGROUND_BOTTOM]))
	_draw_mother_tree(origin + Vector2(hex_width * 3.0, RADIUS * 1.7))
	# Caminos posibles desde la posición actual.
	for cell in moves:
		draw_line(cell_position(RunState.current), cell_position(cell), Color(AVAILABLE_BORDER, 0.35), 4.0)
	for cell in RunState.cells:
		_draw_cell(cell)
	_draw_tower(cell_position(RunState.TOWER_CELL))
	_draw_token(token_position + Vector2(0, sin(time * 3.0) * 3.0))

func _draw_cell(cell: Vector2i) -> void:
	var center := cell_position(cell)
	var kind: String = RunState.cell_type(cell)
	var visited: bool = RunState.visited.has(cell) and cell != RunState.current
	var available: bool = cell in moves
	var fill: Color = TYPE_COLORS.get(kind, Color.GRAY)
	if visited:
		fill = fill.lerp(VISITED_TINT, 0.65)
	elif not available:
		fill = fill.darkened(0.25)
	var points := _hex(center, RADIUS - 2.0)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, LINE_COLOR, 4.0, true)
	if available:
		var pulse := 0.6 + 0.4 * sin(time * 5.0)
		var width := 5.0 if cell == selected else 2.5
		draw_polyline(_closed(_hex(center, RADIUS - 5.0)), Color(AVAILABLE_BORDER, pulse if cell == selected else 0.7), width, true)
	var icon_alpha := 0.45 if visited else 1.0
	match kind:
		"start":
			draw_string(ThemeDB.fallback_font, center + Vector2(-RADIUS, 6), "START", HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 15, Color(TEXT_COLOR, icon_alpha))
		"fight":
			draw_factory_icon(self, center, RADIUS * 0.55, icon_alpha)
		"fountain":
			draw_fountain_icon(self, center, RADIUS * 0.55, icon_alpha)
		"shop":
			draw_fox_icon(self, center, RADIUS * 0.55, icon_alpha)
	if visited and kind != "start":
		draw_line(center + Vector2(-14, -14), center + Vector2(14, 14), Color(0.9, 0.95, 0.85, 0.35), 3.0)
		draw_line(center + Vector2(14, -14), center + Vector2(-14, 14), Color(0.9, 0.95, 0.85, 0.35), 3.0)

func _hex(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + TAU * index / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	points.append(points[0])
	return points

func _draw_tower(center: Vector2) -> void:
	# Torre de cristal con el sol encima, como en el boceto. Se ilumina si ya se puede ir.
	var available: bool = RunState.TOWER_CELL in moves
	for cell in RunState.cells:
		if cell.y == RunState.ROWS.size() - 1 and cell.x in RunState.TOWER_COLUMNS:
			draw_line(cell_position(cell), center + Vector2(0, 30), Color(0.6, 0.2, 0.25, 0.5), 3.0)
	var crystal := PackedVector2Array([center + Vector2(-16, -21), center + Vector2(0, -35), center + Vector2(16, -21),
		center + Vector2(13, 28), center + Vector2(0, 43), center + Vector2(-13, 28)])
	draw_colored_polygon(crystal, Color(0.62, 0.12, 0.2) if available else Color(0.4, 0.12, 0.17))
	draw_line(center + Vector2(0, -35), center + Vector2(0, 43), Color(1.0, 0.5, 0.55, 0.6), 2.0)
	draw_polyline(_closed(crystal), LINE_COLOR, 3.0, true)
	var sun := center + Vector2(0, -55)
	for index in range(12):
		var angle := time * 0.4 + TAU * index / 12.0
		draw_line(sun + Vector2(cos(angle), sin(angle)) * 16.0, sun + Vector2(cos(angle), sin(angle)) * 25.0, Color(1.0, 0.75, 0.25), 3.0)
	draw_circle(sun, 15.0, Color(1.0, 0.85, 0.35))
	draw_circle(sun, 10.0, Color(1.0, 0.97, 0.75))
	if available:
		var pulse := 0.6 + 0.4 * sin(time * 5.0)
		draw_arc(center + Vector2(0, -6), RADIUS * 1.35, 0, TAU, 40, Color(AVAILABLE_BORDER, pulse if selected == RunState.TOWER_CELL else 0.5), 5.0 if selected == RunState.TOWER_CELL else 2.5)

func _draw_mother_tree(base: Vector2) -> void:
	# El Árbol Madre bajo el panal: de ahí sale Viridy.
	var trunk := Color(0.3, 0.22, 0.14)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-24, 70), base + Vector2(24, 70), base + Vector2(10, 10), base + Vector2(-10, 10)]), trunk)
	for leaf in [Vector2(0, 0), Vector2(-40, 16), Vector2(40, 16), Vector2(-20, 30), Vector2(20, 30)]:
		draw_circle(base + leaf + Vector2(0, 14), 26.0, Color(0.2, 0.38, 0.22, 0.85))
	draw_string(ThemeDB.fallback_font, base + Vector2(76, 60), "ÁRBOL MADRE", HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color(TEXT_COLOR, 0.6))

func _draw_token(at: Vector2) -> void:
	# Viridy (su primer frame de reposo) sobre una base de jade.
	draw_circle(at + Vector2(0, 12), 20.0, Color(0.1, 0.25, 0.15, 0.8))
	draw_arc(at + Vector2(0, 12), 20.0, 0, TAU, 24, Color(0.5, 1.0, 0.6), 2.0)
	var height := 62.0
	var width := height * IDLE_REGION.size.x / IDLE_REGION.size.y
	draw_texture_rect_region(IDLE_SHEET, Rect2(at + Vector2(-width * 0.5, -height + 22.0), Vector2(width, height)), IDLE_REGION)

# Iconos compartidos (también los usa la leyenda).
static func draw_factory_icon(canvas: CanvasItem, center: Vector2, size: float, alpha := 1.0) -> void:
	var wall := Color(0.82, 0.78, 0.7, alpha)
	var dark := Color(0.12, 0.1, 0.1, alpha)
	canvas.draw_rect(Rect2(center + Vector2(-size, -size * 0.2), Vector2(size * 0.8, size * 0.9)), wall)
	canvas.draw_rect(Rect2(center + Vector2(-size * 0.2, -size * 0.8), Vector2(size * 1.2, size * 1.5)), wall)
	canvas.draw_rect(Rect2(center + Vector2(-size * 0.75, size * 0.25), Vector2(size * 0.3, size * 0.45)), dark)
	for index in range(3):
		canvas.draw_rect(Rect2(center + Vector2(size * (0.0 + index * 0.33), -size * 0.6), Vector2(size * 0.18, size * 0.18)), dark)
	canvas.draw_rect(Rect2(center + Vector2(size * 0.6, -size * 1.1), Vector2(size * 0.22, size * 0.32)), wall)

static func draw_fountain_icon(canvas: CanvasItem, center: Vector2, size: float, alpha := 1.0) -> void:
	var water := Color(0.55, 0.9, 1.0, alpha)
	var drop := PackedVector2Array([center + Vector2(-size * 0.25, -size * 0.9)])
	for index in range(13):
		var angle := -PI * 0.15 + (PI * 1.3) * index / 12.0
		drop.append(center + Vector2(-size * 0.25, size * 0.2) + Vector2(cos(angle), sin(angle)) * size * 0.6)
	canvas.draw_colored_polygon(drop, water)
	var heal := Color(0.45, 1.0, 0.6, alpha)
	var cross_center := center + Vector2(size * 0.55, -size * 0.35)
	canvas.draw_rect(Rect2(cross_center + Vector2(-size * 0.12, -size * 0.4), Vector2(size * 0.24, size * 0.8)), heal)
	canvas.draw_rect(Rect2(cross_center + Vector2(-size * 0.4, -size * 0.12), Vector2(size * 0.8, size * 0.24)), heal)

static func draw_fox_icon(canvas: CanvasItem, center: Vector2, size: float, alpha := 1.0) -> void:
	var fur := Color(0.98, 0.55, 0.18, alpha)
	var light := Color(1.0, 0.95, 0.88, alpha)
	var dark := Color(0.1, 0.08, 0.06, alpha)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-size, -size * 0.4), center + Vector2(size, -size * 0.4), center + Vector2(0, size)]), fur)
	for side in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(side * size, -size * 0.35), center + Vector2(side * size * 0.3, -size * 0.4), center + Vector2(side * size * 0.85, -size * 1.1)]), fur)
		canvas.draw_circle(center + Vector2(side * size * 0.35, -size * 0.1), size * 0.1, dark)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-size * 0.45, size * 0.15), center + Vector2(size * 0.45, size * 0.15), center + Vector2(0, size)]), light)
	canvas.draw_circle(center + Vector2(0, size * 0.9), size * 0.12, dark)

# ---------- Interfaz

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var title := _label("¡LLEGA A LA TORRE!", 30, TITLE_COLOR)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 6
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(title)
	# Leyenda (izquierda).
	var legend := _panel(Control.PRESET_CENTER_LEFT, Vector2(18, -110))
	var legend_column := VBoxContainer.new()
	legend_column.add_theme_constant_override("separation", 8)
	legend.add_child(legend_column)
	legend_column.add_child(_label("LEYENDA", 16, TITLE_COLOR))
	for entry in [["fountain", "Fuente · curación"], ["fight", "Campamento · enfrentamiento"], ["shop", "Zorro comerciante"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.draw.connect(_draw_legend_icon.bind(icon, entry[0]))
		row.add_child(icon)
		row.add_child(_label(entry[1], 14, TEXT_COLOR))
		legend_column.add_child(row)
	# Estado de la run (derecha).
	var status := _panel(Control.PRESET_CENTER_RIGHT, Vector2(-268, -150))
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(240, 0)
	column.add_theme_constant_override("separation", 6)
	status.add_child(column)
	column.add_child(_label("VIRIDY", 16, TITLE_COLOR))
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(220, 14)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.12, 0.06, 0.06)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.38, 0.86, 0.36)
	health_bar.add_theme_stylebox_override("background", back)
	health_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(health_bar)
	health_label = _label("", 14, TEXT_COLOR)
	column.add_child(health_label)
	info_label = _label("", 14, TEXT_COLOR)
	column.add_child(info_label)
	column.add_child(_label("MEJORAS", 14, TITLE_COLOR))
	upgrades_label = _label("", 13, Color(0.8, 0.9, 0.78))
	upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrades_label.custom_minimum_size = Vector2(240, 0)
	column.add_child(upgrades_label)
	column.add_child(_label("DESTINO", 14, TITLE_COLOR))
	selection_label = _label("", 17, Color.WHITE)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.custom_minimum_size = Vector2(240, 0)
	column.add_child(selection_label)
	hint_label = _label("", 14, Color(0.75, 0.85, 0.72))
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -500
	hint_label.offset_right = 500
	hint_label.offset_top = -30
	hint_label.offset_bottom = -8
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(hint_label)

func _refresh_ui() -> void:
	var health: int = RunState.stored_health()
	health_bar.max_value = RunState.max_health
	health_bar.value = health
	health_label.text = "Vida: %d / %d" % [health, RunState.max_health]
	info_label.text = "Rubíes: %d\nEnfrentamientos superados: %d" % [Upgrades.rubies, RunState.fights_cleared]
	upgrades_label.text = _owned_text()
	if selected == Vector2i(-1, -1):
		selection_label.text = "No hay camino disponible"
	else:
		var kind: String = RunState.cell_type(selected)
		var text: String = RunState.TYPE_NAMES.get(kind, kind)
		if kind == "fight":
			text += " %d" % RunState.depth()
		elif kind == "tower":
			text += " · los tres guardianes"
		selection_label.text = text
	_refresh_hint()

func _refresh_hint() -> void:
	hint_label.text = "%s / %s: elegir hexágono  ·  %s: entrar  ·  %s: abandonar run" % [
		InputHints.binding("move_left"), InputHints.binding("move_right"), InputHints.binding("jump"), InputHints.binding("pause")]

func _owned_text() -> String:
	var lines: Array = []
	lines.append(Upgrades.weapon_title())
	for slot in Upgrades.element_slots:
		var slot_name: String = Upgrades.RANGED_NAME if slot == Upgrades.RANGED_SLOT else Upgrades.SLOTS[slot]
		lines.append("%s en %s" % [Upgrades.ELEMENTS[Upgrades.element_slots[slot]]["title"], slot_name])
	for id in Upgrades.owned:
		var title: String = Upgrades.CATALOG[id]["title"]
		lines.append(title if int(Upgrades.owned[id]) == 1 else "%s ×%d" % [title, int(Upgrades.owned[id])])
	return "\n".join(lines)

func _panel(preset: int, offset: Vector2) -> PanelContainer:
	var anchor := Control.new()
	anchor.set_anchors_preset(preset)
	anchor.position = offset
	layer.add_child(anchor)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.07, 0.85)
	style.border_color = Color(0.55, 0.82, 0.45, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	anchor.add_child(panel)
	return panel

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	return label

func _draw_legend_icon(icon: Control, kind: String) -> void:
	var center := icon.size * 0.5
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + TAU * index / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 16.0)
	icon.draw_colored_polygon(points, TYPE_COLORS[kind])
	match kind:
		"fight":
			draw_factory_icon(icon, center, 8.5)
		"fountain":
			draw_fountain_icon(icon, center, 8.5)
		"shop":
			draw_fox_icon(icon, center, 8.5)
