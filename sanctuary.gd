extends Node2D

# Santuario de pruebas: geometría fija, sin portales, progresión, enemigos ni récords.
const PLAYER := preload("res://playerr.tscn")
const TERRAIN := preload("res://sanctuary_ground.gd")
const VISUALS := preload("res://sanctuary_visuals.gd")
const WATER := preload("res://shaders/sanctuary_water.gdshader")
const PAUSE := preload("res://pause_menu.gd")
const LAGOON_DETAILS := preload("res://sanctuary_lagoon_details.gd")
const SPAWN := Vector2(2940, -70)
const WATER_SURFACE := 96.0

# Nombre, izquierda, derecha, altura, grosor: raíces y cornisas del circuito libre.
const LEDGES := [
	["WestRoot", 1510, 1780, -145, 65],
	["WestRock", 1190, 1320, -370, 370],
	["WestLedge", 760, 1080, -225, 85],
	["WestUpperRock", 1590, 1700, -650, 330],
	["WestLookout", 1820, 2180, -490, 75],
	["WestCanopy", 2070, 2420, -730, 70],
	["LowBranchLeft", 2560, 2860, -225, 55],
	["BranchLeft", 2510, 2810, -480, 55],
	["UpperBranchLeft", 2600, 2920, -740, 55],
	["CrownBranch", 2860, 3280, -1030, 65],
	["LowBranchRight", 3200, 3500, -350, 55],
	["BranchRight", 3260, 3580, -610, 55],
	["UpperBranchRight", 3250, 3560, -880, 55],
	["EastLookout", 3770, 4140, -500, 75],
	["EastCanopy", 3820, 4150, -765, 70],
	["EastRoot", 4530, 4780, -165, 65],
	["EastRock", 4920, 5060, -400, 400],
	["EastUpperRock", 4550, 4660, -690, 330],
	["EastLedge", 5300, 5660, -235, 80],
	["PondStoneWest", 2350, 2490, 125, 100],
	["PondStoneEast", 3650, 3800, 125, 100],
]

var player: CharacterBody2D
var pause_menu: CanvasLayer
var lagoon: Area2D
var water_visual: Polygon2D
var water_texture: ImageTexture
var footer: Label

func _ready() -> void:
	RunSession._clear_run()
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	_build_sky()
	add_child(VISUALS.new())
	_build_terrain()
	_build_water()
	_build_waterfall()
	add_child(LAGOON_DETAILS.new())
	_build_particles()
	player = PLAYER.instantiate()
	player.name = "Playerr"
	player.position = SPAWN
	var camera: Camera2D = player.get_node("Camera2D")
	camera.position = Vector2(0, -155)
	camera.zoom = Vector2.ONE * 0.72
	camera.limit_left = 0
	camera.limit_right = 6400
	camera.limit_top = -1800
	camera.limit_bottom = 620
	add_child(player)
	pause_menu = PAUSE.new()
	pause_menu.name = "PauseMenu"
	pause_menu.testing_mode = true
	add_child(pause_menu)
	_build_ui()
	Music.play_game_music()

func _physics_process(_delta: float) -> void:
	# Salvaguarda de la zona de pruebas, también para lanzamientos extremos de movilidad.
	if is_instance_valid(player) and (player.position.y > 800 or player.position.y < -2200 or player.position.x < -180 or player.position.x > 6580):
		player._respawn_player()

func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("244c43"), Color("87ae85"), Color("e0dfaa")])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 512
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = texture
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)

func _build_terrain() -> void:
	_ground("BanksAndBasin", PackedVector2Array([
		Vector2(0, -50), Vector2(850, -50), Vector2(1150, 0), Vector2(1750, 0),
		Vector2(2000, 96), Vector2(2200, 260), Vector2(4200, 260), Vector2(4400, 96),
		Vector2(4650, 0), Vector2(5600, 0), Vector2(6100, -80), Vector2(6400, -80),
		Vector2(6400, 1200), Vector2(0, 1200),
	]), 12)
	_ground("MotherTreeIsland", PackedVector2Array([
		Vector2(2650, 80), Vector2(2780, 5), Vector2(2860, -65), Vector2(3200, -65),
		Vector2(3300, 5), Vector2(3420, 80), Vector2(3380, 140), Vector2(2700, 140),
	]), 6, true)
	for ledge in LEDGES:
		var x0: float = ledge[1]
		var x1: float = ledge[2]
		var y: float = ledge[3]
		var depth: float = ledge[4]
		_ground(ledge[0], PackedVector2Array([
			Vector2(x0, y + 12), Vector2(x0 + 20, y), Vector2(x1 - 20, y), Vector2(x1, y + 12),
			Vector2(x1 - 16, y + depth), Vector2(x0 + 22, y + depth),
		]), 4, true)
	# Límites de colisión fuera del claro, sin convertirlos en salidas a otra escena.
	for x in [-40, 6440]:
		var boundary := StaticBody2D.new()
		boundary.collision_layer = 2
		boundary.position = Vector2(x, -350)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(80, 3100)
		boundary.add_child(shape)
		add_child(boundary)

func _ground(label: String, points: PackedVector2Array, surface_count: int, root_surface := false) -> void:
	var ground := TERRAIN.new()
	ground.name = label
	ground.outline = points
	ground.surface_count = surface_count
	ground.root_surface = root_surface
	add_child(ground)

