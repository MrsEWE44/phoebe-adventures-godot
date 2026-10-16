extends "res://Scence/Chapter3/arena.gd"
const ENEMY_CAP:=32
const ALLY_CAP:=4
var music_allies: Array[Node2D]=[]
var cinematic_pending:=false
var ensemble_clock:=0.0
var phone_call: Node
var final_ending: Node
func _ready() -> void:
	biome="swamp"
	super._ready()
	for key in {"deploy_count":0,"ensemble_active":false,"ensemble_elapsed":0.0,"escaped":false,"combo_strike":false}:
		if not state.has(key): state[key]={"deploy_count":0,"ensemble_active":false,"ensemble_elapsed":0.0,"escaped":false,"combo_strike":false}[key]
	if level_index==37:
		# Retain party preparation when upgrading an unfinished timed encounter.
		if not state.finished and not state.get("finale_version",0)==2:
			for enemy in living(): enemy.queue_free()
			state.records=[]
			state.wave=0
			state.boss_started=false
			state.combo_strike=false
			state.finale_version=2
		for i in int(state.deploy_count): spawn_performer(["mutsumi","anon","soyo"][i],i)
		Campaign.ensure_character_allowed()
		player.get_node("Camera2D").zoom=Vector2(1.5,1.5)
	cinematic_pending=bool(state.finished) and not state.get("cinematic_seen",false)
	if level_index==28 and cinematic_pending: present_cinematic()
	player.refresh_environment()
	if state.get("failed",false): show_failed_resume.call_deferred()
func show_failed_resume() -> void:
	var screen=preload("res://UI/defeat_screen.gd").new()
	screen.level_index=level_index
	screen.reason="上次合奏已中断，请重试本关或返回主场景准备。"
	add_child(screen)
func setup_allies() -> void:
	var captive_id: String={28:"mutsumi",29:"soyo",30:"anon",31:"anon",32:"anon",36:"tensura_full"}.get(level_index,"")
	if not captive_id.is_empty() and not state.finished:
		captive=make_ally(captive_id,$RescuePosition.position,true)
	if level_index in [33,34] and not state.finished:
		make_ally("penguin_full",$ArenaCenter.position+Vector2(-80,0))
	if not state.finished:
		for record in state.records:
			if record.get("assimilated",false) and float(record.get("ally",{}).get("hp",0))>0:
				make_ally(record.species,geometry.nearest(Vector2(record.position[0],record.position[1])),false,false,record.ally)
func make_ally(id: String, point: Vector2, locked:=false, protected:=false, record: Dictionary={}) -> Node2D:
	var ally=preload("res://Scence/Chapter4/ally.tscn").instantiate()
	ally.role=id
	ally.level=self
	ally.captive=locked
	ally.protected=protected
	ally.record=record
	ally.position=geometry.nearest(point)
	add_child(ally)
	if not locked: music_allies.append(ally)
	return ally
func spawn_performer(id: String, slot: int) -> void:
	if not state.get("performers") is Dictionary: state.performers={}
	if not state.performers.get(id) is Dictionary: state.performers[id]={}
	var marker:=get_node_or_null("BandSeats/"+id)
	var point: Vector2=to_local(marker.global_position) if marker!=null else $ArenaCenter.position+Vector2(-105,(-1+slot)*48)
	make_ally(id,point,false,true,state.performers[id])
func conduct(actor: Node2D) -> bool:
	if level_index!=37 or state.finished or state.get("failed",false) or state.ensemble_active: return false
	if actor.current_character!="soyo" or actor.normal_weapon.weapon_id!="conductor":
		Campaign.message.emit("先切换soyo狸，持指挥棒按F，依次释放睦子米、爱音、soyo狸。")
		return false
	var slot:=int(state.deploy_count)
	if slot>=3: return false
	spawn_performer(["mutsumi","anon","soyo"][slot],slot)
	state.deploy_count=slot+1
	Campaign.message.emit("合奏席位 %d/3 已就位。"%state.deploy_count)
	if int(state.deploy_count)==3:
		state.ensemble_active=true
		Campaign.ensure_character_allowed()
		position_guard.call_deferred()
		Campaign.message.emit("坤坤接替！乐队护盾减伤98%，音波可将奶娃转为友军。保护乐队完成五波；每8秒合击，第三波最终体登场。")
	Campaign.save_progress()
	return true
