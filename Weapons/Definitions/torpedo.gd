extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "torpedo"
	weapon_name = "深海鱼雷炮"
	kind = "ranged"
	damage = 58
	energy_cost = 8
	cooldown = 1.05
	attack_range = 480.0
	projectile_speed = 270.0
	display_width = 36.0
	projectile_width = 22.0
	projectile_hit_radius = 2.5
	explosion_radius = 62.0
	pierce = 0
	drop_enabled = true
	drop_chapters = [2]
	drop_order = 23
	aquatic_multiplier = 1.6
	bounces = 0
	texture = preload("res://Weapons/chapter2_art.gd").texture(3)
	projectile_texture = preload("res://Weapons/chapter2_art.gd").texture(6)
