extends RefCounted
const REGIONS = [Rect2(84,130,265,266), Rect2(425,175,440,184), Rect2(887,147,425,235), Rect2(1347,157,399,232), Rect2(49,543,354,208), Rect2(458,596,411,101), Rect2(918,569,410,146), Rect2(1402,504,311,281)]

static func texture(index: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://Art/Chapter2/weapons.png")
	atlas.region = REGIONS[index]
	return atlas
