extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	var c=root.get_node("Campaign")
	var g=root.get_node("Global")
	root.get_node("Story").automatic_enabled=false
	c.saving_enabled=false
	c.reset_state(60)
	c.hub_chapter=5
	c.active_level=46
	c.profile.miku_unlocked=true
	c.profile.reimu_unlocked=true
	c.profile.ikun_unlocked=true
	for index in range(38,46):
		c.level_state(index).arena={"finished":true}
		c.complete_arena(index)
	var w=load(c.Catalog.scene_path(46)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	w.player.set_physics_process(false)
	await frames()
	ck(c.select_character("miku") and g.boss_track=="sakura","select Miku plays Sakura")
	ck(g.boss_player.stream.resource_path.is_empty() and g.boss_player.stream.loop,"character music loops")
	w.update_music()
	ck(g.boss_track=="sakura","scene refresh does not overwrite character music")
	ck(c.select_character("reimu") and g.boss_track=="badapple","select Reimu plays Bad Apple")
	w.state.battle_done=true
	w.update_music()
	ck(g.boss_track=="omo","Omo arrival owns dialogue music")
	ck(c.choose_omo(true),"give capsule starts music lock")
	var playing_stream: AudioStream=g.boss_player.stream
	for id in ["miku","reimu","phoebe"]:
		ck(c.select_character(id),"switch while locked "+id)
		ck(g.boss_track=="omo" and g.boss_player.stream==playing_stream,"switch cannot replace or restart Omo music "+id)
	w.commit_clear()
	ck(g.boss_track=="omo","5-9 completion keeps Omo until 5-10 ends")
	w.queue_free()
	await frames()
	c.active_level=0
	g.set_boss_music("badapple")
	ck(g.boss_track=="omo","hub between rescue stages keeps lock")
	c.save_path="res://.godot/chapter5-music-save.json"
	c.saving_enabled=true
	c.save_progress()
	c.saving_enabled=false
	c.reset_state(1)
	ck(c.load_progress(),"reload isolated music save")
	ck(c.profile.miku_unlocked and c.profile.reimu_unlocked,"earned character unlocks survive reload")
	c.saving_enabled=false
	g.set_boss_music("badapple")
	ck(g.boss_track=="omo","saved music lock survives reload")
	c.active_level=47
	w=load(c.Catalog.scene_path(47)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	w.player.set_physics_process(false)
	await frames()
	ck(g.boss_track=="omo","5-10 battle begins with Omo")
	ck(c.select_character("miku") and g.boss_track=="omo","5-10 character switch stays locked")
	w.state.battle_done=true
	w.update_music()
	ck(g.boss_track=="omo","rescue dialogue before round completion stays locked")
	w.commit_clear()
	ck(g.boss_track=="victory3","final completion releases lock for victory music")
	ck(c.select_character("reimu") and g.boss_track=="badapple","switch after completion may replace victory cue")
	ck(c.select_character("miku") and g.boss_track=="sakura","Miku music after completion")
	playing_stream=g.boss_player.stream
	c.profile_changed.emit()
	ck(g.boss_player.stream==playing_stream,"inventory/stat updates never restart current music")
	var music_bus:=AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus,true)
	c.select_character("reimu")
	ck(AudioServer.is_bus_mute(music_bus),"character switching respects cinematic mute")
	AudioServer.set_bus_mute(music_bus,false)
	w.queue_free()
	await frames()
	c.active_level=46
	c.profile.hell.omo_choice="keep"
	c.level_state(46).arena.omo_music_locked=false
	g.set_boss_music("omo")
	ck(c.select_character("miku") and g.boss_track=="sakura","keep-capsule branch allows character theme")
	c.active_level=0
	c.hub_chapter=2
	g.set_boss_music("")
	ck(c.select_character("reimu") and g.boss_track=="badapple","character theme works in other chapters")
	ck(c.select_character("phoebe") and g.boss_track.is_empty(),"ordinary character restores scene soundtrack")
	print("CHAPTER5 MUSIC: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
