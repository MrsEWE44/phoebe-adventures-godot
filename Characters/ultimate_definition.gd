class_name UltimateDefinition
extends Resource
@export var display_name := "绝杀"
@export_enum("area", "shot", "support") var mode := "area"
@export var damage := 90.0
@export var radius := 110.0
@export var projectile_speed := 500.0
@export var projectile_range := 650.0
@export_range(1,5) var projectile_count := 1
@export_range(0,5) var initial_charges := 3
@export_range(1,5) var max_charges := 5
@export var cooldown := 2.0
@export_range(.05,5,.05) var windup := .55
@export var weapon_id := "rune_staff"
@export var key: Key = KEY_F
@export var tint := Color("d6b2ff")
@export var empowered := false
@export var impact_radius := 0.0
@export var pierce := 2
@export var bounces := 1
@export var pulse_count := 0