func position_guard() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	if not is_inside_tree() or state.finished: return
	var point: Vector2=geometry.safe_spawn($ArenaCenter.position+Vector2(-100,100),player)
	if point.is_finite(): player.position=point
	player.velocity=Vector2.ZERO
	player.note_activity()
	snapshot()
	Campaign.save_progress()
func _process(delta: float) -> void:
	if state.is_empty(): return
	if level_index==37 and str(state.get("ending_phase","")) in ["memory","dialogue","farewell"]:
		if not is_instance_valid(final_ending) and not Dialogue.active and not get_tree().paused: start_final_ending()
		return
	if state.finished:
		if cinematic_pending and not Dialogue.active and Story.pending.is_empty() and Story.running.is_empty() and not get_tree().paused: present_cinematic()
		return
	if not spawn_enemies or player.is_dead or state.get("failed",false): return
	checkpoint+=delta
	if checkpoint>=4:
		checkpoint=0
		snapshot()
		Campaign.request_save()
	if next_delay>0: next_delay-=delta;return
	var number:=level_index-27
	if number==10:
		preload("res://Scence/Chapter4/final_battle.gd").tick(self,delta)
		return
	if number==7:
		state.elapsed=minf(121,float(state.elapsed)+delta)
		refill_timer-=delta
		if state.elapsed<121 and (living().is_empty() or refill_timer<=0):
			spawn_pack(12)
			refill_timer=15
		if state.elapsed>=121 and living().is_empty(): finish()
		return
	if not living().is_empty(): return
	if int(state.wave)>=int(config.waves): finish();return
	state.wave=int(state.wave)+1
	spawn_pack(8+number)
	if int(state.wave)==int(config.waves):
		match number:
			1: spawn_kind("naiwa_mini",true);spawn_kind("penguin_mini",true)
			2: spawn_kind("naiwa_mini",true);spawn_kind("penguin_mini",true)
			3,4:
				spawn_kind("tensura_mini",true);spawn_kind("naiwa_full",true);spawn_kind("penguin_full",true)
			5: spawn_kind("tensura_full",true)
			6: spawn_kind("tensura_full",true);spawn_kind("weiro_full",true)
			8:
				var boss:=spawn_kind("penguin_full",true)
				boss.record.escape_boss=true
				spawn_kind("tensura_full",true);spawn_kind("weiro_full",true)
			9:
				spawn_kind("penguin_full",true)
				spawn_kind("naiwa_full",true);spawn_kind("tensura_full",true);spawn_kind("weiro_full",true)
	snapshot()
	Campaign.save_progress()
func spawn_pack(count: int) -> void:
	var number:=level_index-27
	var kinds: Array=["naiwa_minion","penguin_minion"]
	if number>=2: kinds.append("tensura_minion")
	if number>=3: kinds.append("tensura_mini")
	if number==7: kinds=["naiwa_mini","penguin_mini","tensura_mini"]
	for i in mini(count,maxi(0,ENEMY_CAP-living().size()-5)): spawn_kind(kinds[i%kinds.size()])
