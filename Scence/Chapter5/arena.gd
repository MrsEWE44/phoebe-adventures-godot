extends "res://Scence/Chapter4/arena.gd"
var ending_open:=false
var omo_actor: Node2D
func _ready() -> void:
	super._ready()
	if level_index==47 and not state.finished and Campaign.profile.hell.omo_choice=="give":
		Campaign.level_state(46).get_or_add("arena",{}).omo_music_locked=true
		Campaign.request_save()
	biome="hell"
	player.refresh_environment()
	player.get_node("Camera2D").zoom=Vector2(1.6,1.6)
	if level_index==42 and not state.get("hell_phone_done",false): start_phone.call_deferred()
func setup_allies() -> void:
	if not state.finished:
		for record in state.records:
			if record.get("assimilated",false) and float(record.get("ally",{}).get("hp",0))>0:
				make_ally(record.species,geometry.nearest(Vector2(record.position[0],record.position[1])),false,false,record.ally)
	var id: String={38:"penguin_full",39:"miku",40:"reimu",43:"doro",44:"gugu",45:"nuonuo",47:"phoebe"}.get(level_index,"")
	if not id.is_empty() and not state.finished: captive=make_ally(id,$RescuePosition.position,true)
	if level_index in [39,40,41] and not state.finished and not Campaign.profile.hell.music_departed:
		make_ally("penguin_full",$Spawn.position+Vector2(70,0))
	if level_index==47 and Campaign.profile.hell.omo_choice=="give" and not state.finished:
		omo_actor=preload("res://Scence/Chapter4/ally.tscn").instantiate()
		omo_actor.set_script(preload("res://Scence/Chapter5/omo.gd"))
		omo_actor.position=geometry.nearest($Spawn.position+Vector2(65,20))
		omo_actor.level=self
		add_child(omo_actor)
func _process(delta: float) -> void:
	if state.is_empty(): return
	if state.get("battle_done",false):
		if not state.finished and not ending_open and not Dialogue.active and not get_tree().paused: start_ending()
		return
	if not spawn_enemies or player.is_dead or state.finished or state.get("failed",false): return
	if level_index==42 and not state.get("hell_phone_done",false): return
	checkpoint+=delta
	if checkpoint>=4: checkpoint=0;snapshot();Campaign.request_save()
	if not living().is_empty(): return
	next_delay-=delta
	if next_delay>0: return
	if int(state.wave)>=int(config.waves): finish();return
	state.wave=int(state.wave)+1
	var n:=level_index-37
	var cap: int=mini(26,8+n+int(state.wave))
	# Boss must have its own slot in the last wave.
	for i in cap: spawn_kind(wave_species(i))
	if n>=5 and int(state.wave)==int(config.waves):
		spawn_kind("hell_boss_%d"%(n-4),true)
		state.boss_started=true
	next_delay=2.0
	Campaign.message.emit("5-%d · 第%d/%d波。留意红色蓄力范围！"%[n,state.wave,config.waves])
	snapshot()
	Campaign.save_progress()
func wave_species(slot: int) -> String:
	var n:=level_index-37
	var family: String="naiwa" if n==1 else ["kangaroo","fatkangaroo","dog","mouse","naiwa"][slot%5]
	var color: String="plain" if n==2 and family!="naiwa" else ["green","purple","red"][(slot+int(state.wave))%3]
	var stage: String="minion" if slot%4==0 else "small" if slot%4==1 else "mini"
	if n>=2 and slot%7==0: stage="full"
	return family+"_"+color+"_"+stage
