extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await physics_frame
	await process_frame
	await process_frame
func run() -> void:
	var c=root.get_node("Campaign")
	var d=root.get_node("Dialogue")
	var story=root.get_node("Story")
	story.automatic_enabled=false
	c.saving_enabled=false
	c.reset_state(60)
	for i in range(28,38):
		c.level_state(i).arena={"finished":true}
		c.complete_arena(i)
	for i in range(38,48):
		c.active_level=i
		c.hub_chapter=5
		var w=load(c.Catalog.scene_path(i)).instantiate()
		w.spawn_enemies=false
		root.add_child(w)
		w.set_process(false)
		w.player.set_physics_process(false)
		w.player.invulnerable=99999
		await frames()
		if i==42:
			ck(d.active,"Phoebe phone automatically opens")
			d.select("answer")
			ck(story.last_voice_emotion=="angry","phone starts angry")
			d.select("listen")
			ck(story.last_voice_emotion=="afraid","phone becomes vulnerable")
			d.select("listen")
			d.select("promise")
			await frames()
			ck(w.state.hell_phone_done and not paused,"phone completion restores combat")
		if i==47:
			ck(w.omo_actor==null,"keep branch has no Omo helper")
		w.spawn_enemies=true
		for wave in range(1,int(w.config.waves)+1):
			w._process(4)
			ck(int(w.state.wave)==wave,"5-%d wave %d"%[i-37,wave])
			ck(not w.living().is_empty() and w.living().size()<=30,"bounded enemy wave")
			var bosses: Array=w.living().filter(func(e):return e.definition.character_id.begins_with("hell_boss"))
			ck(bosses.size()==(1 if i>=42 and wave==int(w.config.waves) else 0),"boss only in final wave")
			for e in w.living():
				e.set_physics_process(false)
				e.take_damage(e.max_health*100,"true")
			await frames()
		w._process(4)
		ck(w.state.battle_done and not w.state.finished,"story before exit unlock")
		w.start_ending()
		await frames()
		var end=w.get_children().filter(func(n):return n.get_script()==load("res://Scence/Chapter5/ending.gd"))[0]
		for page in range(story.entry(i).ending.size()):
			if i==46 and page==story.entry(i).ending.size()-1:
				d.select("keep")
				ck(c.profile.hell.omo_choice=="keep" and c.item_count("time_capsule")==1,"keep capsule persisted")
				d.select("finish")
			elif i==47 and page==1:
				d.select("hug")
				ck(story.last_voice_emotion=="victory","hug gets its own voiced reply")
				d.select("continue")
			else: d.select("continue")
			await frames()
		if i in [40,47]:
			ck(is_instance_valid(end.movie),"chapter movie created")
			if i==47: ck(end.movie.video!=null and end.movie.video.is_playing(),"Phoebe movie automatically plays")
			else: ck(end.movie.video==null,"BadApple offers choice first")
			end.movie.close()
			await frames()
		ck(w.state.finished and i in c.completed and not w.get_node("Portals/Exit").locked,"clear and unlock exit")
		if i==39: ck(c.profile.miku_unlocked and root.get_node("Global").boss_track=="sakura","Miku unlock and Sakura BGM")
		if i==40: ck(c.profile.reimu_unlocked and root.get_node("Global").boss_track=="badapple","Reimu unlock and BadApple BGM")
		if i==41:
			ck(not c.character_allowed("soyo") and c.character_allowed("miku"),"original music team departs, guest remains")
			c.hub_chapter=4
			ck(c.character_allowed("soyo"),"chapter four replay allows music team")
			c.hub_chapter=5
		if i in [43,44,45,47]: ck(c.character_allowed({43:"doro",44:"gugu",45:"nuonuo",47:"phoebe"}[i]),"rescued friend selectable")
		w.queue_free()
		await frames()
	ck(c.friendship_active(),"all four living enables friendship")
	c.profile.party_health.doro=0
	ck(not c.friendship_active(),"one fallen friend disables friendship")
	c.profile.party_health.doro=400
	ck(c.friendship_active(),"revived friend restores friendship")
	c.active_level=46
	c.profile.hell.omo_choice=""
	ck(c.choose_omo(true) and not c.profile.hell.capsule,"give branch consumes capsule")
	ck(not c.choose_omo(false),"cannot change committed bargain")
	c.active_level=47
	c.states.erase("47")
	var w=load(c.Catalog.scene_path(47)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	await frames()
	ck(is_instance_valid(w.omo_actor),"give branch spawns autonomous Omo")
	var e=w.spawn_kind("hell_boss_6",true,w.omo_actor.position+Vector2(30,0))
	e.set_physics_process(false)
	w.omo_actor._physics_process(.5)
	ck(e.is_dead,"Omo spin clears final boss")
	w.queue_free()
	await frames()
	c.active_level=0
	c.hub_chapter=5
	c.save_path="res://.godot/chapter5-flow-save.json"
	c.saving_enabled=true
	c.save_progress()
	c.saving_enabled=false
	c.reset_state(1)
	ck(c.load_progress(),"isolated save reload")
	c.saving_enabled=false
	ck(c.hub_chapter==5 and c.profile.miku_unlocked and c.profile.reimu_unlocked and c.profile.hell.omo_choice=="give","new chapter party and branch survive load")
	print("CHAPTER5 FLOW: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
