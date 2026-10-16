extends Node2D
## Random skills share a guarded lifecycle: windup, action, and cancellation.
var actor: Node2D
var mode:=0 # 0: piercing pass; 1: dribble drive with a bounded explosion trail.
var aim:=Vector2.RIGHT
var boosted:=false
var age:=0.0
var travelled:=0.0
var last_blast:=0.0
var released:=false
var hit_ids: Dictionary={}
var ball: Sprite2D
var owner_character:="ikun"
func _ready() -> void:
	add_to_group("basketball_skills")
	aim=(actor.facing if aim.is_zero_approx() else aim).normalized()
	position=actor.position
	ball=Sprite2D.new()
	ball.texture=preload("res://Weapons/chapter2_art.gd").texture(0)
	ball.scale=Vector2.ONE*18/ball.texture.get_width()
	add_child(ball)
	z_index=5
	actor.weapon_mount.hide()
	if mode==0 and actor.cast_sprite!=null:
		actor.animated_sprite.hide()
		actor.cast_sprite.show()
		actor.cast_sprite.flip_h=aim.x<0
		actor.cast_sprite.play("ultimate")
	get_node("/root/Campaign").message.emit("运球突破！" if mode==1 else "穿线重传！")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead or actor.current_character!=owner_character:
		queue_free()
		return
	age+=delta
	position=actor.position
	ball.position=aim*17+Vector2(0,-8-absf(sin(age*20))*15)
	if age<(.38 if mode==1 else .22): return
	if mode==0:
		if not released:
			released=true
			var shot=preload("res://Combat/projectile.gd").new()
			shot.source_actor=weakref(actor)
			shot.position=actor.position+Vector2(0,-12)
			var muzzle_wall:=get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(actor.global_position,shot.position,2))
			if not muzzle_wall.is_empty():
				shot.position=muzzle_wall.position+Vector2(0,2)
			shot.direction=aim
			shot.texture=ball.texture
			shot.display_width=23
			shot.hit_radius=7
			shot.speed=850
			shot.damage=round(actor.attack_damage(130,true)*(1.8 if boosted else 1.0))
			shot.damage_type="magic"
			shot.pierce_left=100
			shot.bounces_left=0
			shot.explosion_radius=0
			shot.distance_left=720
			get_parent().add_child(shot)
		queue_free()
		return
	var step:=aim*minf(330*delta,190-travelled)
	var origin: Vector2=actor.position
	var collision: KinematicCollision2D=actor.move_and_collide(step)
	if get_parent().has_method("is_spawn_safe") and get_parent().is_spawn_safe(actor.position):
		actor.position=origin
		queue_free()
		return
	travelled+=actor.position.distance_to(origin)
	position=actor.position
	actor.direction=aim
	actor.facing=aim
	actor._update_animation()
	if travelled-last_blast>=32 or collision!=null or travelled>=190:
		last_blast=travelled
		blast()
	if collision!=null or travelled>=190 or age>1.4:
		actor.velocity=Vector2.ZERO
		queue_free()
func blast() -> void:
	var radius:=62.0*(1.2 if actor.home_buff else 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if hit_ids.has(enemy.get_instance_id()): continue
		var center: Vector2=enemy.combat_center()
		if center.distance_to(global_position)>radius: continue
		var wall:=get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,center,2))
		if wall.is_empty():
			hit_ids[enemy.get_instance_id()]=true
			preload("res://Combat/player_damage.gd").hit(actor,enemy,round(actor.attack_damage(100,true)*(1.8 if boosted else 1.0)),"magic")
	var effect=preload("res://Combat/impact_effect.gd").new()
	effect.position=position
	effect.radius=radius
	effect.tint=Color("ffb347")
	get_parent().add_child(effect)
	get_node("/root/Global").play_sfx("impact")
func _exit_tree() -> void:
	if is_instance_valid(actor):
		actor.direction=Vector2.ZERO
		actor.velocity=Vector2.ZERO
		actor.basketball_skill=null
		if actor.cast_sprite!=null: actor.cast_sprite.hide()
		if not actor.is_dead: actor.animated_sprite.show()
		if is_instance_valid(actor.weapon_mount): actor.weapon_mount.visible=not actor.is_dead
