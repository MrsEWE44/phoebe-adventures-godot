extends RefCounted
const Shot=preload("res://Combat/projectile.gd")
const Art=preload("res://Weapons/chapter3_art.gd")
static func shot(actor: Node2D, aim: Vector2, damage: int, texture_index: int, homing:=false, radius:=0.0) -> Node2D:
	var projectile=Shot.new()
	projectile.source_actor=weakref(actor)
	projectile.position=actor.position+Vector2(0,-12)
	var obstruction:=actor.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(actor.global_position,projectile.position,2))
	if not obstruction.is_empty(): projectile.position=obstruction.position+Vector2(0,2)
	projectile.direction=aim
	projectile.damage=actor.attack_damage(damage,true)
	projectile.damage_type="magic"
	projectile.speed=430
	projectile.distance_left=650
	projectile.hit_radius=6
	projectile.display_width=22
	projectile.texture=Art.texture(texture_index)
	projectile.homing=homing
	projectile.explosion_radius=radius
	actor.get_parent().add_child(projectile)
	return projectile
static func skill(actor: Node2D, aim: Vector2, ultimate:=false) -> void:
	match str(actor.current_character):
		"doro":
			if ultimate:
				for i in 5:
					var flower=preload("res://Scence/Chapter3/hazard.gd").new()
					var offset:=aim.rotated((i-2)*.5)*(80+i%2*40)
					flower.position=actor.position+offset
					if actor.get_parent().get("geometry")!=null: flower.position=actor.get_parent().geometry.nearest(flower.position)
					flower.source_actor=weakref(actor)
					flower.radius=85
					flower.damage=actor.attack_damage(45,true)
					flower.tick_damage=actor.attack_damage(36,true)
					flower.warmup=.5
					flower.duration=6
					flower.hostile=false
					flower.visual="flower"
					flower.tint=Color("ffc34f")
					actor.get_parent().add_child(flower)
			else:
				for i in 3: shot(actor,aim.rotated((i-1)*.2),55,3,true,80)
		"gugu":
			var dash=preload("res://Scence/Chapter3/dash.gd").new()
			dash.actor=actor
			dash.aim=aim
			dash.damage=actor.attack_damage(300 if ultimate else 200,true)
			dash.belly=true
			actor.get_parent().add_child(dash)
	actor.voice.play_event("ultimate" if ultimate else "skill")
static func stone_rain(actor: Node2D, aim: Vector2) -> void:
	for i in 7: shot(actor,aim.rotated((i-3)*.14),65,5,false,38)
static func meteor(actor: Node2D, aim: Vector2) -> void:
	var crater=preload("res://Scence/Chapter3/hazard.gd").new()
	var target: Vector2=actor.get_global_mouse_position()
	var offset:=target-actor.global_position
	if offset.length()>380: target=actor.global_position+aim*380
	crater.position=target
	if actor.get_parent().get("geometry")!=null: crater.position=actor.get_parent().geometry.nearest(target)
	crater.source_actor=weakref(actor)
	crater.radius=110
	crater.damage=actor.attack_damage(240,true)
	crater.tick_damage=actor.attack_damage(40,true)
	crater.duration=6
	crater.friendly_fire=true
	actor.get_parent().add_child(crater)
	actor.get_node("/root/Campaign").message.emit("陨石落点已标记！陨坑会伤害玩家、怪物和 BOSS。")
