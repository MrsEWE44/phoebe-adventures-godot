extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="conductor"
	weapon_name="音乐指挥棒"
	kind="ranged"
	damage_type="magic"
	damage=100
	cooldown=0.6
	attack_range=360.0
	texture=preload("res://Art/Chapter4/conductor.svg")
	display_width=38
	drop_enabled=false
	auto_fire=false
