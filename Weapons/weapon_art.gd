extends RefCounted
## Regions in the generated atlas, including four projectile types.
const REGIONS := [
	Rect2(28,157,241,92),
	Rect2(312,150,333,105),
	Rect2(651,148,315,108),
	Rect2(1005,140,207,140),
	Rect2(39,415,236,155),
	Rect2(324,434,276,110),
	Rect2(639,418,291,140),
	Rect2(960,429,276,106),
	Rect2(33,705,258,158),
	Rect2(322,728,284,115),
	Rect2(639,712,282,151),
	Rect2(965,730,260,126),
	Rect2(65,1044,187,39),
	Rect2(337,1038,247,52),
	Rect2(651,1032,233,64),
	Rect2(1008,1024,180,90),
]
static var atlas: Texture2D

static func texture(index: int) -> AtlasTexture:
	if atlas == null:
		atlas = load("res://Weapons/Generated/weapons_projectiles.png")
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = REGIONS[index]
	return result
