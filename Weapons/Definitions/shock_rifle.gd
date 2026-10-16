extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="shock_rifle"
 weapon_name="电弧冲击枪"
 kind="ranged"
 damage_type="magic"
 damage=35
 cooldown=0.38
 energy_cost=2
 attack_range=550
 display_width=36
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_0.tres")
 projectile_texture=load("res://Art/Progression/item_6.tres")
 hit_effect="shock"
 drop_order=30
