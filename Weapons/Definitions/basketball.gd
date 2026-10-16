extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "basketball"
	weapon_name = "弹跳篮球"
	kind = "ranged"
	damage = 26
	energy_cost = 0
	cooldown = 0.46
	attack_range = 380.0
	projectile_speed = 260.0
	display_width = 20.0
	projectile_width = 16.0
	projectile_hit_radius = 5
	explosion_radius = 0.0
	pierce = 1
	drop_enabled = false
	drop_order = 20
	aquatic_multiplier = 1.0
	bounces = 2
	texture = preload("res://Weapons/chapter2_art.gd").texture(0)
	projectile_texture = preload("res://Weapons/chapter2_art.gd").texture(4)
