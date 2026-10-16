extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "rune_staff"
	weapon_name = "符文法杖"
	kind = "ranged"
	damage = 38
	energy_cost = 6
	cooldown = 0.4
	attack_range = 400
	projectile_speed = 290
	display_width = 28
	drop_order = 2
	damage_type = "magic"
	texture = preload("res://Weapons/weapon_art.gd").texture(9)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(15)

	projectile_width = 16
	projectile_hit_radius = 3.5
