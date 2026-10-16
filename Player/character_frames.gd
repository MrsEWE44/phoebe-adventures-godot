extends RefCounted

static func phoebe() -> SpriteFrames:
	return load("res://Characters/Animations/phoebe.tres")

static func nuonuo() -> SpriteFrames:
	return load("res://Characters/Animations/nuonuo.tres")

static func creature(kind: int) -> SpriteFrames:
	var texture: Texture2D = load("res://Art/Creatures/desert_creatures.png")
	var crops := [Rect2(48,116,284,226), Rect2(24,64,328,240), Rect2(36,4,312,302)]
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 7)
	for col in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var crop: Rect2 = crops[kind]
		atlas.region = Rect2(crop.position + Vector2(col * 362, kind * 362), crop.size)
		frames.add_frame(&"default", atlas)
	return frames
