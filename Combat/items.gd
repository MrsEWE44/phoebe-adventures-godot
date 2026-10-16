extends RefCounted
const Weapons = preload("res://Weapons/weapon_registry.gd")

const ITEMS := {
	"time_capsule":{"name":"时空胶囊","kind":"key","icon_path":"res://UI/Icons/time_capsule.svg"},
	"battle_overdrive":{"name":"破甲战歌","kind":"key","icon_path":"res://UI/Icons/battle_overdrive.svg"},
	"travel_scroll":{"name":"传送卷轴","kind":"key","icon_path":"res://UI/Icons/travel_scroll.svg"},
	"experience_crystal":{"name":"经验结晶","kind":"consumable","experience":100,"icon_path":"res://UI/Icons/experience_crystal.svg"},
	"revival_stone":{"name":"复苏晶石","kind":"consumable","icon_path":"res://UI/Icons/revival_stone.svg"},
	"diving_armor": {"name":"深潜护甲", "kind":"equipment", "physical_defense":3, "magic_defense":6,"icon_path":"res://UI/Icons/diving_armor.svg"},
	"armor": {"name": "青铜护甲", "kind": "armor", "physical_defense": 8, "magic_defense": 2,"icon_index":12},
	"amulet": {"name": "守护护符", "kind": "amulet", "physical_defense": 2, "magic_defense": 10,"icon_path":"res://UI/Icons/amulet.svg"},
	"health": {"name": "生命药剂", "kind": "consumable", "restore": 40,"icon_index":9},
	"energy": {"name": "技能药剂", "kind": "consumable", "restore": 70,"icon_index":10},
	"ultimate": {"name": "绝杀药剂", "kind": "consumable", "restore": 1,"icon_index":11},
	"health_large":{"name":"大型生命药剂","kind":"consumable","health_ratio":0.8,"icon_index":9},
	"energy_large":{"name":"大型技能瓶","kind":"consumable","energy_restore":200,"icon_index":10},
	"elixir":{"name":"全效秘药","kind":"consumable","health_ratio":1.0,"energy_restore":200,"icon_index":11},
	"plate_armor":{"name":"秘银护甲","kind":"gear","slot":"body","physical_defense":35,"magic_defense":25,"icon_index":12},
	"heavy_armor":{"name":"黄金重铠","kind":"gear","slot":"body","physical_defense":65,"magic_defense":40,"speed_bonus":-0.08,"icon_index":13},
	"swift_boots":{"name":"疾风鞋","kind":"gear","slot":"feet","physical_defense":8,"magic_defense":8,"speed_bonus":0.22,"icon_index":14},
	"frost_boots":{"name":"霜行战靴","kind":"gear","slot":"feet","physical_defense":18,"magic_defense":25,"speed_bonus":0.12,"slow_resist":0.5,"icon_index":15},
	"guardian_charm":{"name":"守护晶核","kind":"gear","slot":"charm","physical_defense":20,"magic_defense":50,"icon_path":"res://UI/Icons/guardian_charm.svg"},
}


static func item(id: String) -> Dictionary:
	if not ITEMS.has(id): return Weapons.get_weapon(id).item_data()
	var data: Dictionary=ITEMS[id].duplicate()
	if data.has("icon_index"): data.texture=load("res://Art/Progression/item_%d.tres"%data.icon_index)
	elif data.has("icon_path"): data.texture=load(data.icon_path)
	return data

static func has_item(id: String) -> bool:
	return ITEMS.has(id) or Weapons.all().has(id)

static func short_description(id: String) -> String:
	var notes: Dictionary={"experience_crystal":"使用 +100 经验；满级不消耗。B → 道具使用。","health":"恢复40%最大生命；Q / 背包使用。","energy":"恢复70能量；R / 背包使用。","ultimate":"增加1次大招；T使用，Q币企鹅不适用。","health_large":"恢复80%最大生命；2 / 背包使用。","energy_large":"恢复200能量；3 / 背包使用。","elixir":"当前角色生命与能量全满；4 / 背包使用。","revival_stone":"仅主场景复活一位倒下队友；B → 角色选目标。"}
	if notes.has(id): return notes[id]
	var data:=item(id)
	if Weapons.all().has(id):
		var spec:=Weapons.get_weapon(id)
		var text:="%s · 基础伤害%d · 每击%d能量"%["近战" if spec.kind=="melee" else "远程",spec.damage,spec.energy_cost]
		if spec.aquatic_multiplier>1: text+=" · 克制水生敌人"
		if spec.special_attack: text+=" · V："+spec.special_name
		if not spec.hit_effect.is_empty(): text+=" · "+str({"burn":"持续灼烧","shock":"电弧麻痹","frost":"冻结减速","silence":"沉默首领"}.get(spec.hit_effect,spec.hit_effect))
		return text
	var text:="物防+%d / 法防+%d"%[data.get("physical_defense",0),data.get("magic_defense",0)]
	if data.has("speed_bonus"): text+=" · 移速%+d%%"%roundi(data.speed_bonus*100)
	return text+(" · B中装备，同槽替换" if data.kind=="gear" else " · 持有自动生效")

static func weapon_ids() -> Array[String]:
	var ids:=Weapons.drop_ids()
	ids.append("penguin_rock")
	ids.append_array(["music_drums","conductor"])
	return ids

static func enemy_drop(level_index: int, boss:=false, rng: RandomNumberGenerator=null) -> String:
	if rng==null:
		rng=RandomNumberGenerator.new()
		rng.randomize()
	if rng.randf()>=(.65 if boss else .24): return ""
	var roll:=rng.randf()
	if roll<.60:
		var supplies: Array[String]=["health","health","health","energy","energy","energy","health_large","energy_large","ultimate","elixir","experience_crystal"]
		return supplies[rng.randi_range(0,supplies.size()-1)]
	if roll<.90:
		var weapons:=Weapons.drops_for_level(level_index)
		return weapons[rng.randi_range(0,weapons.size()-1)] if not weapons.is_empty() else "energy"
	var gear: Array[String]=["armor","amulet","swift_boots","plate_armor","guardian_charm"]
	return gear[rng.randi_range(0,gear.size()-1)]
