extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="leek_wave"
	weapon_name="缚魂大葱"
	kind="ranged"
	damage_type="magic"
	damage=68
	cooldown=.65
	attack_range=240
	texture=preload("res://Art/Chapter5/leek_wave.svg")
	display_width=42
	drop_enabled=false
