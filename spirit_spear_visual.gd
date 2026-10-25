extends RefCounted

const TEXTURE: Texture2D = preload("res://assets/sprites/player/viridy/viridy_spirit_spear_v1.png")

static func icon_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE
	atlas.region = Rect2(0, 0, 768, 192)
	return atlas