func _build_water() -> void:
	# Polygon2D solo envía sus UV al renderer cuando tiene textura asignada.
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	water_texture = ImageTexture.create_from_image(pixel)
	water_visual = Polygon2D.new()
	water_visual.texture = water_texture
	water_visual.name = "LagoonWater"
	water_visual.z_index = 1
	water_visual.polygon = PackedVector2Array([Vector2(2000, 96), Vector2(4400, 96), Vector2(4200, 260), Vector2(2200, 260)])
	water_visual.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.9167, 1), Vector2(0.0833, 1)])
	var material := ShaderMaterial.new()
	material.shader = WATER
	water_visual.material = material
	add_child(water_visual)
	lagoon = Area2D.new()
	lagoon.name = "Lagoon"
	lagoon.collision_layer = 0
	lagoon.collision_mask = 1
	var shape := CollisionPolygon2D.new()
	shape.polygon = water_visual.polygon
	lagoon.add_child(shape)
	lagoon.body_entered.connect(_on_water_entered)
	add_child(lagoon)

func _on_water_entered(body: Node2D) -> void:
	if body != player or player.global_position.y < WATER_SURFACE - 12:
		return
	var drops := CPUParticles2D.new()
	drops.position = Vector2(player.position.x, WATER_SURFACE)
	drops.z_index = 3
	drops.one_shot = true
	drops.amount = 14
	drops.lifetime = 0.65
	drops.explosiveness = 1.0
	drops.direction = Vector2.UP
	drops.spread = 65
	drops.gravity = Vector2(0, 340)
	drops.initial_velocity_min = 45
	drops.initial_velocity_max = 110
	drops.scale_amount_min = 1.5
	drops.scale_amount_max = 3
	drops.color = Color("b8f5d7")
	add_child(drops)
	get_tree().create_timer(1.0).timeout.connect(drops.queue_free)

func _build_waterfall() -> void:
	var waterfall := Polygon2D.new()
	waterfall.texture = water_texture
	waterfall.name = "SpringWaterfall"
	waterfall.z_index = -5
	waterfall.polygon = PackedVector2Array([
		Vector2(2070, -490), Vector2(2110, -490), Vector2(2130, -415), Vector2(2130, -40),
		Vector2(2160, 96), Vector2(2080, 96), Vector2(2090, -40), Vector2(2090, -415),
	])
	waterfall.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.13), Vector2(1, 0.77), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0.77), Vector2(0, 0.13)])
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float stream = pow(0.5 + 0.5 * sin(UV.x * 48.0 + sin(UV.y * 25.0 - TIME * 3.0)), 5.0);
	float edge = smoothstep(0.0, 0.16, UV.x) * smoothstep(0.0, 0.16, 1.0 - UV.x);
	COLOR = vec4(mix(vec3(0.45, 0.83, 0.76), vec3(0.87, 0.97, 0.84), stream), edge * 0.68);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	waterfall.material = material
	add_child(waterfall)
	var mist := CPUParticles2D.new()
	mist.name = "SpringMist"
	mist.position = Vector2(2120, 96)
	mist.z_index = 2
	mist.amount = 22
	mist.lifetime = 1.1
	mist.preprocess = 1.1
	mist.direction = Vector2.UP
	mist.spread = 70
	mist.gravity = Vector2(0, 60)
	mist.initial_velocity_min = 12
	mist.initial_velocity_max = 45
	mist.scale_amount_min = 1.5
	mist.scale_amount_max = 4
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.8, 1, 0.88, 0.45), Color(0.8, 1, 0.88, 0)])
	mist.color_ramp = fade
	add_child(mist)

func _build_particles() -> void:
	var pollen := CPUParticles2D.new()
	pollen.name = "SanctuaryPollen"
	pollen.position = Vector2(3100, -650)
	pollen.z_index = 2
	pollen.amount = 100
	pollen.lifetime = 9
	pollen.preprocess = 9
	pollen.local_coords = false
	pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pollen.emission_rect_extents = Vector2(2800, 800)
	pollen.direction = Vector2(1, -0.2)
	pollen.spread = 55
	pollen.gravity = Vector2.ZERO
	pollen.initial_velocity_min = 5
	pollen.initial_velocity_max = 18
	pollen.scale_amount_min = 1
	pollen.scale_amount_max = 2.8
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0, 0.25, 0.75, 1])
	colors.colors = PackedColorArray([Color(1, 1, 0.7, 0), Color(0.95, 1, 0.65, 0.8), Color(0.95, 1, 0.65, 0.65), Color(1, 1, 0.7, 0)])
	pollen.color_ramp = colors
	add_child(pollen)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SanctuaryHUD"
	layer.layer = 6
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(28, 20)
	title.text = "SANTUARIO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f3edc9"))
	title.add_theme_color_override("font_outline_color", Color("203c2e"))
	title.add_theme_constant_override("outline_size", 5)
	layer.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(29, 48)
	subtitle.text = "El corazón de la naturaleza"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color("cee0b8")
	layer.add_child(subtitle)
	layer.add_child(preload("res://speed_hud.gd").new())
	layer.add_child(preload("res://ferocity_hud.gd").new())
	footer = Label.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 28
	footer.offset_top = -34
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color("e7ebc6"))
	footer.add_theme_color_override("font_outline_color", Color("203c2e"))
	footer.add_theme_constant_override("outline_size", 4)
	layer.add_child(footer)
	_refresh_hint()
	InputHints.device_changed.connect(_refresh_hint)

func _refresh_hint() -> void:
	footer.text = "Explora a tu ritmo  ·  %s: pausa y menú" % InputHints.binding("pause")