func spawn_kind(species: String, required:=false, preferred:=Vector2.INF) -> Node2D:
	if living().size()>=ENEMY_CAP: return null
	# Until the reveal, the hand-bearing impostor is masquerading as Tensura.
	if level_index<=32 and species.begins_with("tensura"): species=species.replace("tensura","weiro")
	var actor:=super.spawn_kind(species,required,preferred)
	if actor!=null and species=="penguin_full" and required and level_index>=35:
		var factor:=1.5 if level_index==35 else 2.0 if level_index==36 else 3.0
		actor.max_health*=factor
		actor.health=actor.max_health
		actor.damage_scale*=1.25 if level_index==35 else 1.45
		actor.record.hp=actor.health
		actor.record.max_hp=actor.max_health
		actor.record.damage_boost=1.25 if level_index==35 else 1.45
		actor.record.defense_boost=1.25 if level_index==35 else 1.6
	return actor
func restore_actor(record: Dictionary) -> Node2D:
	Campaign.migrate_enemy_record(record,level_index,"hp","max_hp")
	var actor: Node2D=load("res://Characters/Actors/%s.tscn"%record.species).instantiate()
	actor.set_script(preload("res://Scence/Chapter4/enemy.gd"))
	actor.definition=Campaign.character_definition(record.species)
	if level_index<=32 and str(record.species).begins_with("weiro"):
		actor.definition=actor.definition.duplicate()
		actor.definition.display_name=actor.definition.display_name.replace("伪罗","")
	actor.use_scene_collision_shapes=true
	actor.record=record
	actor.level=self
	actor.persistent_id=record.id
	actor.position=geometry.nearest(Vector2(record.position[0],record.position[1]))
	add_child(actor)
	actor.max_health=float(record.max_hp)
	actor.health=float(record.hp)
	actor.damage_scale*=float(record.get("damage_boost",1.0))
	actor.emerge_remaining=1.2
	return actor
func assimilate(enemy: Node2D, chorus:=false) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.record.get("assimilated",false): return false
	if enemy.record.get("required",false) and enemy.record.get("final_conductor",false): return false
	if not (chorus and level_index==37) and music_allies.filter(func(a): return is_instance_valid(a) and not a.is_dead).size()>=ALLY_CAP: return false
	var id: String=enemy.definition.character_id
	enemy.record.dead=true
	enemy.record.hp=0
	enemy.record.assimilated=true
	enemy.is_dead=true
	enemy.remove_from_group("enemies")
	enemy.record.ally={"hp":650.0}
	make_ally(id,enemy.position,false,false,enemy.record.ally)
	enemy.queue_free()
	Campaign.request_save()
	return true
func escape_boss(boss: Node2D) -> void:
	if state.finished or state.escaped: return
	state.escaped=true
	boss.record.dead=true
	boss.remove_from_group("enemies")
	boss.queue_free()
	finish()
func fail_ensemble() -> void:
	if state.get("failed",false) or state.finished: return
	state.failed=true
	snapshot()
	Campaign.save_progress()
	var screen=preload("res://UI/defeat_screen.gd").new()
	screen.level_index=level_index
	screen.reason="合奏中断：演奏者倒下。重试本关，优先拦截冲向舞台的敌人。"
	add_child(screen)
func snapshot() -> void:
	for enemy in living():
		enemy.record.hp=enemy.health
		enemy.record.position=[enemy.position.x,enemy.position.y]
	for ally in music_allies:
		if is_instance_valid(ally): ally.record.hp=ally.health
	Campaign.level_state(level_index).position=[player.position.x,player.position.y]
func finish() -> void:
	if state.finished or state.get("failed",false): return
	if level_index==34 and state.elapsed<121: return
	if level_index==35 and not state.escaped: return
	if level_index==37 and state.get("ending_phase","")!="done": return
	state.finished=true
	for record in state.records: record.dead=true
	for enemy in living(): enemy.queue_free()
	for group in ["projectiles","arena_hazards"]:
		for node in get_tree().get_nodes_in_group(group): node.queue_free()
	if is_instance_valid(captive): captive.queue_free()
	Campaign.complete_arena(level_index)
	if level_index==32: make_ally("penguin_full",$ArenaCenter.position)
	$Portals/Exit.refresh()
	update_music()
	cinematic_pending=true
	if level_index==28: present_cinematic()
	Campaign.message.emit("4-%d 挑战完成！右侧出口已开启，可进入下一关或返回主地图。"%(level_index-27))
