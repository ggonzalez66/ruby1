extends Node2D

# Menú principal: Subir Torre (la partida de cuatro etapas), Entrar al Gauntlet (oleadas y guardianes),
# Escalera al Cielo (plataformeo puro hasta fundirse con el sol), Opciones (las mismas del menú de
# pausa) y Salir. De fondo, Rengar corre sin fin por la jungla con el efecto de rango SSS (brillo de
# imparable y afterimages del color del rango).

const TOWER_SCENE := "res://main.tscn"
const GAUNTLET_SCENE := "res://gauntlet.tscn"
const SKY_SCENE := "res://sky_stairs.tscn"
const JUNGLE_SCRIPT := preload("res://jungle_background.gd")
const PAUSE_MENU_SCRIPT := preload("res://pause_menu.gd")
const MUSIC_SCRIPT := preload("res://music_player.gd")
const PLATFORM_SCRIPT := preload("res://platform.gd")
const SPRINT_SHEET: Texture2D = preload("res://assets/sprites/player/viridy/viridy_sprint.png")
# Las 3 celdas de 724 px, recortadas abajo a la altura de los pies.
const SPRINT_REGION := Rect2(0, 0, 2430, 642)
const GLOW_SHADER: Shader = preload("res://shaders/charge_glow.gdshader")
const TITLE_GLINT_SHADER: Shader = preload("res://shaders/title_glint.gdshader")

const PANEL_COLOR := Color(0.05, 0.11, 0.09, 0.9)
const PANEL_BORDER := Color(0.55, 0.82, 0.45, 0.9)
const BUTTON_COLOR := Color(0.1, 0.2, 0.15)
const BUTTON_HOVER := Color(0.17, 0.33, 0.23)
const TEXT_COLOR := Color(0.93, 1.0, 0.86)
# Título en rojo rubí con un destello ocasional (franja de luz + estrellita).
const TITLE_COLOR := Color(0.93, 0.1, 0.2)
const TITLE_OUTLINE := Color(0.18, 0.01, 0.04)
const GLINT_TIME := 0.55
const GLINT_PAUSE_MIN := 2.5
const GLINT_PAUSE_MAX := 4.5
# Rengar corre a su velocidad de sprint; la cámara lo acompaña y el suelo se recicla.
const RUN_SPEED := 560.0
const RUN_FPS := 12.0
const RUN_SCALE := 0.177
const RUNNER_SCREEN_X := -370.0
const GROUND_Y := 24.0
const GROUND_SEGMENT := 2400.0
const AFTERIMAGE_INTERVAL := 0.06
const AFTERIMAGE_LIFETIME := 0.42
const RUN_RANK := 6

var camera: Camera2D
var menu_root: Control
var first_button: Button
var options_menu: CanvasLayer
var runner: Sprite2D
var runner_material: ShaderMaterial
var ghost_material: ShaderMaterial
var ghosts: Node2D
var grounds: Array = []
var run_time := 0.0
var afterimage_timer := 0.0
var step_timer := 0.0
var title: Label
var title_material: ShaderMaterial
var sparkle: Polygon2D
var glint_wait := 1.2
var glint_time := -1.0

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
	_build_runner()
	var music := AudioStreamPlayer.new()
	music.set_script(MUSIC_SCRIPT)
	# En el menú principal suena siempre Mute City.
	music.fixed_track = "mute_city.mp3"
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
	camera.position.x += RUN_SPEED * delta
	_update_runner(delta)
	_update_title_glint(delta)

func _update_title_glint(delta: float) -> void:
	# Cada pocos segundos una franja de luz cruza el título y al final titila una estrellita.
	if glint_time < 0.0:
		glint_wait -= delta
		title_material.set_shader_parameter("sweep_x", -1000.0)
		if glint_wait <= 0.0:
			glint_time = 0.0
		return
	glint_time += delta
	var progress: float = glint_time / GLINT_TIME
	var width: float = title.size.x
	title_material.set_shader_parameter("sweep_x", lerp(-60.0, width + 60.0, progress))
	# La estrellita aparece cuando la franja llega al final y se apaga girando.
	var star: float = clamp((progress - 0.65) / 0.35, 0.0, 1.0)
	var twinkle: float = sin(star * PI)
	sparkle.scale = Vector2.ONE * twinkle * 1.2
	sparkle.rotation = star * 1.2
	sparkle.modulate.a = twinkle
	if progress >= 1.0:
		glint_time = -1.0
		glint_wait = randf_range(GLINT_PAUSE_MIN, GLINT_PAUSE_MAX)
		sparkle.scale = Vector2.ZERO

