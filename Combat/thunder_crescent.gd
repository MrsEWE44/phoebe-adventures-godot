extends Node2D
var actor: Node2D
var spec: Resource
var aim:=Vector2.RIGHT
var age:=0.0
var travelled:=0.0
var damage:=0.0
var hit_ids: Dictionary={}
var animation: AnimatedSprite2D
func _ready() -> void:
	add_to_group("weapon_specials")
	position=get_parent().to_local(actor.combat_center())
	if aim.is_zero_approx(): aim=actor.facing
	aim=aim.normalized()
	damage=spec.special_damage if spec.special_fixed_damage else actor.attack_damage(spec.special_damage,true)
	rotation=aim.angle()
	animation=AnimatedSprite2D.new()
	animation.sprite_frames=spec.special_animation
	animation.play("slash")
	animation.pause()
	animation.scale=Vector2(spec.special_radius*1.3/animation.sprite_frames.get_frame_texture("slash",0).get_width(),spec.special_radius*2/animation.sprite_frames.get_frame_texture("slash",0).get_height())
	add_child(animation)
	z_index=5
	get_node("/root/Global").play_sfx("seal")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead:
		queue_free()
		return
	age+=delta
	if age<.18: return
	var start:=global_position
	var end:=start+aim*minf(delta*780,spec.special_range-travelled)
	var wall:=get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start,end,2))
	if not wall.is_empty(): end=wall.position-aim*2
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if hit_ids.has(enemy.get_instance_id()): continue
		var center: Vector2=enemy.combat_center()
		var closest:=Geometry2D.get_closest_point_to_segment(center,start,end)
		if center.distance_to(closest)>spec.special_radius or (center-start).dot(aim)<-12: continue
		var sight:=get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(closest,center,2))
		if sight.is_empty():
			hit_ids[enemy.get_instance_id()]=true
			preload("res://Combat/player_damage.gd").hit(actor,enemy,damage,spec.special_damage_type)
	travelled+=start.distance_to(end)
	global_position=end
	animation.frame=mini(7,int(travelled/spec.special_range*8))
	if travelled>=spec.special_range or not wall.is_empty() or age>1.2: queue_free()
