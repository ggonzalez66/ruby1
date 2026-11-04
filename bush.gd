extends Node2D

# Bush del Gauntlet: Viridy se esconde dentro (stealth_director.gd). Se dibuja solo y se mece; al entrar o
# salir se agita y suelta hojas. Quien está dentro (Viridy o un enemigo) se ve solo como contorno por encima
# de las hojas, para saber que está ahí (shaders/silhouette_outline.gdshader).

const WIDTH := 170.0
const HEIGHT := 92.0
const LEAF_DARK := Color(0.1, 0.27, 0.14)
const LEAF_MID := Color(0.17, 0.42, 0.18)
const LEAF_LIGHT := Color(0.33, 0.6, 0.24)
const SWAY_SPEED := 1.6
const SWAY := 0.03
const RUSTLE_TIME := 0.7
const OUTLINE_SHADER := preload("res://shaders/silhouette_outline.gdshader")
const PLAYER_LINE := Color(0.75, 1.0, 0.82, 0.95)
const ENEMY_LINE := Color(1.0, 0.35, 0.3, 0.95)
# Grosor de la línea en píxeles de pantalla.
const LINE_WIDTH := 1.6

var clock := 0.0
var rustle_left := 0.0
var leaves: Array = []
var outline_layer: Node2D
var ghosts: Array[Sprite2D] = []

func _ready() -> void:
	add_to_group(&"bushes")
	# Por delante de Viridy, para que quede tapada de verdad.
	z_index = 8
	outline_layer = Node2D.new()
	outline_layer.name = "Outlines"
	outline_layer.top_level = true
	outline_layer.z_index = 9
	add_child(outline_layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x)
	for layer in [[LEAF_DARK, 46, 24.0], [LEAF_MID, 54, 17.0], [LEAF_LIGHT, 26, 10.0]]:
		for index in range(layer[1]):
			var x := rng.randf_range(-0.5, 0.5)
			# Forma de cúpula: más baja hacia los lados.
			var top := HEIGHT * sqrt(maxf(1.0 - 4.0 * x * x, 0.0))
			leaves.append([Vector2(x * WIDTH, -rng.randf_range(0.1, 0.95) * top), layer[2] * rng.randf_range(0.7, 1.15), layer[0], rng.randf() * TAU])

func contains(point: Vector2) -> bool:
	var local := point - global_position
	return absf(local.x) <= WIDTH * 0.5 and local.y <= 8.0 and local.y >= -HEIGHT

func rustle() -> void:
	rustle_left = RUSTLE_TIME
	Fx.dust(get_parent(), global_position + Vector2(0, -HEIGHT * 0.6), Vector2.UP, 6, 0.9, 1.6)

func _process(delta: float) -> void:
	clock += delta
	rustle_left = maxf(rustle_left - delta, 0.0)
	var strength: float = SWAY + 0.09 * rustle_left / RUSTLE_TIME
	skew = sin(clock * (SWAY_SPEED + 16.0 * rustle_left)) * strength
	_update_outlines()

# Contornos de quien está dentro: una copia del fotograma actual de cada sprite, solo con su borde.
func _update_outlines() -> void:
	var used := 0
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null and player.get("animated_sprite") != null and not player.get("dead") and contains(player.global_position + Vector2(0, -20)):
		used = _outline_sprite(player.animated_sprite, PLAYER_LINE, used)
	for enemy in get_tree().get_nodes_in_group(&"ruby_enemies"):
		if not (enemy is Node2D) or not enemy.visible or not contains(enemy.global_position + Vector2(0, -12)):
			continue
		for sprite in _sprites_of(enemy):
			used = _outline_sprite(sprite, ENEMY_LINE, used)
	for index in range(used, ghosts.size()):
		ghosts[index].visible = false

func _sprites_of(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child.name == "RubyCore" or not (child is CanvasItem) or not child.visible or String(child.name).begins_with("PixelFx_"):
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			found.append(child)
		found.append_array(_sprites_of(child))
	return found

func _outline_sprite(source: Node2D, color: Color, used: int) -> int:
	var texture: Texture2D = null
	var ghost := _ghost(used)
	ghost.region_enabled = false
	ghost.hframes = 1
	ghost.vframes = 1
	ghost.frame = 0
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
		if animated.sprite_frames == null:
			return used
		texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		ghost.centered = animated.centered
		ghost.offset = animated.offset
		ghost.flip_h = animated.flip_h
		ghost.flip_v = animated.flip_v
	else:
		var sprite := source as Sprite2D
		texture = sprite.texture
		ghost.centered = sprite.centered
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.region_enabled = sprite.region_enabled
		ghost.region_rect = sprite.region_rect
	if texture == null:
		return used
	ghost.texture = texture
	ghost.global_transform = source.global_transform
	ghost.visible = true
	var on_screen := maxf(absf(source.global_scale.x), 0.001)
	ghost.material.set_shader_parameter("line_color", color)
	ghost.material.set_shader_parameter("width", LINE_WIDTH / on_screen)
	return used + 1

func _ghost(index: int) -> Sprite2D:
	while ghosts.size() <= index:
		var ghost := Sprite2D.new()
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		ghost.material = material
		outline_layer.add_child(ghost)
		ghosts.append(ghost)
	return ghosts[index]

func _draw() -> void:
	# Cúpula oscura de fondo: sin huecos por los que se vea a Viridy.
	var dome := PackedVector2Array()
	for index in range(17):
		var angle: float = PI + PI * index / 16.0
		dome.append(Vector2(cos(angle) * WIDTH * 0.5, sin(angle) * HEIGHT * 0.92))
	draw_colored_polygon(dome, LEAF_DARK.darkened(0.25))
	for leaf in leaves:
		var center: Vector2 = leaf[0]
		var size: float = leaf[1]
		var side := Vector2.from_angle(leaf[3]) * size
		var across := side.orthogonal() * 0.6
		draw_colored_polygon(PackedVector2Array([center + side, center + across, center - side, center - across]), leaf[2])
