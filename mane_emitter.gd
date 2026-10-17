extends CPUParticles2D

# Melena evanescente de Viridy: motas del color del rango de estilo que se desprenden de la melena, suben
# y se quedan atrás (en coordenadas del mundo) al moverse. La zona de la melena sale del contorno del frame que se está
# dibujando (arriba y hacia atrás), así sirve para cualquier animación, volteada o girando.

# Dentro del contorno visible del frame (0..1): centro y medio tamaño de la zona de la melena.
const MANE_CENTER := Vector2(0.42, 0.22)
const MANE_HALF_SIZE := Vector2(0.22, 0.14)

var _bounds_cache := {}
var _color := Color.TRANSPARENT
var _atlas_images := {}

func _init() -> void:
	amount = 26
	lifetime = 0.9
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(0, -1)
	spread = 40.0
	gravity = Vector2(0, -26)
	initial_velocity_min = 8.0
	initial_velocity_max = 26.0
	damping_min = 4.0
	damping_max = 10.0
	scale_amount_min = 1.0
	scale_amount_max = 2.5
	set_style_color(Color(0.45, 0.75, 1.0))

func set_style_color(color: Color) -> void:
	if color.is_equal_approx(_color):
		return
	_color = color
	var glow: Color = color.lerp(Color.WHITE, 0.55)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(glow, 0.95), Color(color, 0.85), Color(color, 0.0)])
	color_ramp = ramp

func follow(sprite: AnimatedSprite2D, facing: float, active: bool, color: Color = Color.TRANSPARENT) -> void:
	if color.a > 0.0:
		set_style_color(color)
	emitting = active and sprite.visible
	if not emitting:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var bounds := _visible_bounds(texture)
	var size := texture.get_size()
	var center := bounds.position + bounds.size * MANE_CENTER - size * 0.5
	var flip := -1.0 if sprite.flip_h else 1.0
	center.x *= flip
	position = sprite.position + (center * sprite.scale).rotated(sprite.rotation)
	emission_rect_extents = bounds.size * MANE_HALF_SIZE * sprite.scale
	# Las motas se van hacia atrás de donde mira el personaje.
	direction = Vector2(-0.5 * facing, -1.0).normalized()

func _visible_bounds(texture: Texture2D) -> Rect2:
	if _bounds_cache.has(texture):
		return _bounds_cache[texture]
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	var image: Image = null
	if texture is AtlasTexture:
		if not _atlas_images.has(texture.atlas):
			var loaded: Image = texture.atlas.get_image()
			if loaded and loaded.is_compressed():
				loaded.decompress()
			_atlas_images[texture.atlas] = loaded
		var atlas_image: Image = _atlas_images[texture.atlas]
		if atlas_image:
			image = atlas_image.get_region(Rect2i(texture.region))
	else:
		image = texture.get_image()
	if image:
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			bounds = Rect2(used)
	_bounds_cache[texture] = bounds
	return bounds
