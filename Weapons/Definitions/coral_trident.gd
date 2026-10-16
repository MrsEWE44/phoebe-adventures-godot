extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "coral_trident"
	weapon_name = "珊瑚三叉戟"
	handling_note = "第二章近战武器。普攻不耗能量，攻击距离比短剑更长；对水生敌人伤害×1.6。2-1向导提供一次。"
	kind = "melee"
	damage = 35
	energy_cost = 0
	cooldown = 0.48
	attack_range = 72.0
	projectile_speed = 420.0
	display_width = 36.0
	projectile_width = 16.0
	projectile_hit_radius = 2.5
	explosion_radius = 0.0
	pierce = 0
	drop_enabled = true
	drop_chapters = [2]
	drop_order = 22
	aquatic_multiplier = 1.6
	bounces = 0
	texture = preload("res://Weapons/chapter2_art.gd").texture(2)
	projectile_texture = preload("res://Weapons/chapter2_art.gd").texture(7)
