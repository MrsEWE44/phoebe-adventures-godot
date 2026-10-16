extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "sun_spear"
	weapon_name = "烈阳长枪"
	kind = "melee"
	damage = 33
	energy_cost = 0
	cooldown = 0.48
	attack_range = 72
	projectile_speed = 0
	display_width = 35
	drop_order = 3
	texture = preload("res://Weapons/weapon_art.gd").texture(1)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(12)
