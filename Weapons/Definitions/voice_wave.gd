extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="voice_wave"
	weapon_name="主唱声波"
	kind="ranged"
	damage_type="magic"
	damage=18
	cooldown=0.6
	attack_range=360.0
	texture=preload("res://Art/Chapter4/voice_wave.svg")
	display_width=0
	drop_enabled=false
	auto_fire=true
