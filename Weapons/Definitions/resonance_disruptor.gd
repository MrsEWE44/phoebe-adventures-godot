extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="resonance_disruptor"
	weapon_name="静音共振枪"
	kind="ranged"
	damage_type="true"
	damage=220
	energy_cost=4
	cooldown=.85
	attack_range=650
	projectile_speed=520
	display_width=38
	projectile_width=18
	projectile_hit_radius=4
	texture=preload("res://Weapons/weapon_art.gd").texture(11)
	projectile_texture=load("res://Art/Progression/item_8.tres")
	drop_levels=[26]
	drop_order=40
	target_health_ratios={"naiwa_minion":1.0,"penguin_minion":1.0,"naiwa_mini":.6,"penguin_mini":.6,"naiwa_full":.18,"penguin_full":.18}
	critical_chance=.3
	critical_multiplier=1.8
	chain_targets=5
	chain_radius=175
	hit_effect="silence"