# ---------- Rengar corriendo de fondo

func _build_runner() -> void:
	# Dos tramos de suelo que se van turnando por delante de la cámara.
	for index in range(2):
		var ground: StaticBody2D = PLATFORM_SCRIPT.new()
		ground.size = Vector2(GROUND_SEGMENT, 300)
		ground.side_borders = false
		ground.position = Vector2(GROUND_SEGMENT * (index - 0.5), GROUND_Y + 150.0)
		add_child(ground)
		grounds.append(ground)
	ghosts = Node2D.new()
	add_child(ghosts)
	var rank_color: Color = Ferocity.RANKS[RUN_RANK]["color"]
	runner_material = ShaderMaterial.new()
	runner_material.shader = GLOW_SHADER
	ghost_material = ShaderMaterial.new()
	ghost_material.shader = GLOW_SHADER
	ghost_material.set_shader_parameter("glow_color", rank_color)
	ghost_material.set_shader_parameter("glow_amount", 0.85)
	runner = Sprite2D.new()
	runner.texture = SPRINT_SHEET
	runner.region_enabled = true
	runner.region_rect = SPRINT_REGION
	runner.hframes = 3
	runner.scale = Vector2.ONE * RUN_SCALE
	runner.material = runner_material
	add_child(runner)

func _update_runner(delta: float) -> void:
	run_time += delta
	runner.frame = int(run_time * RUN_FPS) % runner.hframes
	runner.position = Vector2(camera.position.x + RUNNER_SCREEN_X, GROUND_Y - SPRINT_REGION.size.y * RUN_SCALE * 0.5)
	# Brillo de imparable: el mismo parpadeo oro solar / menta que en el juego.
	var flash: Dictionary = Ferocity.unstoppable_flash()
	runner_material.set_shader_parameter("glow_color", flash["color"])
	runner_material.set_shader_parameter("glow_amount", flash["amount"])
	afterimage_timer -= delta
	if afterimage_timer <= 0.0:
		afterimage_timer = AFTERIMAGE_INTERVAL
		_spawn_afterimage()
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = 0.12
		Fx.dust(self, Vector2(runner.position.x - 6.0, GROUND_Y), Vector2(-1.0, -0.5), 3, 1.0, 0.5)
	for ground in grounds:
		if ground.position.x + GROUND_SEGMENT * 0.5 < camera.position.x - 900.0:
			ground.position.x += GROUND_SEGMENT * grounds.size()

func _spawn_afterimage() -> void:
	# Sombra del frame actual que se queda donde estaba y se desvanece (queda atrás al correr).
	var ghost := Sprite2D.new()
	ghost.texture = runner.texture
	ghost.region_enabled = true
	ghost.region_rect = SPRINT_REGION
	ghost.hframes = runner.hframes
	ghost.frame = runner.frame
	ghost.scale = runner.scale
	ghost.position = runner.position
	ghost.material = ghost_material
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.7)
	ghosts.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tween.tween_callback(ghost.queue_free)

# ---------- Acciones

func _start(scene: String) -> void:
	# Partida nueva: estadísticas y estilo desde cero.
	Stats.reset()
	Ferocity.reset()
	# La partida de tres etapas empieza sin guardianes vencidos.
	Stats.set_meta(&"defeated_bosses", [])
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
	title = _label("RUBY1", 84, TITLE_COLOR, 14)
	title.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	title_material = ShaderMaterial.new()
	title_material.shader = TITLE_GLINT_SHADER
	title.material = title_material
	column.add_child(title)
	# Estrellita de cuatro puntas en la esquina superior derecha del título.
	sparkle = Polygon2D.new()
	var star_points := PackedVector2Array()
	for index in range(8):
		var radius: float = 16.0 if index % 2 == 0 else 3.5
		var angle: float = -PI * 0.5 + PI * index / 4.0
		star_points.append(Vector2(cos(angle), sin(angle)) * radius)
	sparkle.polygon = star_points
	sparkle.color = Color(1.0, 0.95, 0.92)
	sparkle.scale = Vector2.ZERO
	title.add_child(sparkle)
	title.resized.connect(func(): sparkle.position = Vector2(title.size.x * 0.5 + 115.0, title.size.y * 0.3))
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
	buttons.add_child(_button("Escalera al Cielo", _start.bind(SKY_SCENE)))
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
