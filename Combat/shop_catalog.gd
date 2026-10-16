extends RefCounted
const STOCK={
	"experience_crystal":{"price":80,"level":1},
	"health":{"price":12,"level":1},"energy":{"price":10,"level":1},"ultimate":{"price":45,"level":1},
	"health_large":{"price":35,"level":10},"energy_large":{"price":30,"level":10},"elixir":{"price":85,"level":30},
	"revival_stone":{"price":180,"level":40},
	"armor":{"price":50,"level":1},"amulet":{"price":60,"level":1},"diving_armor":{"price":70,"level":20},
	"plate_armor":{"price":220,"level":30},"heavy_armor":{"price":360,"level":30},"swift_boots":{"price":160,"level":10},"frost_boots":{"price":260,"level":30},"guardian_charm":{"price":240,"level":30},
	"harpoon":{"price":55,"level":20},"coral_trident":{"price":65,"level":20},"torpedo":{"price":90,"level":20},
	"pili_blade":{"price":600,"level":30},"shock_rifle":{"price":280,"level":30},"flame_rifle":{"price":300,"level":30},"frost_rifle":{"price":320,"level":30},"storm_sword":{"price":260,"level":30},"frost_blade":{"price":280,"level":30},"inferno_axe":{"price":340,"level":30}}
static func entries(category: String) -> Array[String]:
	var result: Array[String]=[]
	for id in STOCK:
		var weapon:=preload("res://Weapons/weapon_registry.gd").all().has(id)
		if (category=="weapons")==weapon: result.append(id)
	return result
