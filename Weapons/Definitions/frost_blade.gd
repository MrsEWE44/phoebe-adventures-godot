extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="frost_blade"
 weapon_name="寒霜巨剑"
 kind="melee"
 damage_type="magic"
 damage=55
 cooldown=0.8
 energy_cost=0
 attack_range=95
 display_width=44
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_4.tres")
 projectile_texture=load("res://Art/Progression/item_8.tres")
 hit_effect="frost"
 drop_order=34
