extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="flame_rifle"
 weapon_name="熔火喷射枪"
 kind="ranged"
 damage_type="magic"
 damage=12
 cooldown=0.13
 energy_cost=2
 attack_range=240
 display_width=36
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_1.tres")
 projectile_texture=load("res://Art/Progression/item_7.tres")
 hit_effect="burn"
 drop_order=31
