extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id = "phoebe_relic"
	weapon_name = "星环圣杖"
	drop_enabled = false
	damage = 90
	damage_type = "magic"
	texture = preload("res://Weapons/weapon_art.gd").texture(9)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(15)
	display_width = 34
