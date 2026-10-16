extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id = "nuonuo_relic"
	weapon_name = "星辉绝杀炮"
	drop_enabled = false
	damage = 150
	damage_type = "magic"
	texture = preload("res://Weapons/weapon_art.gd").texture(11)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(15)
	display_width = 34
