extends "res://Scence/Chapter3/enemy.gd"
var leap_remaining:=0.0
var leap_aim:=Vector2.RIGHT
var leap_hit:=false
func _physics_process(delta: float) -> void:
	if is_dead or not definition.character_id.begins_with("tensura") and not definition.character_id.begins_with("weiro"):
		super._physics_process(delta)
		return
	if emerge_remaining>0: emerge_remaining-=delta;return
	tick_character(delta)
	speech_clock-=delta
	if speech_clock<=0:
		voice.play_event("angry" if health<max_health*.35 else "battle")
		speech_clock=randf_range(9,14)
	hit_remaining=maxf(0,hit_remaining-delta)
	_update_reaction()
	queue_redraw()
	if level.player.is_dead or root_remaining>0: return
	combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	if leap_remaining>0:
		leap_remaining-=delta
		velocity=leap_aim*420
		move_and_slide()
		animated_sprite.rotation=sin(leap_remaining*20)*.12
		if not leap_hit and position.distance_to(combat_target.position)<44:
			leap_hit=true
			combat_target.take_damage(outgoing(35+skill_rank*15),"physical")
		if leap_remaining<=0: animated_sprite.rotation=0
		return
	attack_clock-=delta
	special_clock-=delta
	action_remaining-=delta
	if not pending.is_empty():
		if action_remaining<=0: execute(pending);pending=""
		queue_redraw()
		return
	if special_clock<=0 and skill_rank==3:
		telegraph("music_summon",1.8);return
	if attack_clock<=0:
		var has_hands: bool=definition.character_id.begins_with("weiro")
		var attack: String="punch" if has_hands and position.distance_to(combat_target.position)<78 else ("beam" if has_hands and skill_rank>=2 and randi()%2==0 else "leap")
		telegraph(attack,1.1)
		return
	navigation_clock-=delta
	if navigation_clock<=0:
		path=level.geometry.path(position,combat_target.position)
		navigation_clock=.7
	while not path.is_empty() and position.distance_to(path[0])<10: path.remove_at(0)
	direction=position.direction_to(path[0]) if not path.is_empty() else Vector2.ZERO
	velocity=direction*speed*movement_factor()
	_update_animation()
	move_and_slide()
func ability_allowed(action: String) -> bool:
	if definition.character_id.begins_with("tensura") or definition.character_id.begins_with("weiro"):
		return action=="leap" or (definition.character_id.begins_with("weiro") and (action=="punch" or (action=="beam" and skill_rank>=2))) or (action=="music_summon" and skill_rank==3)
	return super.ability_allowed(action)
func execute(action: String) -> void:
	if not ability_allowed(action): return
	if action=="summon" and record.get("final_conductor",false):
		level.summon_final_reinforcements(self)
		record.summoned=true
		return
	if action=="music_summon":
		if not ability_allowed(action): return
		voice.play_event("ultimate")
		special_clock=18
		var kinds: Array=["tensura_full","tensura_mini","tensura_minion"] if definition.character_id=="weiro_full" and level.level_index>=33 else ["naiwa_full","penguin_full"]
		if int(record.get("generation",0))>=1: kinds=["tensura_minion"]
		for kind in kinds:
			var child: Node2D=level.spawn_kind(kind)
			if child!=null: child.record.generation=int(record.get("generation",0))+1
		return
	if action=="leap":
		voice.play_event("skill")
		leap_remaining=.55
		leap_aim=position.direction_to(target_point)
		leap_hit=false
		attack_clock=3.0
		return
	if action=="beam":
		voice.play_event("skill")
		var aim:=position.direction_to(target_point)
		var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
		wave.position=position
		wave.line=true
		wave.direction=aim
		wave.radius=560
		wave.tint=Color("ff6459")
		level.add_child(wave)
		for target in preload("res://Combat/teams.gd").friendly_targets(get_tree()):
			if target.is_dead: continue
			var offset: Vector2=target.global_position-global_position
			if offset.dot(aim)>0 and offset.dot(aim)<560 and absf(offset.cross(aim))<32: target.take_damage(outgoing(70+skill_rank*20),"magic")
		attack_clock=4
		return
	# Summon caps also apply to inherited penguin skills.
	if action=="summon" and level.living().size()>level.ENEMY_CAP-4: special_clock=5;return
	super.execute(action)
func take_damage(amount: float,type: String="physical") -> void:
	if type!="true": amount/=float(record.get("defense_boost",1.0))
	if record.get("final_conductor",false):
		var floor_ratio: float=.68 if int(level.state.wave)<=3 else (.36 if int(level.state.wave)==4 else (0.0 if level.get_meta("ensemble_striking",false) else .02))
		amount=minf(amount,maxf(0,health-max_health*floor_ratio))
	if record.get("escape_boss",false):
		amount=minf(amount,maxf(0,health-max_health*.1))
	super.take_damage(amount,type)
	if record.get("escape_boss",false) and health<=max_health*.101: level.escape_boss.call_deferred(self)
func _draw() -> void:
	super._draw()
	if pending in ["beam","leap"]:
		var aim:=position.direction_to(target_point)
		draw_line(Vector2.ZERO,aim*(560 if pending=="beam" else 230),Color(1,.15,.2,.25),55)
		draw_line(Vector2.ZERO,aim*(560 if pending=="beam" else 230),Color(1,.5,.3),3)
