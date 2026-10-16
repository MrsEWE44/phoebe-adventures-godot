extends SceneTree
var checks:=0
var failures:=0
var c: Node
func ck(v: bool, name: String) -> void:
	checks+=1
	if not v: failures+=1;push_error(name)
func _initialize() -> void: call_deferred("run")
func setup(index: int) -> Node2D:
	c.states.erase(str(index))
	if index in c.completed: c.level_state(index).cleared_before=true
	c.active_level=index
	c.hub_chapter=4
	var world=load(c.Catalog.scene_path(index)).instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	world.set_process(false)
	return world
func run() -> void:
	c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(40)
	c.hub_chapter=4
	c.ensure_character_allowed()
	for index in range(28,37):
		c.level_state(index).arena={"finished":true}
		c.complete_arena(index)
	var w=setup(31)
	await process_frame
	w.player.position=w.geometry.nearest(w.get_node("ArenaCenter").position)
	ck(c.select_character("mutsumi"),"select Mutsumi")
	var e=w.spawn_kind("naiwa_minion",false,w.player.position+Vector2(70,0))
	e.set_physics_process(false)
	ck(w.player.trigger_ultimate(Vector2.RIGHT),"Mutsumi ultimate fires")
	ck(e.is_dead,"Mutsumi ultimate clears infant")
	for tick in 32: await physics_frame
	ck(c.select_character("soyo"),"select Soyo")
	# Evolution forces conductor; test the earlier ivory-cello skill separately.
	c.profile.music_forms.soyo_full=false
	c.profile.equipped="fists"
	c.profile_changed.emit()
	e=w.spawn_kind("naiwa_mini",false,w.player.position+Vector2(85,0))
	e.set_physics_process(false)
	ck(w.player.trigger_ultimate(Vector2.RIGHT),"Soyo beam fires")
	ck(e.is_dead,"Soyo beam defeats middle stage")
	for tick in 32: await physics_frame
	ck(c.select_character("anon"),"select Anon")
	ck(w.player.definition.character_id=="anon_dragon","dragon animation applied")
	e=w.spawn_kind("naiwa_full",false,w.player.position+Vector2(80,0))
	e.set_physics_process(false)
	preload("res://Scence/Chapter4/music_combat.gd").play(w.player,Vector2.RIGHT)
	ck(e.record.get("assimilated",false),"full Naiwa assimilated")
	ck(not e.is_in_group("enemies"),"converted enemy no longer hostile")
	ck(w.music_allies.size()==1,"ally created")
	await process_frame
	e=w.spawn_kind("tensura_mini",false,w.player.position+Vector2(80,0))
	e.set_physics_process(false)
	var hp: float=e.health
	preload("res://Scence/Chapter4/music_combat.gd").play(w.player,Vector2.RIGHT)
	ck(e.health<hp,"automatic voice damages Tensura")
	ck(e.slow_remaining>0 and e.outgoing(100)<100*e.damage_scale,"voice slows and weakens damage")
	w.queue_free()
	await process_frame
	w=setup(35)
	await process_frame
	e=w.spawn_kind("penguin_full",true)
	e.record.escape_boss=true
	e.set_physics_process(false)
	e.take_damage(e.max_health*2,"true")
	await process_frame
	ck(w.state.escaped and w.state.finished,"10 percent flee completes encounter")
	w.cinematic_pending=false
	w.queue_free()
	await process_frame
	c.profile.music_forms.soyo_full=true
	w=setup(37)
	await process_frame
	ck(c.select_character("soyo"),"select conductor before finale")
	ck(w.player.normal_weapon.weapon_id=="conductor","conductor equipped")
	ck(w.conduct(w.player),"deploy Mutsumi")
	ck(w.conduct(w.player),"deploy Anon")
	ck(w.conduct(w.player),"deploy Soyo")
	ck(c.profile.character=="ikun" and c.party_ids()==["ikun"],"only Ikun during protection")
	ck(not c.select_character("anon"),"cannot switch during protection")
	w.spawn_enemies=true
	w.next_delay=0
	w._process(.01)
	ck(w.state.wave==1 and not w.state.boss_started,"finale begins with first wave, without boss")
	for enemy in w.living(): enemy.queue_free()
	await process_frame
	preload("res://Scence/Chapter4/final_battle.gd").start_wave(w,3)
	var boss=preload("res://Scence/Chapter4/final_battle.gd").boss(w)
	ck(boss!=null,"final conductor appears in third wave")
	boss.take_damage(boss.max_health*100,"true")
	ck(not boss.is_dead and boss.health>=boss.max_health*.679,"third wave shield preserves later phases")
	# Full five-wave/music/movie ordering is covered by finale.gd.
	w.state.ending_phase="done"
	w.finish()
	ck(w.state.finished and 37 in c.completed,"epilogue completion commits chapter reward")
	ck(root.get_node("Global").boss_track=="victory4","chapter-four victory music")
	w.cinematic_pending=false
	w.queue_free()
	await process_frame
	# Isolated save migration retains music rewards, forms and departed-party restriction.
	c.save_path="res://.godot/chapter4-test-save.json"
	c.saving_enabled=true
	c.active_level=0
	c.profile.character="soyo"
	c.profile.health=c.player_stats("soyo").health
	c.save_progress()
	c.reset_state(1)
	ck(c.load_progress(),"isolated save reload")
	ck(c.profile.soyo_unlocked and c.profile.music_forms.soyo_full,"music progression preserved")
	ck(c.effective_weapon("soyo")=="conductor","conductor after reload")
	ck(not c.character_allowed("phoebe"),"departure persists")
	c.profile.party_health.ikun=0
	ck(not c.enter_level(37),"fallen Ikun cannot strand party in final deployment")
	ck(c.active_level==0,"failed entry remains in hub")
	c.saving_enabled=false
	print("CHAPTER4 COMBAT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
