extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="storm_sword"
 weapon_name="雷鸣剑"
 kind="melee"
 damage_type="magic"
 damage=45
 cooldown=0.6
 energy_cost=0
 attack_range=85
 display_width=44
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_3.tres")
 projectile_texture=load("res://Art/Progression/item_6.tres")
 hit_effect="shock"
 drop_order=33
