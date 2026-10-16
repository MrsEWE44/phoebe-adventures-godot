extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "plasma_cannon"
	weapon_name = "星辉能量炮"
	kind = "ranged"
	damage = 45
	energy_cost = 8
	cooldown = 0.6
	attack_range = 450
	projectile_speed = 320
	display_width = 31
	drop_order = 11
	damage_type = "magic"
	explosion_radius = 34
	projectile_width = 16
	texture = preload("res://Weapons/weapon_art.gd").texture(11)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(15)
	projectile_hit_radius = 3.5
