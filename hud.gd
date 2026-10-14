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
var fill_tween: Tween
var elapsed_time := 0.0
var timer_main_label: Label
var timer_millis_label: Label
var knife_icon: TextureRect
var boss_indicator: Control
var boss_indicator_style: StyleBoxFlat
var boss_view: SubViewport
var boss_camera: Camera2D
var boss_warning: Label
var boss_arrow: Polygon2D
var death_panel: VBoxContainer
var death_hint: Label
var boss_banner: VBoxContainer
var boss_banner_name: Label
var boss_banner_subtitle: Label
var boss_banner_tween: Tween
var banner_boss: Node
var flash_rect: ColorRect
var flash_tween: Tween

const BOSS_INDICATOR_SIZE := 72.0
const BOSS_INDICATOR_MARGIN := 14.0

func _ready() -> void:
	layer = 10
	_build()
	_build_timer()
	_build_boss_indicator()
	_build_death_screen()
	_build_boss_banner()
	_connect_player.call_deferred()

func _process(delta: float) -> void:
	elapsed_time += delta
	_update_timer_text()
	_update_boss_indicator()
	_update_boss_banner()

func _build_boss_banner() -> void:
	# Presentación del guardián al empezar el combate: nombre grande y subtítulo entre dos líneas.
	boss_banner = VBoxContainer.new()
	boss_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_banner.modulate.a = 0.0
	boss_banner.visible = false
	add_child(boss_banner)
	boss_banner.add_child(_banner_line())
	boss_banner_name = Label.new()
	boss_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_name.add_theme_font_size_override("font_size", 46)
	boss_banner_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	boss_banner_name.add_theme_color_override("font_outline_color", Color(0.15, 0.06, 0.02))
	boss_banner_name.add_theme_constant_override("outline_size", 10)
	boss_banner.add_child(boss_banner_name)
	boss_banner_subtitle = Label.new()
	boss_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_subtitle.add_theme_font_size_override("font_size", 18)
	boss_banner_subtitle.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	boss_banner_subtitle.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	boss_banner_subtitle.add_theme_constant_override("outline_size", 6)
	boss_banner.add_child(boss_banner_subtitle)
	boss_banner.add_child(_banner_line())

func _banner_line() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(420, 2)
	line.color = Color(0.9, 0.65, 0.25, 0.85)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return line

func _update_boss_banner() -> void:
	var boss := get_tree().get_first_node_in_group(&"boss")
	var fighting: bool = boss != null and boss.combat_started and not boss.is_defeated()
	if fighting and banner_boss != boss:
		banner_boss = boss
		_show_boss_banner(boss)
	elif boss != null and not boss.combat_started and not boss.is_defeated():
		# Al reaparecer en el checkpoint el combate se reinicia: se vuelve a presentar.
		banner_boss = null

func _show_boss_banner(boss: Node) -> void:
	boss_banner_name.text = boss.boss_name
	boss_banner_subtitle.text = boss.boss_subtitle
	boss_banner.visible = true
	boss_banner.reset_size()
	var screen := get_viewport().get_visible_rect().size
	boss_banner.position = Vector2(screen.x * 0.5 - boss_banner.size.x * 0.5, screen.y * 0.2)
	if boss_banner_tween:
		boss_banner_tween.kill()
	boss_banner.modulate.a = 0.0
	boss_banner.scale = Vector2.ONE
	boss_banner_tween = create_tween()
	boss_banner_tween.tween_property(boss_banner, "modulate:a", 1.0, 0.35)
	boss_banner_tween.tween_interval(1.8)
	boss_banner_tween.tween_property(boss_banner, "modulate:a", 0.0, 0.7)
	boss_banner_tween.tween_callback(func(): boss_banner.visible = false)

func _build_death_screen() -> void:
	# Mensaje de muerte (aparece al instante) y destello dorado al volver al checkpoint.
	death_panel = VBoxContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_CENTER)
	death_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	death_panel.visible = false
	add_child(death_panel)
	var title := Label.new()
	title.text = "MUERTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.12, 0.1))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	death_panel.add_child(title)
	var hint := Label.new()
	death_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	hint.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.0))
	hint.add_theme_constant_override("outline_size", 6)
	death_panel.add_child(hint)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.85, 0.35, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func _on_player_died() -> void:
	death_hint.text = "Presiona %s para cargar el último checkpoint" % InputHints.binding("respawn")
	death_panel.visible = true
	# En el tercio superior para que se vea a Rengar salir despedido (la cámara lo centra).
	var screen := get_viewport().get_visible_rect().size
	death_panel.position = Vector2(screen.x * 0.5 - death_panel.size.x * 0.5, screen.y * 0.22)

func _on_player_respawned() -> void:
	death_panel.visible = false
	if flash_tween:
		flash_tween.kill()
	flash_rect.color.a = 0.85
	flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.55).set_ease(Tween.EASE_OUT)

