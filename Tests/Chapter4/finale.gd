extends SceneTree
const Battle=preload("res://Scence/Chapter4/final_battle.gd")
var checks:=0
var failures:=0
func ck(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func video_has_audio() -> bool:
	var bus:=AudioServer.get_bus_index("Video")
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=2.0
	var slot:=AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus,capture)
	await create_timer(1.5).timeout
	var peak:=0.0
	for sample in capture.get_buffer(capture.get_frames_available()): peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	AudioServer.remove_bus_effect(bus,slot)
	return peak>.00001
func run() -> void:
	var c=root.get_node("Campaign")
	var dialogue=root.get_node("Dialogue")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(40)
	c.hub_chapter=4
	for index in range(28,37):
		c.level_state(index).arena={"finished":true}
		c.complete_arena(index)
	c.active_level=37
	var w=load(c.Catalog.scene_path(37)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	await frames()
	w.player.set_physics_process(false)
	w.player.invulnerable=9999
	c.select_character("soyo")
	for i in 3: ck(w.conduct(w.player),"deploy musician %d"%i)
	ck(c.profile.character=="ikun","Ikun controls protection battle")
	var seats: Array=[]
	for ally in w.music_allies:
		ally.set_physics_process(false)
		seats.append(ally.position)
	ck(seats[0].distance_to(seats[1])>25 and seats[1].distance_to(seats[2])>25,"three distinct fixed seats")
	for species in ["tensura_minion","tensura_mini","tensura_full","weiro_minion","weiro_mini","weiro_full"]:
		var actor=w.spawn_kind(species)
		actor.set_physics_process(false)
		ck(actor.ability_allowed("punch")==species.begins_with("weiro"),species+" hand attack rule")
		ck(actor.ability_allowed("beam")== (species.begins_with("weiro") and not species.ends_with("minion")),species+" hand beam rule")
		actor.execute("punch") if species.begins_with("tensura") else actor.execute("leap")
		actor.record.dead=true
		actor.queue_free()
	await frames()
	# A genuine terrain body between player and victim must not stop music attacks.
	c.select_character("soyo") # Locked during ensemble; use the actor's music weapon directly.
	w.player.normal_weapon=preload("res://Weapons/weapon_registry.gd").get_weapon("ivory_cello").duplicate()
	w.player.normal_weapon.auto_fire=true
	w.player.position=Vector2(460,480)
	var victim=w.spawn_kind("naiwa_full",false,Vector2(570,480))
	victim.position=Vector2(570,480)
	victim.set_physics_process(false)
	var wall:=StaticBody2D.new()
	wall.position=Vector2(515,450)
	wall.collision_layer=2
	var shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=Vector2(15,150)
	shape.shape=rectangle
	wall.add_child(shape)
	w.add_child(wall)
	await physics_frame
	await physics_frame
	var hp: float=victim.health
	preload("res://Scence/Chapter4/music_combat.gd").play(w.player,Vector2.RIGHT)
	ck(victim.health<hp,"music beam damages enemy behind wall")
	victim.record.dead=true
	victim.queue_free()
	wall.queue_free()
	await frames()
	# Chorus tiers use true damage: infants fall immediately, middle forms within two hits.
	var center:=Vector2.ZERO
	for ally in w.music_allies: center+=ally.combat_center()/3.0
	var middle=w.spawn_kind("weiro_mini",false,center+Vector2(70,20))
	middle.position=center+Vector2(70,20)
	middle.set_physics_process(false)
	var infant=w.spawn_kind("naiwa_minion",false,center+Vector2(80,20))
	infant.position=center+Vector2(80,20)
	infant.set_physics_process(false)
	Battle.pulse(w)
	ck(infant.record.get("assimilated",false) and not infant.is_in_group("enemies"),"chorus recruits infant Naiwa")
	ck(not middle.is_dead and middle.health<=middle.max_health*.33,"middle form severely hurt by first chorus")
	Battle.pulse(w)
	ck(middle.is_dead,"middle form falls within two pulses")
	await frames()
	# Corpse visibility is independent of the duration of its death recording.
	for species in ["naiwa_full","penguin_full"]:
		var ally=w.make_ally(species,Vector2(470,480))
		ally.set_physics_process(false)
		ally.take_damage(999999,"true")
		ally._physics_process(1.3)
		ck(ally.is_dead and not ally.visible and ally.record.hp==0,species+" ally corpse hidden")
		ally.voice.stop()
		ally._physics_process(.1)
		await frames()
		ck(not is_instance_valid(ally),species+" corpse freed after audio")
	var previous_count:=0
	for number in range(1,6):
		Battle.tick(w,.01)
		ck(int(w.state.wave)==number,"sequential wave %d"%number)
		var boss=Battle.boss(w)
		ck((boss!=null)==(number>=3),"boss starts at wave three")
		ck(w.living().size()>previous_count,"increasing wave population")
		previous_count=w.living().size()
		ck(w.living().size()<=32,"live cap")
		if boss!=null:
			ck(w.living().any(func(e):return e.definition.character_id=="weiro_full"),"boss summoned full Weiro")
			ck(w.living().any(func(e):return e.definition.character_id=="naiwa_full"),"boss summoned full Naiwa")
		if number==3:
			w.snapshot()
			c.save_path="res://.godot/finale-wave-resume.json"
			c.saving_enabled=true
			c.save_progress()
			c.saving_enabled=false
			var expected_hp: float=boss.health
			var expected_enemies: int=w.living().size()
			w.queue_free()
			await frames()
			c.reset_state(1)
			ck(c.load_progress(),"wave-three isolated save reloads")
			c.saving_enabled=false
			w=load(c.Catalog.scene_path(37)).instantiate()
			root.add_child(w)
			w.set_process(false)
			w.player.set_physics_process(false)
			w.player.invulnerable=9999
			for actor in w.living()+w.music_allies: actor.set_physics_process(false)
			boss=Battle.boss(w)
			ck(int(w.state.wave)==3 and w.living().size()==expected_enemies,"wave and enemies preserved after reload")
			ck(boss!=null and is_equal_approx(boss.health,expected_hp),"boss health preserved after reload")
			ck(w.music_allies.filter(func(a):return a.protected).size()==3,"three band members restored once")
		for enemy in w.living():
			enemy.set_physics_process(false)
			if not enemy.record.get("final_conductor",false): enemy.take_damage(enemy.max_health*100,"true")
		if boss!=null:
			boss.take_damage(boss.max_health*100,"true")
			ck(not boss.is_dead,"ordinary attacks cannot skip final chorus")
		if number==5:
			Battle.pulse(w)
			ck(boss.is_dead,"chorus defeats final boss in fifth wave")
		await frames()
	Battle.tick(w,.01)
	await frames()
	await frames()
	var ending=w.final_ending
	ck(ending!=null and w.state.ending_phase=="memory","memory sequence starts after battle")
	ck(not w.state.finished and 37 not in c.completed,"no early clear before epilogue")
	ck(root.get_node("Global").boss_track=="memory4","defeat memory BGM selected")
	ck(ending.movie.video.is_playing() and ending.movie.video.bus==&"Video","memory movie autoplays with video bus")
	for bus in ["Music","Voice","EnemyVoice","Effects"]:
		ck(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),bus+" muted during memory movie")
	ck(await video_has_audio(),"memory movie produces actual audio samples")
	ending.movie.video.finished.emit()
	await frames()
	ck(w.state.ending_phase=="dialogue" and dialogue.active and paused,"movie completion opens paused epilogue")
	ck(root.get_node("Global").boss_track=="memory4" and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"memory BGM restored for dialogue")
	dialogue.select("epilogue_continue")
	c.save_path="res://.godot/finale-resume.json"
	c.saving_enabled=true
	c.save_progress()
	c.saving_enabled=false
	dialogue.close()
	w.queue_free()
	await frames()
	c.reset_state(1)
	ck(c.load_progress(),"isolated epilogue save reloads")
	c.saving_enabled=false
	w=load(c.Catalog.scene_path(37)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	w._process(.01)
	await frames()
	await frames()
	ck(w.state.ending_phase=="dialogue" and int(w.state.ending_page)==1,"resume at saved dialogue page")
	ck(dialogue.active and get_nodes_in_group("victory_video").is_empty(),"watched memory not replayed after reload")
	for i in 3: dialogue.select("epilogue_continue")
	ck(w.state.ending_phase=="farewell" and not w.state.finished,"farewell before victory")
	await create_timer(2.7).timeout
	await frames()
	ck(w.state.finished and 37 in c.completed,"chapter completes after departure")
	ck(root.get_node("Global").boss_track=="victory4","victory BGM after epilogue")
	var videos=get_nodes_in_group("victory_video")
	ck(videos.size()==1 and videos[0].video==null,"victory movie asks first")
	if not videos.is_empty():
		videos[0].play_video()
		ck(videos[0].video.bus==&"Video","victory video uses dedicated audio")
		ck(await video_has_audio(),"victory movie produces actual audio samples")
		for bus in ["Music","Voice","EnemyVoice","Effects"]: ck(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),bus+" muted during victory movie")
		videos[0].close()
	w.queue_free()
	await frames()
	print("CHAPTER4 FIVE-WAVE FINALE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
