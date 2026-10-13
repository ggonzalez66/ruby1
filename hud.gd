extends CanvasLayer

# HUD de la vida de Rengar: panel arriba a la izquierda con barra, rastro de daño y número.

const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.82)
const PANEL_BORDER := Color(0.55, 0.82, 0.45, 0.9)
const BAR_BACK := Color(0.12, 0.06, 0.06)
const BAR_FILL := Color(0.38, 0.86, 0.36)
const BAR_FILL_LOW := Color(0.93, 0.3, 0.24)
const BAR_TRAIL := Color(1.0, 0.92, 0.62)
const BAR_WIDTH := 220.0

var fill: ColorRect
var trail: ColorRect
var value_label: Label
var trail_tween: Tween
var elapsed_time := 0.0
var timer_main_label: Label
var timer_millis_label: Label
var knife_icon: TextureRect

func _ready() -> void:
	layer = 10
	_build()
	_build_timer()
	_connect_player.call_deferred()

func _process(delta: float) -> void:
	elapsed_time += delta
	_update_timer_text()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var name_label := Label.new()
	name_label.text = "RENGAR"
	name_label.add_theme_color_override("font_color", Color(0.93, 1.0, 0.86))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	# Icono del cuchillo: brillante en la mano, apagado cuando está lanzado.
	knife_icon = TextureRect.new()
	var knife_texture := AtlasTexture.new()
	knife_texture.atlas = load("res://assets/sprites/player/rengar_knife.png")
	knife_texture.region = Rect2(48, 271, 243, 227)
	knife_icon.texture = knife_texture
	knife_icon.custom_minimum_size = Vector2(22, 20)
	knife_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knife_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(knife_icon)
	value_label = Label.new()
	value_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.8))
	value_label.add_theme_font_size_override("font_size", 14)
	header.add_child(value_label)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, 14)
	column.add_child(bar)
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.size = Vector2(BAR_WIDTH, 14)
	bar.add_child(back)
	trail = ColorRect.new()
	trail.color = BAR_TRAIL
	trail.size = Vector2(BAR_WIDTH, 14)
	bar.add_child(trail)
	fill = ColorRect.new()
	fill.color = BAR_FILL
	fill.size = Vector2(BAR_WIDTH, 14)
	bar.add_child(fill)

func _build_timer() -> void:
	# Cronómetro centrado arriba: minutos y segundos grandes, milésimas en pequeño.
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.position.y = 14
	add_child(anchor)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	anchor.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	timer_main_label = Label.new()
	timer_main_label.add_theme_font_size_override("font_size", 30)
	timer_main_label.add_theme_color_override("font_color", Color(0.93, 1.0, 0.86))
	row.add_child(timer_main_label)
	timer_millis_label = Label.new()
	timer_millis_label.add_theme_font_size_override("font_size", 16)
	timer_millis_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.66))
	timer_millis_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(timer_millis_label)
	_update_timer_text()
	# Centra el panel sobre el ancla una vez conocido su tamaño.
	panel.resized.connect(func(): panel.position.x = -panel.size.x * 0.5)

func _update_timer_text() -> void:
	var total_millis: int = int(elapsed_time * 1000.0)
	var minutes: int = total_millis / 60000
	var seconds: int = (total_millis / 1000) % 60
	timer_main_label.text = "%02d:%02d" % [minutes, seconds]
	timer_millis_label.text = ".%03d" % (total_millis % 1000)

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	player.knife_changed.connect(_on_knife_changed)
	_on_health_changed(player.current_health, player.max_health)
	_on_knife_changed(player.has_knife)

func _on_knife_changed(in_hand: bool) -> void:
	knife_icon.modulate = Color.WHITE if in_hand else Color(0.4, 0.45, 0.4, 0.35)

func _on_health_changed(current: int, maximum: int) -> void:
	var ratio: float = clamp(float(current) / float(max(maximum, 1)), 0.0, 1.0)
	var target_width: float = BAR_WIDTH * ratio
	var took_damage: bool = target_width < fill.size.x
	fill.size.x = target_width
	fill.color = BAR_FILL_LOW if ratio <= 0.3 else BAR_FILL
	value_label.text = "%d / %d" % [current, maximum]

	# El rastro claro se queda un momento y luego baja hasta la vida actual.
	if trail_tween:
		trail_tween.kill()
	if took_damage:
		trail_tween = create_tween()
		trail_tween.tween_interval(0.35)
		trail_tween.tween_property(trail, "size:x", target_width, 0.4)
	else:
		trail.size.x = target_width
