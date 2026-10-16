extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="inferno_axe"
 weapon_name="烈焰战斧"
 kind="melee"
 damage_type="magic"
 damage=65
 cooldown=0.95
 energy_cost=0
 attack_range=100
 display_width=44
 projectile_width=20
 projectile_hit_radius=5
 texture=load("res://Art/Progression/item_5.tres")
 projectile_texture=load("res://Art/Progression/item_7.tres")
 hit_effect="burn"
 drop_order=35
