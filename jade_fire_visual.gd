extends RefCounted

const TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_jade_fire.png")
const COLOR := Color(0.25, 0.53, 0.42)

static func icon_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE
	atlas.region = Rect2(Vector2.ZERO, TEXTURE.get_size() * 0.5)
	return atlas
