extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "bronze_blade"
	weapon_name = "青铜短剑"
	handling_note = "第一章近战武器。普攻不耗能量；贴近后横扫，躲开预警再反击。1-1向导提供一次，遗迹中也可找到。"
	kind = "melee"
	damage = 25
	energy_cost = 0
	cooldown = 0.28
	attack_range = 52
	projectile_speed = 0
	display_width = 24
	drop_order = 0
	texture = preload("res://Weapons/weapon_art.gd").texture(0)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(12)
