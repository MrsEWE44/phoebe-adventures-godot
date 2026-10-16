extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="penguin_wing"
 weapon_name="咕咕嘎嘎双翼"
 kind="melee"
 damage=115
 energy_cost=0
 cooldown=0.5
 attack_range=72
 texture=preload("res://Weapons/chapter3_art.gd").texture(7)
 projectile_texture=preload("res://Weapons/chapter3_art.gd").texture(7)
 display_width=28
 projectile_width=18
 projectile_hit_radius=6
 projectile_speed=360
 drop_enabled=false
