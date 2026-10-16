extends "res://Characters/character_base.gd"
signal arena_death
var level: Node2D
var record: Dictionary={}
var persistent_id:=""
var emerge_remaining:=1.0
var action_remaining:=0.0
var attack_clock:=1.5
var special_clock:=7.0
var navigation_clock:=0.0
var path:=PackedVector2Array()
var pending:=""
var target_point:=Vector2.ZERO
var death_timer:=1.2
var combat_target: Node2D
var skill_rank:=1
var silence_remaining:=0.0
var speech_clock:=5.0
var hurt_chain:=0
var hurt_chain_clock:=0.0
func _ready() -> void:
	player_controlled=false
	idle_voice_enabled=false
	super._ready()
	skill_rank=3 if definition.character_id.ends_with("full") else (2 if character_type==CharacterType.BOSS else 1)
	scale_enemy(Campaign.encounter_level(level.level_index))
	add_to_group("enemies")
	voice.play_event("battle")
func _physics_process(delta: float) -> void:
	if is_dead:
		death_timer-=delta
		if death_timer<=0: hide() # Let the independent death voice finish offscreen.
		if death_timer<=0 and not voice.player.playing: queue_free()
		return
	if emerge_remaining>0:
		emerge_remaining-=delta
		animated_sprite.modulate.a=1-emerge_remaining*.5
		return
	tick_character(delta)
	silence_remaining=maxf(0,silence_remaining-delta)
	hurt_chain_clock=maxf(0,hurt_chain_clock-delta)
	if hurt_chain_clock<=0: hurt_chain=0
	speech_clock-=delta
	if speech_clock<=0:
		var nearby := is_instance_valid(combat_target) and position.distance_to(combat_target.position)<390
		var event := "angry" if health<max_health*.35 else ("taunt" if definition.character_id.begins_with("penguin") and nearby else ("battle" if nearby else "idle"))
		speech_clock=randf_range(12,17) if voice.play_event(event) else 1.5
	hit_remaining=maxf(0,hit_remaining-delta)
	_update_reaction()
	if bool(get_meta("chapter3_dashing",false)) or root_remaining>0: return
	if is_dead or not is_instance_valid(level.player) or level.player.is_dead: return
	combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	attack_clock-=delta
	special_clock-=delta
	action_remaining-=delta
	navigation_clock-=delta
	if not pending.is_empty():
		if action_remaining<=0:
			execute(pending)
			pending=""
		queue_redraw()
		return
	var id: String=definition.character_id
	var distance:=position.distance_to(combat_target.position)
	facing=position.direction_to(combat_target.position)
	if id=="penguin_full" and health<max_health*.75 and not record.get("summoned",false):
		telegraph("summon",2.0)
		return
	if special_clock<=0 and silence_remaining<=0:
		if id=="naiwa_full": telegraph("sonic",1.35);return
		if id=="naiwa_mini" and distance<240: telegraph("bind",1.1);return
		if id=="penguin_full":
			telegraph(["meteor","stone_rain","kick"][randi_range(0,2)],1.4)
			return
	var ranged: bool=id.begins_with("penguin")
	if attack_clock<=0 and distance<(390 if ranged else 65):
		telegraph("rock" if ranged else "punch",.65 if ranged else .45)
		return
	if navigation_clock<=0:
		path=level.geometry.path(position,combat_target.position)
		navigation_clock=.6
	while not path.is_empty() and position.distance_to(path[0])<10: path.remove_at(0)
	direction=Vector2.ZERO
	if distance>(155 if ranged else 38) and not path.is_empty(): direction=position.direction_to(path[0])
	velocity=direction*speed*movement_factor()
	_update_animation()
	move_and_slide()
	queue_redraw()
func telegraph(action: String, delay: float) -> void:
	if not ability_allowed(action): return
	if not is_instance_valid(combat_target): combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	pending=action
	action_remaining=delay
	target_point=combat_target.position
	velocity=Vector2.ZERO
	animated_sprite.flip_h=facing.x>0
	animated_sprite.play("attack")
	voice.play_event("ultimate" if action in ["sonic","summon","meteor"] else "skill")
	special_clock=8.0 if action not in ["punch","rock"] else special_clock
	attack_clock=1.8
