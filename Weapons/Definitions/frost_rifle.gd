extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="frost_rifle"
 weapon_name="冰封步枪"
 kind="ranged"
 damage_type="magic"
 damage=42
 cooldown=0.6
 energy_cost=2
 attack_range=530
 display_width=36
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_2.tres")
 projectile_texture=load("res://Art/Progression/item_8.tres")
 hit_effect="frost"
 drop_order=32
