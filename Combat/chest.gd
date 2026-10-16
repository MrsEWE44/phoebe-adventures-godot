extends Node2D
@export var chest_id := "chest_1"
@export var reward := "health"
@export_range(8,48,1) var interaction_reach := 24.0
var opened := false
var level: Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	level = get_parent().get_parent()
	reward=preload("res://Weapons/weapon_registry.gd").level_reward(level.level_index,reward)
	if chest_id in Campaign.level_state(level.level_index).opened_chests:
		hide()
		queue_free()
		return
	add_to_group("chests")
	sprite.stop()
	sprite.frame = 0
	sprite.animation_finished.connect(_finish_opening)

func hint() -> String:
	return "E · 打开宝箱"

func interaction_distance(actor: Node2D) -> float:
	if opened or not is_instance_valid(actor): return INF
	var area: Area2D = $InteractionArea
	var shape: RectangleShape2D = $InteractionArea/CollisionShape2D.shape
	var center: Vector2 = actor.combat_center() if actor.has_method("combat_center") else actor.global_position
	var local := area.to_local(center)
	var nearest := area.to_global(local.clamp(-shape.size*.5,shape.size*.5))
	var distance := center.distance_to(nearest)
	if distance > interaction_reach: return INF
	# Walls and sealed doors also prevent reaching through to a chest.
	var ray := PhysicsRayQueryParameters2D.create(center,area.global_position,2)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return INF
	return distance

func interact() -> void:
	if opened or not Campaign.claim_chest(level.level_index,chest_id,reward):
		return
	opened = true
	$InteractionArea/CollisionShape2D.set_deferred("disabled",true)
	Global.play_sfx("chest")
	remove_from_group("chests")
	$Label.hide()
	sprite.play(&"open")

func _finish_opening() -> void:
	if opened:
		hide()
		queue_free()
