extends SceneTree
const Items=preload("res://Combat/items.gd")
const Weapons=preload("res://Weapons/weapon_registry.gd")
var checks:=0
var failures:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func arena(index: int) -> Node:
	var node=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
	root.add_child(node)
	node.set_process(false)
	node.player.set_physics_process(false)
	node.player.invulnerable=100000
	node.video_started=true
	return node
func kill_all(level: Node) -> void:
	for actor in level.living(): actor.take_damage(actor.max_health*10,"true")
func reset_voices() -> void:
	for actor in get_nodes_in_group("characters"):
		actor.voice.stop()
		actor.voice.cooldowns.clear()
		actor.voice.last_event=""
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var rng:=RandomNumberGenerator.new()
	rng.seed=5628301
	for boss in [false,true]:
		var count:=0
		var invalid:=false
		for i in 30000:
			var id:=Items.enemy_drop(18,boss,rng)
			if not id.is_empty(): count+=1;invalid=invalid or not Items.has_item(id)
		var ratio:=count/30000.0
		check(absf(ratio-(.65 if boss else .24))<.015,"sample drop probability within 1.5 percent")
		check(not invalid,"all rolled items valid")
		print("Observed drop chance, boss=",boss,": ",ratio)
	for index in range(1,28):
		var pool:=Weapons.drops_for_level(index)
		check(pool.is_empty()==(index>=18),"chapter-aware weapon pool %d"%index)
		check(("harpoon" in pool)==(index>=8 and index<=17),"ocean weapon stays in chapter2 %d"%index)
		check("resonance_disruptor" not in pool,"counter weapon is never random loot %d"%index)
		if index==26: check(pool.is_empty(),"3-9 weapon is completion-only")
	for index in [20,22,24,26,27]:
		var level=arena(index)
		var global=root.get_node("Global")
		var expected: String="penguin" if index>=24 else "naiwa"
		check(global.boss_track==expected and global.boss_player.playing,"BGM starts on scene entry %d"%index)
		check(global.boss_player.stream.loop,"BGM stream loops continuously")
		var enemy=level.spawn_kind("naiwa_minion")
		enemy.set_physics_process(false)
		enemy.take_damage(100000,"true")
		level.update_music()
		check(global.boss_track==expected and global.boss_player.playing,"BGM remains during empty arena")
		if index==26:
			check("resonance_disruptor" not in campaign.profile.weapons and not campaign.profile.resonance_unlocked,"3-9 entrance does not grant counter weapon")
			level.next_delay=0
			level._process(.1)
			check(level.living().size()>=17,"3-9 starts with a larger enemy group")
			for id in ["naiwa_mini","penguin_mini","naiwa_full"]:
				check(level.living().any(func(e): return e.definition.character_id==id),"3-9 contains "+id)
			kill_all(level)
			level.state.records=level.state.records.filter(func(record): return record.species!="naiwa_mini")
			level.ensure_rescue_bosses()
			check(level.living().any(func(e): return e.definition.character_id=="naiwa_mini"),"unfinished older rescue save gains missing mandatory mini boss")
			kill_all(level)
			level.state.elapsed=46
			level.reinforce_rescue()
			var count: int=level.state.records.size()
			level.reinforce_rescue()
			check(level.state.records.size()==count,"reinforcement threshold cannot repeat")
			kill_all(level)
			level.state.elapsed=91
			level.reinforce_rescue()
			check(level.living().any(func(e): return e.definition.character_id=="penguin_mini"),"second timed group includes penguin mini boss")
			kill_all(level)
			level.state.elapsed=240
			count=level.state.records.size()
			level.reinforce_rescue()
			check(level.state.records.size()==count,"no delayed reinforcement after survival timer")
		level.queue_free()
		await frames()
		check(global.boss_track.is_empty(),"leaving arena restores normal soundtrack")
	var level=arena(27)
	var full=level.spawn_kind("naiwa_full",false,level.get_node("ArenaCenter").position)
	full.set_physics_process(false)
	var spec:=Weapons.get_weapon("resonance_disruptor")
	var shot=preload("res://Combat/projectile.gd").new()
	shot.damage=220
	shot.target_health_ratios=spec.target_health_ratios
	shot.hit_effect=spec.hit_effect
	shot.damage_type="true"
	level.add_child(shot)
	check(is_equal_approx(shot._damage_for(full),full.max_health*.18),"full Naiwa takes 18 percent max health true damage")
	var mini=level.spawn_kind("naiwa_mini")
	mini.set_physics_process(false)
	check(is_equal_approx(shot._damage_for(mini),mini.max_health*.6),"mini boss takes 60 percent max health true damage")
	full.telegraph("sonic",1.35)
	shot._hit(full.hurtbox)
	check(full.silence_remaining==2.5 and full.pending.is_empty(),"counter bullet cancels sonic windup and silences")
	var hazards:=get_nodes_in_group("arena_hazards").size()
	full.execute("sonic")
	check(get_nodes_in_group("arena_hazards").size()==hazards,"silenced boss cannot emit sonic damage")
	full.silence_remaining=0
	full.execute("sonic")
	check(get_nodes_in_group("arena_hazards").size()==hazards+1,"sonic resumes after silence")
	var boss=level.spawn_kind("penguin_full",true)
	boss.set_physics_process(false)
	boss.execute("summon")
	var summons: Array=level.living().filter(func(e): return e.get("record") is Dictionary and e.record.get("summoner")==boss.persistent_id)
	check(summons.size()==4,"final boss summons exactly four full Naiwa")
	for summon in summons:
		summon.set_physics_process(false)
		check(summon.definition==full.definition and summon.skill_rank==3 and summon.max_health==full.max_health,"summon reuses complete 3-5 boss definition and level scaling")
	boss.execute("summon")
	check(level.living().filter(func(e): return e.get("record") is Dictionary and e.record.get("summoner")==boss.persistent_id).size()==4,"summon is persistent and cannot repeat")
	for family in ["naiwa","penguin"]:
		var voices: Array=[]
		for stage in ["minion","mini","full"]:
			var actor=level.spawn_kind(family+"_"+stage)
			actor.set_physics_process(false)
			voices.append(actor.voice.profile)
			check(actor.skill_rank==["minion","mini","full"].find(stage)+1,"skills have explicit stage rank")
		check(voices[0]==voices[1] and voices[1]==voices[2],"all stages use identical family voice resource")
	for id in ["naiwa","penguin","q_penguin","doro","gugu"]:
		var voice: Resource=load("res://Characters/Voices/"+id+".tres")
		for event in ["idle","battle","hurt","death","angry","afraid","terrified","skill","ultimate","victory","dialogue","exhausted"]:
			check(not voice.get(event).is_empty() and voice.get(event)[0].get_length()>0,"valid combat voice "+id+"/"+event)
		check(voice.max_duration==0,"full voice duration retained "+id)
	var movie=load("res://Scence/Chapter3/victory_video.gd").new()
	level.add_child(movie)
	var audio_manager=root.get_node("Global")
	# The current victory flow asks first and mutes gameplay buses only when played.
	var music_bus:=AudioServer.get_bus_index("Music")
	var was_muted:=AudioServer.is_bus_mute(music_bus)
	movie.play_video()
	check(AudioServer.is_bus_mute(music_bus) and movie.video.bus==&"Video","playing victory video mutes chapter music but uses separate video audio")
	movie.close()
	check(AudioServer.is_bus_mute(music_bus)==was_muted,"closing video restores previous music bus setting")
	check(not audio_manager.boss_player.stream_paused and (not audio_manager.audio_stream_player.playing or audio_manager.audio_stream_player.stream_paused) and (not audio_manager.audio_stream_player_2.playing or audio_manager.audio_stream_player_2.stream_paused),"closing video restores chapter loop without overlapping normal music")
	level.queue_free()
	await frames()
	campaign.states.erase("26")
	campaign.destroy_weapon("resonance_disruptor")
	level=arena(26)
	check("resonance_disruptor" not in campaign.profile.weapons,"destroying counter weapon does not regrant entrance gift")
	level.queue_free()
	await frames()
	for index in [26,27]:
		campaign.states.erase(str(index))
		level=arena(index)
		var ally: Node=level.captive
		ally.set_physics_process(false)
		var threat=level.spawn_kind("naiwa_mini",false,ally.position+Vector2(50,0))
		threat.set_physics_process(false)
		reset_voices()
		ally.speech_clock=0
		ally._physics_process(.1)
		check(ally.voice.last_event=="terrified" and ally.voice.player.playing,"nearby boss triggers audible fear: "+ally.role)
		check(ally.voice.player.stream==ally.voice.profile.terrified[0],"correct contextual clip selected")
		reset_voices()
		ally.health=ally.max_health*.2
		ally.speech_clock=0
		ally._physics_process(.1)
		check(ally.voice.last_event=="exhausted","low health changes voice state: "+ally.role)
		reset_voices()
		ally.release()
		check(ally.voice.last_event=="victory" and ally.voice.player.playing,"rescue plays victory voice: "+ally.role)
		level.queue_free()
		await frames()
	print("Loot/audio/rescue: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
