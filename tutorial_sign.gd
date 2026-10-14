@tool
extends Node2D

# Cartel de tutorial: un poste con una tablilla. Al acercarse Rengar aparece encima un panel con
# el texto; {jump}, {attack}, {move}... se sustituyen por los controles reales del jugador
# (teclado o mando según lo que esté usando).

@export_multiline var text := "Texto del tutorial"
@export var title := ""
@export var show_distance := 230.0
@export var panel_width := 320.0

const WOOD := Color(0.42, 0.27, 0.15)
const WOOD_DARK := Color(0.25, 0.15, 0.08)
const GLOW := Color(1.0, 0.82, 0.35)

var panel: PanelContainer
var label: RichTextLabel
var visibility := 0.0

func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	z_index = 4
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.07, 0.92)
	style.border_color = Color(0.85, 0.68, 0.3, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.0
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	if title != "":
		var title_label := Label.new()
		title_label.text = title
		title_label.add_theme_font_size_override("font_size", 15)
		title_label.add_theme_color_override("font_color", GLOW)
		column.add_child(title_label)
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(panel_width, 0)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	label.add_theme_color_override("default_color", Color(0.92, 1.0, 0.86))
	column.add_child(label)
	_refresh_text()
	InputHints.device_changed.connect(_refresh_text)

func _refresh_text() -> void:
	label.text = InputHints.format(text)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var near: bool = player != null and player.global_position.distance_to(global_position + Vector2(0, -30)) < show_distance
	visibility = move_toward(visibility, 1.0 if near else 0.0, delta * 5.0)
	panel.modulate.a = visibility
	panel.visible = visibility > 0.01
	# Encima del cartel, centrado.
	panel.position = Vector2(-panel.size.x * 0.5, -78.0 - panel.size.y - 6.0 * (1.0 - visibility))
	queue_redraw()

func _draw() -> void:
	# Poste y tablilla de madera con un "?" que brilla más cuando el panel está abierto.
	draw_rect(Rect2(-3, -54, 6, 54), WOOD_DARK)
	draw_rect(Rect2(-22, -76, 44, 28), WOOD)
	draw_rect(Rect2(-22, -76, 44, 28), WOOD_DARK, false, 2.0)
	var glow_alpha: float = 0.35 + 0.65 * visibility
	draw_circle(Vector2(0, -62), 9.0, Color(GLOW, 0.25 * glow_alpha))
	draw_string(ThemeDB.fallback_font, Vector2(-5, -55), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(GLOW, glow_alpha))
