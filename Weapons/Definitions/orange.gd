extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="orange"
 weapon_name="Doro 追踪橘子"
 kind="ranged"
 damage=14
 energy_cost=0
 cooldown=0.4
 attack_range=560
 texture=preload("res://Weapons/chapter3_art.gd").texture(2)
 projectile_texture=preload("res://Weapons/chapter3_art.gd").texture(2)
 display_width=19
 projectile_width=18
 projectile_hit_radius=6
 projectile_speed=360
 drop_enabled=false
 damage_type="magic"
 homing=true
 auto_fire=true
 explosion_radius=38