func execute(action: String) -> void:
	if not ability_allowed(action): return
	if not is_instance_valid(combat_target) or combat_target.is_dead: combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	var full: bool=definition.character_id.ends_with("full")
	match action:
		"punch":
			if position.distance_to(combat_target.position)<78 and clear_sight(combat_target.position): combat_target.take_damage(outgoing(90 if full else (28 if character_type==CharacterType.BOSS else 16)),"physical")
		"rock": throw_rock(position.direction_to(target_point),240 if full else (55 if skill_rank==2 else 18))
		"bind","sonic":
			if silence_remaining>0: return
			var area=preload("res://Scence/Chapter3/hazard.gd").new()
			area.position=position
			area.radius=170 if action=="sonic" else (140 if skill_rank==2 else 75)
			area.damage=outgoing(125 if action=="sonic" else 5)
			area.slow=4
			area.bind_time=(.9 if skill_rank==2 else .25) if action=="bind" else 0.0
			area.dot=outgoing(12) if action=="sonic" else 0.0
			area.warmup=.1
			area.visual="sonic"
			area.tint=Color("ddaaff")
			level.add_child(area)
		"summon":
			if record.get("summoned",false): return
			for i in 4:
				var summon=level.spawn_kind("naiwa_full",false)
				summon.record.summoner=persistent_id
			record.summoned=true
			level.snapshot()
			Campaign.save_progress()
			Campaign.message.emit("凑企鹅召唤了四只奶娃完全体！使用静音共振枪打断音波，并击败全部标记首领。")
		"stone_rain":
			var aim:=position.direction_to(target_point)
			var count:=7 if full else 3
			for i in count: throw_rock(aim.rotated((i-(count-1)*.5)*.15),160 if full else 35)
		"meteor":
			var crater=preload("res://Scence/Chapter3/hazard.gd").new()
			crater.position=target_point
			crater.radius=110
			crater.damage=outgoing(260)
			crater.tick_damage=outgoing(32)
			crater.duration=6
			crater.friendly_fire=true
			level.add_child(crater)
		"kick":
			var dash=preload("res://Scence/Chapter3/flying_kick.tscn").instantiate()
			dash.actor=self
			dash.aim=position.direction_to(target_point)
			dash.damage=outgoing(450)
			dash.friendly_fire=true
			level.add_child(dash)
func ability_allowed(action: String) -> bool:
	if definition.character_id.begins_with("naiwa"):
		return action=="punch" or (action=="bind" and skill_rank>=2) or (action=="sonic" and skill_rank==3)
	return action=="rock" or (skill_rank==3 and action in ["summon","stone_rain","meteor","kick"])
func throw_rock(aim: Vector2, damage: int) -> void:
	var shot=preload("res://Combat/projectile.gd").new()
	shot.position=position+Vector2(0,-18)
	var obstruction:=get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(position,shot.position,2))
	if not obstruction.is_empty(): shot.position=position
	shot.direction=aim
	shot.hostile=true
	shot.damage=outgoing(damage)
	shot.speed=230
	shot.display_width=25 if definition.character_id=="penguin_full" else 18
	shot.hit_radius=7
	shot.texture=preload("res://Weapons/chapter3_art.gd").texture(5)
	level.add_child(shot)
func clear_sight(point: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(position,point,2)).is_empty()
func silence_sonic(seconds: float) -> void:
	if not definition.character_id.begins_with("naiwa"): return
	silence_remaining=maxf(silence_remaining,seconds)
	if pending in ["bind","sonic"]:
		pending=""
		action_remaining=0
	voice.play_event("exhausted")
func take_damage(amount: float,type: String="physical") -> void:
	if not can_receive_damage() or amount<=0: return
	var defense: float=(45.0 if definition.character_id=="penguin_full" else (20.0 if definition.character_id.ends_with("full") else 6.0))*Campaign.Growth.defense_scale(combat_level)
	if type=="magic": defense*=.4
	var received: float=amount if type=="true" else Campaign.Growth.mitigate(amount,defense,combat_level)
	super.take_damage(received,type)
	if not is_dead:
		hurt_chain+=1
		hurt_chain_clock=5
		voice.play_event("angry" if hurt_chain>=3 else "hurt")
	record.hp=health
	queue_redraw()
func begin_death() -> void:
	if is_dead: return
	super.begin_death()
	remove_from_group("enemies")
	set_deferred("collision_layer",0)
	level.actor_died(record)
	Campaign.award_experience(combat_level,character_type==CharacterType.BOSS)
	Campaign.profile.kills+=1
	Campaign.profile.coins+=roundi((35 if character_type==CharacterType.BOSS else 8)*(1+combat_level*.08))
	Campaign.enemy_defeated.emit()
	var item_id:=preload("res://Combat/items.gd").enemy_drop(level.level_index,character_type==CharacterType.BOSS)
	if not item_id.is_empty():
		var loot=preload("res://Combat/loot.gd").new()
		loot.item_id=item_id
		loot.position=position
		level.call_deferred("add_child",loot)
	Campaign.request_save()
func _draw() -> void:
	if is_dead or definition==null: return
	var y: float=-definition.hurtbox_size.y-12
	draw_rect(Rect2(-30,y,60,5),Color("40253c"))
	draw_rect(Rect2(-30,y,60*float(health)/max_health,5),Color("ff607d"))
	draw_string(ThemeDB.fallback_font,Vector2(-40,y-4),definition.display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
	if silence_remaining>0:
		draw_arc(to_local(combat_center()),24,0,TAU,24,Color("86efff"),2)
		draw_string(ThemeDB.fallback_font,Vector2(-15,y-16),"静音",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("86efff"))
	if pending in ["sonic","bind"]: draw_arc(Vector2.ZERO,170 if pending=="sonic" else 140,0,TAU,50,Color(1,.2,.5,.7),2)
	if pending=="rock": draw_line(Vector2.ZERO,to_local(target_point),Color(1,.25,.2,.6),3)
	if pending=="kick":
		var aim:=position.direction_to(target_point)
		var center:=to_local(combat_center())
		draw_line(center,center+aim*340,Color(1,.25,.12,.2),68)
		draw_line(center,center+aim*340,Color(1,.65,.25,.85),3)
		draw_string(ThemeDB.fallback_font,Vector2(-38,y-20),"飞踢 · 快躲开",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffd18b"))
