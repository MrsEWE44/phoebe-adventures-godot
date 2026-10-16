extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
 weapon_id="q_ak"
 weapon_name="Q 币 AK47"
 kind="ranged"
 damage=26
 energy_cost=0
 cooldown=0.4
 attack_range=720
 texture=preload("res://Weapons/chapter3_art.gd").texture(0)
 projectile_texture=preload("res://Weapons/chapter3_art.gd").texture(1)
 display_width=42
 projectile_width=18
 projectile_hit_radius=6
 projectile_speed=360
 drop_enabled=false
 boss_multiplier=1.0
 explosion_radius=0
 special_attack=SpecialAttack.PIERCING_ROUND
 special_name="贯穿弹头 · 15秒"
 special_damage=900
 special_radius=0
 special_energy_cost=0
 special_cooldown=15
