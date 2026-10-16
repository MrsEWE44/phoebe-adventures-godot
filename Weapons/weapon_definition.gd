class_name WeaponDefinition
extends Resource
enum SpecialAttack { NONE, THUNDER_CRESCENT, DECISIVE_CANNON, METEOR, EXPLOSIVE_ROUND, PIERCING_ROUND }
## Inherit this class in Weapons/Definitions/*.gd; the registry discovers it.
@export var weapon_id := "new_weapon"
@export var weapon_name := "新武器"
@export_multiline var handling_note := ""
@export_enum("melee", "ranged") var kind := "ranged"
@export_enum("physical", "magic", "true") var damage_type := "physical"
@export_range(1,999) var damage := 20
@export_range(0,200) var energy_cost := 0
@export_range(.05,5,.01) var cooldown := .3
@export_range(10,1200) var attack_range := 420.0
@export var texture: Texture2D
@export var projectile_texture: Texture2D
@export var display_width := 30.0
@export var projectile_width := 14.0
## Zero derives the projectile radius from its visible height.
@export_range(0,12,.25) var projectile_hit_radius := 0.0
@export_range(.2,1.6,.05) var melee_half_angle := .9
@export var projectile_speed := 420.0
@export_range(1,12) var pellets := 1
@export_range(0,90) var spread_degrees := 0.0
@export_range(0,200) var explosion_radius := 0.0
@export_range(0,6) var pierce := 0
@export var orbit_radius := 13.0
@export var recoil := 3.0
@export var drop_enabled := true
@export var drop_order := 10
@export_range(1,3,.1) var aquatic_multiplier := 1.0
@export_range(0,5) var bounces := 0
@export var special_attack: SpecialAttack = SpecialAttack.NONE
@export var special_name := ""
@export var special_damage := 150
@export var special_fixed_damage := false
@export_enum("physical", "magic", "true") var special_damage_type := "magic"
@export var special_energy_cost := 45
@export var special_cooldown := 7.0
@export var special_range := 260.0
@export var special_radius := 75.0
@export var special_animation: SpriteFrames
@export var homing:=false
@export var auto_fire:=false
@export var boss_multiplier:=1.0
@export var hit_effect:=""
## Empty lists mean a general drop. Ownership/use is independent of drop location.
@export var drop_chapters: Array[int]=[]
@export var drop_levels: Array[int]=[]
@export var target_multipliers: Dictionary={}
## Minimum fraction of target maximum HP; applied before a critical hit.
@export var target_health_ratios: Dictionary={}
@export_range(0,1,.01) var critical_chance:=0.0
@export var critical_multiplier:=1.8
@export_range(0,8) var chain_targets:=0
@export var chain_radius:=175.0

func item_data() -> Dictionary:
	return {"name":weapon_name,"kind":kind,"damage":damage,"damage_type":damage_type,
		"cost":energy_cost,"cooldown":cooldown,"range":attack_range,"texture":texture}