func spawn_kind(species: String,required:=false,preferred:=Vector2.INF) -> Node2D:
	if living().size()>=30: return null
	var point: Vector2=geometry.nearest($ArenaCenter.position)
	var cells: Array=geometry.base_free.duplicate()
	cells.shuffle()
	for cell in cells:
		var p: Vector2=geometry.nav.get_point_position(cell)
		if p.distance_to(player.position)<160 or p.distance_to($ArenaCenter.position)>330: continue
		if living().any(func(e):return e.position.distance_to(p)<30): continue
		point=p
		break
	if preferred.is_finite(): point=geometry.nearest(preferred)
	var spec: Resource=Campaign.character_definition(species)
	var hp: float=spec.max_health*Campaign.Growth.enemy_health_scale(Campaign.encounter_level(level_index),species)
	if "_green_" in species: hp*=1.35
	state.serial=int(state.serial)+1
	var record: Dictionary={"id":"hell_%d"%state.serial,"species":species,"hp":hp,"max_hp":hp,"position":[point.x,point.y],"dead":false,"required":required,"summoned":false,"growth_version":Campaign.Growth.BALANCE_VERSION}
	state.records.append(record)
	return restore_actor(record)
func restore_actor(record: Dictionary) -> Node2D:
	var actor: Node2D=load("res://Characters/Actors/%s.tscn"%record.species).instantiate()
	actor.record=record
	actor.level=self
	actor.persistent_id=record.id
	actor.position=geometry.nearest(Vector2(record.position[0],record.position[1]))
	add_child(actor)
	actor.max_health=record.max_hp
	actor.health=record.hp
	if "_red_" in str(record.species): actor.damage_scale*=1.4
	return actor
func update_music() -> void:
	var victory: bool=bool(state.get("finished",false)) if level_index==47 else 47 in Campaign.completed
	Global.set_boss_music("victory3" if victory else "omo" if level_index==46 and state.get("battle_done",false) else "badapple" if level_index>=40 or 40 in Campaign.completed else "sakura" if 39 in Campaign.completed else "memory4")
func finish() -> void:
	if state.finished or state.get("battle_done",false): return
	if not living().is_empty() or int(state.wave)<int(config.waves): return
	state.battle_done=true
	for group in ["projectiles","arena_hazards"]:
		for effect in get_tree().get_nodes_in_group(group): effect.queue_free()
	snapshot()
	Campaign.save_progress()
	update_music()
func start_ending() -> void:
	ending_open=true
	if level_index==46 and not is_instance_valid(omo_actor):
		omo_actor=make_ally("omo",geometry.nearest(player.position+Vector2(65,0)))
		omo_actor.set_physics_process(false)
	var ending=preload("res://Scence/Chapter5/ending.gd").new()
	ending.world=self
	ending.completed.connect(func(): ending_open=false)
	add_child(ending)
func commit_clear() -> void:
	state.finished=true
	if level_index==47: Campaign.level_state(46).get_or_add("arena",{}).omo_music_locked=false
	if level_index==38 and is_instance_valid(captive) and not Campaign.profile.hell.music_departed: make_ally("penguin_full",captive.position)
	if is_instance_valid(captive): captive.queue_free()
	if is_instance_valid(omo_actor): omo_actor.queue_free()
	Campaign.complete_arena(level_index)
	Campaign.ensure_character_allowed()
	if level_index==41:
		for ally in music_allies:
			if is_instance_valid(ally): ally.queue_free()
	update_music()
	$Portals/Exit.refresh()
	Campaign.save_progress()
func start_phone() -> void:
	var call=preload("res://Scence/Chapter5/phone.gd").new()
	call.state=state
	call.completed.connect(func():
		state.hell_phone_done=true
		Campaign.save_progress()
		Story.enter_world(self))
	add_child(call)
func objective_text() -> String:
	if state.finished: return "5-%d · 已通关 · 右门：下一关 / 主场景"%(level_index-37)
	if state.get("battle_done",false): return "5-%d · 战斗结束 · 完成救援对话"%(level_index-37)
	return "5-%d · %s · 第%d/%d波 · 敌人%d"%[level_index-37,config.name,state.wave,config.waves,living().size()]
func show_exit_choices() -> void:
	if not state.finished: return
	var options: Array=[{"id":"hub","text":"返回第五章主场景"}]
	if level_index<47: options.push_front({"id":"next_level","text":"进入5-%d"%(level_index-36)})
	Dialogue.open("余烬出口",["救援进展已保存。"],options,self,func(id):
		Dialogue.close()
		if id=="next_level": Campaign.enter_level.call_deferred(level_index+1)
		else: Campaign.return_to_hub.call_deferred())
