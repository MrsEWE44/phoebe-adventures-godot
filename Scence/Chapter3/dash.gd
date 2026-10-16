extends Node2D
var actor: CharacterBody2D
var aim:=Vector2.RIGHT
var damage:=180.0
var friendly_fire:=false
var belly:=false
var elapsed:=0.0
var distance:=0.0
var hit: Dictionary={}
var original_mask:=0
@export var windup:=.25
@export var travel_range:=260.0
@export var travel_speed:=480.0
@export var hit_radius:=42.0
var original_definition: Resource
var original_rotation:=0.0
var original_scale:=Vector2.ONE
func _ready() -> void:
	add_to_group("arena_hazards")
	aim=aim.normalized() if not aim.is_zero_approx() else actor.facing
	position=actor.position
	original_mask=actor.collision_mask
	original_definition=actor.definition
	original_rotation=actor.animated_sprite.rotation
	original_scale=actor.animated_sprite.scale
	actor.collision_mask=2
	actor.set_meta("chapter3_dashing",true)
	if belly:
		actor.animated_sprite.rotation=-PI/2 if aim.x>=0 else PI/2
		actor.animated_sprite.scale.y*=.75
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead or actor.definition!=original_definition: queue_free();return
	elapsed+=delta
	if elapsed<windup: queue_redraw();return
	var before:=actor.global_position
	var center_offset: Vector2=actor.combat_center()-before
	var collision:=actor.move_and_collide(aim*minf(travel_speed*delta*actor.movement_factor(),travel_range-distance))
	distance+=before.distance_to(actor.global_position)
	position=actor.position
	for target in get_tree().get_nodes_in_group("characters" if friendly_fire else "enemies"):
		if target==actor or target.is_dead or target.character_type==target.CharacterType.NPC or hit.has(target.get_instance_id()): continue
		var center: Vector2=target.combat_center()
		var closest:=Geometry2D.get_closest_point_to_segment(center,before+center_offset,actor.global_position+center_offset)
		if center.distance_to(closest)>hit_radius+target.combat_radius(): continue
		if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(closest,center,2)).is_empty(): continue
		hit[target.get_instance_id()]=true
		preload("res://Combat/player_damage.gd").hit(actor,target,damage,"physical")
		var impact:=preload("res://Combat/impact_effect.gd").new()
		impact.position=get_parent().to_local(center)
		impact.radius=30
		get_parent().call_deferred("add_child",impact)
	if collision!=null or distance>=travel_range-.1 or elapsed>windup+1.3: queue_free()
	queue_redraw()
func _draw() -> void:
	draw_line(-aim*40,Vector2.ZERO,Color(.8,.95,1,.5),18)
func _exit_tree() -> void:
	if is_instance_valid(actor):
		actor.collision_mask=original_mask
		actor.set_meta("chapter3_dashing",false)
		if actor.definition==original_definition:
			actor.animated_sprite.rotation=original_rotation
			actor.animated_sprite.scale=original_scale
