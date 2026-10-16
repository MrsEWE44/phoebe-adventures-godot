extends "res://Scence/Chapter3/enemy.gd"
var leap_time:=0.0
var leap_direction:=Vector2.RIGHT
var leap_hit:=false
func _ready() -> void:
	super._ready()
	skill_rank=4 if definition.character_id.ends_with("full") or definition.character_id.begins_with("hell_boss") else 3 if definition.character_id.ends_with("mini") else 2 if definition.character_id.ends_with("small") else 1
	if "_green_" in definition.character_id: speed*=.8
	if "_red_" in definition.character_id: speed*=1.15
func ability_allowed(_action: String) -> bool: return true
func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return
	if emerge_remaining>0: emerge_remaining-=delta;return
	tick_character(delta)
	hit_remaining=maxf(0,hit_remaining-delta)
	_update_reaction()
	if root_remaining>0 or level.player.is_dead: return
	combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	if not is_instance_valid(combat_target): return
	if leap_time>0:
		leap_time-=delta
		velocity=leap_direction*390
		move_and_slide()
		if not leap_hit and combat_target.position.distance_to(position)<55:
			leap_hit=true
			combat_target.take_damage(outgoing(12+skill_rank*9),"physical")
		return
	attack_clock-=delta
	special_clock-=delta
	action_remaining-=delta
	navigation_clock-=delta
	speech_clock-=delta
	if speech_clock<=0: voice.play_event("battle");speech_clock=12
	if not pending.is_empty():
		if action_remaining<=0: execute(pending);pending=""
		queue_redraw()
		return
	var id: String=definition.character_id
	var distance:=position.distance_to(combat_target.position)
	if special_clock<=0 and distance<370:
		var action: String="leap" if id.begins_with("kangaroo") or id.begins_with("dog") else "stomp" if id.begins_with("fatkangaroo") else "spit" if id.begins_with("mouse") else "curse"
		if id.begins_with("hell_boss"):
			var pattern: Array={1:["meteor","stomp"],2:["curse","spit"],3:["leap","stomp"],4:["summon","curse"],5:["summon","spit","meteor"],6:["meteor","summon","curse","leap"]}[int(id.get_slice("_",2))]
			action=pattern[int(record.get("casts",0))%pattern.size()]
		telegraph(action,1.0 if skill_rank<4 else 1.4)
		return
	if attack_clock<=0 and distance<68:
		telegraph("claw",.65)
		return
	if navigation_clock<=0:
		path=level.geometry.path(position,combat_target.position)
		navigation_clock=.6
	while not path.is_empty() and position.distance_to(path[0])<10: path.remove_at(0)
	direction=position.direction_to(path[0]) if not path.is_empty() and distance>45 else Vector2.ZERO
	velocity=direction*speed*movement_factor()
	_update_animation()
	move_and_slide()
	queue_redraw()
func execute(action: String) -> void:
	voice.play_event("skill")
	attack_clock=1.5
	special_clock=4.0 if skill_rank<4 else 6.0
	record.casts=int(record.get("casts",0))+1
	var id: String=definition.character_id
	if action=="claw":
		if is_instance_valid(combat_target) and position.distance_to(combat_target.position)<85: combat_target.take_damage(outgoing(7+skill_rank*7),"physical")
	elif action=="leap":
		leap_direction=position.direction_to(target_point)
		leap_time=.5
		leap_hit=false
	elif action=="spit":
		for i in (3 if skill_rank>=3 else 1):
			var shot=preload("res://Combat/projectile.gd").new()
			shot.position=position
			shot.direction=position.direction_to(target_point).rotated((i-1)*.18 if skill_rank>=3 else 0)
			shot.hostile=true
			shot.damage=outgoing(8+skill_rank*6)
			shot.damage_type="magic"
			shot.speed=210
			shot.distance_left=420
			shot.texture=preload("res://Weapons/chapter3_art.gd").texture(3)
			level.add_child(shot)
	elif action=="summon":
		if int(record.get("generation",0))>=1: return
		for i in 3:
			var child: Node2D=level.spawn_kind(["dog_red_mini","mouse_purple_small","naiwa_green_mini"][i])
			if child!=null: child.record.generation=1
	else:
		var effect=preload("res://Scence/Chapter3/hazard.gd").new()
		effect.position=level.geometry.nearest(target_point) if action=="meteor" else position
		effect.radius=105+skill_rank*12
		effect.damage=outgoing(12+skill_rank*10)
		effect.visual="meteor" if action=="meteor" else "sonic"
		effect.warmup=.7
		effect.tint=Color("c895ff") if "_purple_" in id else Color("ff7951")
		effect.slow=2 if action in ["stomp","curse"] else 0
		effect.bind_time=.6 if "_purple_" in id else 0
		effect.dot=outgoing(4+skill_rank) if "_red_" in id or action=="meteor" else 0
		effect.tick_damage=outgoing(8) if action=="meteor" else 0
		effect.duration=3 if action=="meteor" else .5
		level.add_child(effect)
func take_damage(amount: float,type: String="physical") -> void:
	if "_green_" in definition.character_id and type!="true": amount*=.55
	super.take_damage(amount,type)
func _draw() -> void:
	super._draw()
	if not pending.is_empty() and not is_dead:
		draw_arc(Vector2.ZERO,115,0,TAU,40,Color(1,.3,.1,.7),2)
		if pending=="leap": draw_line(Vector2.ZERO,position.direction_to(target_point)*200,Color(1,.6,.2,.7),25)