func _build_boss_indicator() -> void:
	# Círculo pequeño en el borde de la pantalla con la miniatura del guardián en vivo.
	boss_indicator = Control.new()
	boss_indicator.size = Vector2(BOSS_INDICATOR_SIZE, BOSS_INDICATOR_SIZE)
	boss_indicator.visible = false
	add_child(boss_indicator)

	var mask := Panel.new()
	mask.size = boss_indicator.size
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color(0.03, 0.08, 0.06, 0.95)
	mask_style.set_corner_radius_all(int(BOSS_INDICATOR_SIZE / 2.0))
	mask.add_theme_stylebox_override("panel", mask_style)
	# El círculo del panel recorta la miniatura.
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	boss_indicator.add_child(mask)

	var container := SubViewportContainer.new()
	container.size = boss_indicator.size
	container.stretch = true
	mask.add_child(container)
	boss_view = SubViewport.new()
	boss_view.size = Vector2i(int(BOSS_INDICATOR_SIZE), int(BOSS_INDICATOR_SIZE))
	boss_view.transparent_bg = true
	boss_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(boss_view)
	boss_camera = Camera2D.new()
	boss_camera.zoom = Vector2(0.24, 0.24)
	boss_view.add_child(boss_camera)

	var ring := Panel.new()
	ring.size = boss_indicator.size
	boss_indicator_style = StyleBoxFlat.new()
	boss_indicator_style.bg_color = Color(0, 0, 0, 0)
	boss_indicator_style.border_color = PANEL_BORDER
	boss_indicator_style.set_border_width_all(2)
	boss_indicator_style.set_corner_radius_all(int(BOSS_INDICATOR_SIZE / 2.0))
	ring.add_theme_stylebox_override("panel", boss_indicator_style)
	boss_indicator.add_child(ring)

	boss_warning = Label.new()
	boss_warning.text = "!"
	boss_warning.add_theme_font_size_override("font_size", 26)
	boss_warning.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	boss_warning.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	boss_warning.add_theme_constant_override("outline_size", 6)
	boss_warning.position = Vector2(BOSS_INDICATOR_SIZE - 16, -12)
	boss_warning.visible = false
	boss_indicator.add_child(boss_warning)

	boss_arrow = Polygon2D.new()
	boss_arrow.polygon = PackedVector2Array([Vector2(0, -6), Vector2(10, 0), Vector2(0, 6)])
	boss_arrow.color = PANEL_BORDER
	boss_indicator.add_child(boss_arrow)

func _update_boss_indicator() -> void:
	var boss := get_tree().get_first_node_in_group(&"boss") as Node2D
	if boss == null or not boss.combat_started or boss.is_defeated():
		boss_indicator.visible = false
		return
	boss_view.world_2d = get_viewport().world_2d
	var screen_size := get_viewport().get_visible_rect().size
	var boss_center: Vector2 = boss.global_position + Vector2(0, -90)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * boss_center
	var on_screen := Rect2(Vector2.ZERO, screen_size).grow(-20.0).has_point(screen_pos)
	boss_indicator.visible = not on_screen
	if on_screen:
		return

	boss_camera.global_position = boss_center
	var radius := BOSS_INDICATOR_SIZE * 0.5
	var center := Vector2(
		clamp(screen_pos.x, BOSS_INDICATOR_MARGIN + radius, screen_size.x - BOSS_INDICATOR_MARGIN - radius),
		clamp(screen_pos.y, 90.0 + radius, screen_size.y - BOSS_INDICATOR_MARGIN - radius))
	boss_indicator.position = center - Vector2(radius, radius)
	# Flecha fuera del círculo apuntando hacia el guardián.
	var direction := (screen_pos - center).normalized()
	boss_arrow.position = Vector2(radius, radius) + direction * (radius + 6.0)
	boss_arrow.rotation = direction.angle()

	# Aviso de ataque: el "!" y el borde parpadean en rojo.
	var warning: bool = boss.is_warning()
	var blink: bool = int(Time.get_ticks_msec() / 120) % 2 == 0
	boss_warning.visible = warning and blink
	var border := Color(1.0, 0.25, 0.2) if warning and blink else PANEL_BORDER
	boss_indicator_style.border_color = border
	boss_arrow.color = border

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
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	_on_health_changed(player.current_health, player.max_health)
	_on_knife_changed(player.has_knife)

func _on_knife_changed(in_hand: bool) -> void:
	knife_icon.modulate = Color.WHITE if in_hand else Color(0.4, 0.45, 0.4, 0.35)

func _on_health_changed(current: int, maximum: int) -> void:
	var ratio: float = clamp(float(current) / float(max(maximum, 1)), 0.0, 1.0)
	var target_width: float = BAR_WIDTH * ratio
	var took_damage: bool = target_width < fill.size.x
	var healed: bool = target_width > fill.size.x + 0.5
	if fill_tween:
		fill_tween.kill()
	if healed and fill.size.x > 0.0:
		# Curación: la barra crece con un destello verde claro.
		fill_tween = create_tween().set_parallel(true)
		fill_tween.tween_property(fill, "size:x", target_width, 0.35).set_ease(Tween.EASE_OUT)
		fill.modulate = Color(1.6, 1.6, 1.3)
		fill_tween.tween_property(fill, "modulate", Color.WHITE, 0.5)
	else:
		fill.size.x = target_width
		fill.modulate = Color.WHITE
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
