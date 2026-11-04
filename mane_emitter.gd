extends CPUParticles2D

# Melena evanescente de Viridy: llamitas espirituales (hoja "mane_wisp" de PixelFX, propia del juego) del
# color del rango de estilo que se desprenden de la melena, se enroscan hacia arriba y se deshacen en humo,
# quedándose atrás (en coordenadas del mundo) al moverse. La zona de la melena sale del contorno del frame
# que se está dibujando (arriba y hacia atrás), así sirve para cualquier animación, volteada o girando.

# Dentro del contorno visible del frame (0..1): centro y medio tamaño de la zona de la melena.
const MANE_CENTER := Vector2(0.42, 0.22)
const MANE_HALF_SIZE := Vector2(0.22, 0.14)
const SHEET := "mane_wisp"

var _bounds_cache := {}
var _color := Color.TRANSPARENT
var _atlas_images := {}

func _init() -> void:
	amount = 20
	lifetime = 0.75
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(0, -1)
	spread = 35.0
	gravity = Vector2(0, -30)
	initial_velocity_min = 10.0
	initial_velocity_max = 28.0
	damping_min = 4.0
	damping_max = 10.0
	scale_amount_min = 0.38
	scale_amount_max = 0.62
	angle_min = -18.0
	angle_max = 18.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Cada partícula reproduce la hoja entera durante su vida (nace, se enrosca, se hace humo).
	var info: Dictionary = PixelFx.DATA.SHEETS[SHEET]
	texture = load(PixelFx.SHEET_DIR % SHEET)
	var material_anim := CanvasItemMaterial.new()
	material_anim.particles_animation = true
	material_anim.particles_anim_h_frames = int(info["columns"])
	material_anim.particles_anim_v_frames = ceili(float(info["count"]) / float(info["columns"]))
	material_anim.particles_anim_loop = false
	material = material_anim
	anim_speed_min = 1.0
	anim_speed_max = 1.0
	set_style_color(Color(0.45, 0.75, 1.0))

func set_style_color(color: Color) -> void:
	if color.is_equal_approx(_color):
		return
	_color = color
	# La hoja es gris: el color de la partícula la tiñe (blanco → color del rango, aclarado en el núcleo).
	var glow: Color = color.lerp(Color.WHITE, 0.35)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(glow, 1.0), Color(color, 0.95), Color(color, 0.6)])
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
