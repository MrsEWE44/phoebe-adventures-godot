extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "iron_pistol"
	weapon_name = "遗迹手枪"
	handling_note = "第一章远程武器。普攻不耗能量，适合沿狭路边退边射；子弹受墙体阻挡。1-1固定宝箱可获得。"
	kind = "ranged"
	damage = 18
	energy_cost = 0
	cooldown = 0.3
	attack_range = 420
	projectile_speed = 460
	display_width = 20
	drop_order = 5
	texture = preload("res://Weapons/weapon_art.gd").texture(3)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(12)

	projectile_width = 10
	projectile_hit_radius = 1.6
