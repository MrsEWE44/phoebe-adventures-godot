extends RefCounted
const Definition = preload("res://Weapons/weapon_definition.gd")
## Chapter rewards are explicit; shop stock and character loadouts are separate.
const CHAPTER_WEAPONS={1:["bronze_blade","iron_pistol"],2:["coral_trident","harpoon"],3:["resonance_disruptor","penguin_rock"]}
## Removed unused resources; keep IDs only to migrate old saves and reward records.
const RETIRED={"moon_blade":"bronze_blade","ember_launcher":"iron_pistol","dusk_sniper":"iron_pistol","bronze_shotgun":"iron_pistol","pulse_smg":"iron_pistol","ranger_rifle":"iron_pistol","sand_bow":"iron_pistol"}
static var definitions: Dictionary = {}

static func all() -> Dictionary:
	if not definitions.is_empty():
		return definitions
	var fists := Definition.new()
	fists.weapon_id = "fists"
	fists.weapon_name = "徒手"
	fists.kind = "melee"
	fists.damage = 14
	fists.cooldown = .34
	fists.attack_range = 47
	fists.drop_enabled = false
	definitions.fists = fists
	var directory := "res://Weapons/Definitions/"
	for file in DirAccess.get_files_at(directory):
		var path := file.trim_suffix(".remap")
		if not path.ends_with(".gd"):
			continue
		var script: Script = load(directory+path)
		var weapon = script.new()
		if weapon is Definition and not definitions.has(weapon.weapon_id):
			definitions[weapon.weapon_id] = weapon
		else:
			push_error("Invalid or duplicate weapon definition: "+path)
	return definitions

static func get_weapon(id: String) -> Resource:
	var entries := all()
	return entries.get(id, entries.fists)

static func drop_ids() -> Array[String]:
	var weapons: Array = all().values().filter(func(w): return w.drop_enabled)
	weapons.sort_custom(func(a,b): return a.drop_order < b.drop_order if a.drop_order != b.drop_order else a.weapon_id < b.weapon_id)
	var ids: Array[String] = []
	for weapon in weapons:
		ids.append(weapon.weapon_id)
	return ids

static func drops_for_level(index: int) -> Array[String]:
	# Chapter 3 grants the counter gun in 3-9 and Gugu's inherited stone in 3-10.
	# Monsters, chests and random NPC gifts never roll any weapons here.
	if index>=18: return []
	var chapter:=1 if index<=7 else (2 if index<=17 else 3)
	var ids: Array[String]=[]
	for id: String in CHAPTER_WEAPONS.get(chapter,[]):
		var spec: Resource=get_weapon(id)
		if not spec.drop_enabled: continue
		if not spec.drop_levels.is_empty() and index not in spec.drop_levels: continue
		if not spec.drop_chapters.is_empty() and chapter not in spec.drop_chapters: continue
		ids.append(id)
	return ids

static func level_reward(index: int, id: String) -> String:
	id=str(RETIRED.get(id,id))
	if not all().has(id): return id
	var pool:=drops_for_level(index)
	if id in pool: return id
	# Old chest/NPC records must obey the same pool as new monster drops.
	for replacement in pool:
		if get_weapon(replacement).kind==get_weapon(id).kind: return replacement
	return "energy"

static func migrate_inventory(profile: Dictionary) -> void:
	if profile.get("weapons") is Array:
		var owned: Array=[]
		for id in profile.weapons:
			var replacement: String=str(RETIRED.get(id,id))
			if replacement not in owned: owned.append(replacement)
		profile.weapons=owned
	if profile.get("weapon_upgrades") is Dictionary:
		for id in RETIRED:
			if not profile.weapon_upgrades.has(id): continue
			var replacement: String=RETIRED[id]
			profile.weapon_upgrades[replacement]=maxi(int(profile.weapon_upgrades.get(replacement,0)),int(profile.weapon_upgrades[id]))
			profile.weapon_upgrades.erase(id)
	profile.equipped=RETIRED.get(profile.get("equipped","fists"),profile.get("equipped","fists"))
