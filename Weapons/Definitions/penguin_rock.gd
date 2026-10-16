extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="penguin_rock"
 weapon_name="凑企鹅原石"
 kind="ranged"
 damage=110
 energy_cost=0
 cooldown=0.7
 attack_range=560
 texture=preload("res://Weapons/chapter3_art.gd").texture(5)
 projectile_texture=preload("res://Weapons/chapter3_art.gd").texture(5)
 display_width=24
 projectile_width=18
 projectile_hit_radius=6
 projectile_speed=360
 drop_enabled=false
 special_attack=SpecialAttack.METEOR
 special_damage=240
 special_name="天陨 · 无差别伤害"
 special_energy_cost=35
 special_cooldown=12
