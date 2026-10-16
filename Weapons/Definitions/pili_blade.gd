extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="pili_blade"
	weapon_name="屠龙刀"
	kind="melee"
	damage=48
	cooldown=.58
	attack_range=88
	display_width=55
	melee_half_angle=1.2
	texture=load("res://Art/CombatUpdate/pili_blade.tres")
	drop_order=24
	special_attack=SpecialAttack.THUNDER_CRESCENT
	special_name="一刀999"
	special_damage=999
	special_fixed_damage=true
	special_damage_type="true"
	special_energy_cost=40
	special_cooldown=6.0
	special_range=520
	special_radius=170
	special_animation=load("res://Art/CombatUpdate/thunder_crescent.tres")
