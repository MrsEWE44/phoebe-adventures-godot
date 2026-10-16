extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="music_drums"
	weapon_name="共振架子鼓"
	kind="ranged"
	damage_type="magic"
	damage=90
	cooldown=1.0
	attack_range=360.0
	texture=preload("res://Art/Chapter4/music_drums.svg")
	display_width=38
	drop_enabled=false
	auto_fire=false