func present_cinematic() -> void:
	cinematic_pending=false
	if state.get("cinematic_seen",false): return
	if level_index==28:
		if is_instance_valid(phone_call): return
		phone_call=preload("res://Scence/Chapter4/phone_call.gd").new()
		phone_call.state=state
		add_child(phone_call)
		return
	state.cinematic_seen=true
	Campaign.save_progress()
	var movie: String={32:"chapter4_reveal",33:"chapter4_impostor",37:"chapter4_victory"}.get(level_index,"")
	if movie.is_empty(): return
	var video=preload("res://Scence/Chapter3/victory_video.gd").new()
	video.stream_path="res://Videos/"+movie+".ogv"
	video.prompt_title="第四章通关！是否播放胜利视频？" if level_index==37 else "剧情影像"
	add_child(video)
	if level_index!=37: video.play_video.call_deferred()
func update_music() -> void:
	Global.set_boss_music("memory4" if level_index==37 and str(state.get("ending_phase","")) in ["memory","dialogue","farewell"] else ("victory4" if 37 in Campaign.completed else ("penguin" if level_index>=35 else "naiwa")))
func objective_text() -> String:
	if state.is_empty(): return "第四章 · 加载中"
	if state.finished: return "4-%d · 通关 · 右门选择下一关或返回"%(level_index-27)
	if level_index==37:
		return "五波合奏 · 第%d/5波 · 下一次合击 %d秒 · 保护三名成员"%[state.wave,ceili(maxf(0,ensemble_clock))] if state.get("ensemble_active",false) else "4-10 · 切换soyo持指挥棒 · 按F依次召集三人"
	if level_index==34: return "4-7 · 排练 %d/121秒 · 剩余敌人%d"%[state.elapsed,living().size()]
	return "4-%d %s · 第%d/%d波 · 敌人%d"%[level_index-27,config.name,state.wave,config.waves,living().size()]
func show_exit_choices() -> void:
	if not state.finished: return
	var options: Array=[{"id":"hub","text":"返回第四章主场景"}]
	if level_index<37: options.push_front({"id":"next_level","text":"进入4-%d"%(level_index-26)})
	Dialogue.open("右侧出口",["救援进度已保存。"],options,self,func(id):
		Dialogue.close()
		if id=="next_level": Campaign.enter_level.call_deferred(level_index+1)
		else: Campaign.return_to_hub.call_deferred())
func _unhandled_input(event: InputEvent) -> void:
	if not Dialogue.active and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		for chest in get_tree().get_nodes_in_group("chests"):
			if chest.interaction_distance(player)<INF: chest.interact();return
	super._unhandled_input(event)

func summon_final_reinforcements(boss: Node2D) -> void:
	if int(state.get("final_summons",0))>=1 or living().size()>ENEMY_CAP-2: return
	state.final_summons=1
	boss.record.summoned=true
	for kind in ["weiro_full","naiwa_full"]:
		var actor:=spawn_kind(kind)
		if actor!=null:
			actor.record.generation=1
			actor.record.summoner=boss.persistent_id
	boss.voice.play_event("ultimate")
func begin_final_ending() -> void:
	if state.finished or not str(state.get("ending_phase","")).is_empty(): return
	state.ending_phase="memory"
	for enemy in living():
		enemy.record.dead=true
		enemy.queue_free()
	for group in ["projectiles","arena_hazards"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get_parent()==self: node.queue_free()
	snapshot()
	Campaign.save_progress()
	update_music()
	start_final_ending.call_deferred()
func start_final_ending() -> void:
	if is_instance_valid(final_ending): return
	final_ending=preload("res://Scence/Chapter4/finale.gd").new()
	final_ending.world=self
	add_child(final_ending)
