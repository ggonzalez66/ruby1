class_name PixelFx
extends RefCounted

# Reproduce las hojas de PixelFX (assets/fx/pixelfx, exportadas por tools/art/export_pixelfx.py) como un
# AnimatedSprite2D que se borra solo al terminar. Las hojas "grey" se tiñen en vivo con una paleta de tres
# colores [oscuro, medio, brillante] (mapa de degradado sobre la luminancia), así un mismo golpe sale
# dorado, plateado, jade o rojo según quién lo dé. El pixel art se ve con filtro nearest.

const DATA := preload("res://pixel_fx_data.gd")
const SHEET_DIR := "res://assets/fx/pixelfx/%s.png"
const GRADIENT_SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform vec4 dark : source_color;
uniform vec4 mid : source_color;
uniform vec4 bright : source_color;
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float l = texel.r;
	vec3 tint = l < 0.5 ? mix(dark.rgb, mid.rgb, l * 2.0) : mix(mid.rgb, bright.rgb, (l - 0.5) * 2.0);
	COLOR = vec4(tint, texel.a) * COLOR;
}
"""
# Paleta por defecto de las hojas grises: blanco cálido.
const DEFAULT_PALETTE: Array[Color] = [Color(0.25, 0.22, 0.2), Color(0.85, 0.82, 0.78), Color(1.0, 1.0, 0.97)]

static var _frames := {}
static var _materials := {}
static var _shader: Shader

static func has(sheet: String) -> bool:
	return DATA.SHEETS.has(sheet)

static func duration(sheet: String, speed: float = 1.0) -> float:
	var info: Dictionary = DATA.SHEETS[sheet]
	return info["count"] / (info["fps"] * maxf(speed, 0.01))

# Lanza un efecto. options: flip (bool), rotation (rad), speed (×), z (z_index), modulate (Color),
# follow (Node2D al que se pega; "point" pasa a ser su desplazamiento local), loop (bool: no se borra solo).
static func play(parent: Node, sheet: String, point: Vector2, size: float = 1.0, palette: Array = [], options: Dictionary = {}) -> AnimatedSprite2D:
	if parent == null or not parent.is_inside_tree() or not DATA.SHEETS.has(sheet):
		return null
	var info: Dictionary = DATA.SHEETS[sheet]
	var sprite := AnimatedSprite2D.new()
	sprite.name = "PixelFx_" + sheet
	var looping := bool(options.get("loop", false))
	sprite.sprite_frames = _sprite_frames(sheet, looping)
	sprite.centered = false
	sprite.offset = -info["pivot"]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * size
	sprite.flip_h = bool(options.get("flip", false))
	if sprite.flip_h:
		# Al voltear, el pivote se refleja dentro del fotograma.
		sprite.offset.x = -(info["frame"].x - info["pivot"].x)
	sprite.rotation = float(options.get("rotation", 0.0))
	sprite.z_index = int(options.get("z", 6))
	sprite.speed_scale = float(options.get("speed", 1.0))
	sprite.modulate = options.get("modulate", Color.WHITE)
	if info["grey"]:
		sprite.material = _material(palette if palette.size() >= 3 else DEFAULT_PALETTE)
	var follow: Node2D = options.get("follow") as Node2D
	if follow != null and is_instance_valid(follow):
		follow.add_child(sprite)
		sprite.position = point
	else:
		parent.add_child(sprite)
		sprite.global_position = point
	if not looping:
		sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"default")
	return sprite

static func _sprite_frames(sheet: String, looping: bool) -> SpriteFrames:
	var key := sheet + ("|loop" if looping else "")
	if _frames.has(key):
		return _frames[key]
	var info: Dictionary = DATA.SHEETS[sheet]
	var texture: Texture2D = load(SHEET_DIR % sheet)
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", info["fps"])
	frames.set_animation_loop(&"default", looping)
	var size: Vector2 = info["frame"]
	for index in range(int(info["count"])):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(index % int(info["columns"]), index / int(info["columns"])) * size, size)
		frames.add_frame(&"default", atlas)
	_frames[key] = frames
	return frames

static func _material(palette: Array) -> ShaderMaterial:
	var key := "%s|%s|%s" % [palette[0].to_html(), palette[1].to_html(), palette[2].to_html()]
	if _materials.has(key):
		return _materials[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GRADIENT_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("dark", palette[0])
	material.set_shader_parameter("mid", palette[1])
	material.set_shader_parameter("bright", palette[2])
	_materials[key] = material
	return material
