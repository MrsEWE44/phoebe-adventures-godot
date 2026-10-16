extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "harpoon"
	weapon_name = "潮猎鱼叉枪"
	handling_note = "第二章远程武器。每发消耗2能量，贯穿一个目标；对水生敌人伤害×1.6。能量不足时切换三叉戟。"
	kind = "ranged"
	damage = 30
	energy_cost = 2
	cooldown = 0.42
	attack_range = 560.0
	projectile_speed = 520.0
	display_width = 32.0
	projectile_width = 20.0
	projectile_hit_radius = 2.5
	explosion_radius = 0.0
	pierce = 1
	drop_enabled = true
	drop_chapters = [2]
	drop_order = 21
	aquatic_multiplier = 1.6
	bounces = 0
	texture = preload("res://Weapons/chapter2_art.gd").texture(1)
	projectile_texture = preload("res://Weapons/chapter2_art.gd").texture(5)
