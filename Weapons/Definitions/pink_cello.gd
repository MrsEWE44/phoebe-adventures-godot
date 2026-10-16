extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="pink_cello"
	weapon_name="粉色大提琴"
	kind="ranged"
	damage_type="magic"
	damage=42
	cooldown=0.6
	attack_range=360.0
	texture=preload("res://Art/Chapter4/pink_cello.svg")
	display_width=38
	drop_enabled=false
	auto_fire=false
