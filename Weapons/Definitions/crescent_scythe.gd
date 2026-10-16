extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="crescent_scythe"
	weapon_name="赤月大镰刀"
	kind="ranged"
	damage_type="magic"
	damage=180
	cooldown=.65
	attack_range=240
	texture=preload("res://Art/Chapter5/crescent_scythe.svg")
	display_width=42
	drop_enabled=false
