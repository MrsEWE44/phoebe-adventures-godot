extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	var d=root.get_node("Dialogue")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(60)
	c.hub_chapter=5
	c.active_level=38
	# Isolate navigation from the mandatory 5-5 phone, tested by flow.gd.
	c.level_state(42).arena={"finished":false,"hell_phone_done":true,"records":[],"wave":0,"elapsed":0.0,"serial":0,"boss_started":false}
	change_scene_to_file(c.Catalog.scene_path(38))
	await scene_changed
	for index in range(38,48):
		var w=current_scene
		w.spawn_enemies=false
		w.set_process(false)
		w.player.set_physics_process(false)
		w.commit_clear()
		await process_frame
		ck(not w.get_node("Portals/Exit").locked,"exit unlocked "+str(index))
		w.get_node("Portals/Exit")._entered(w.player)
		ck(d.active and paused,"touching exit opens choices "+str(index))
		var caption: String="进入5-%d"%(index-36) if index<47 else "返回第五章主场景"
		var buttons=d.choices_box.get_children().filter(func(b):return b.text==caption)
		ck(buttons.size()==1,"actual next-level button "+str(index))
		if not buttons.is_empty(): buttons[0].pressed.emit()
		for tick in 90:
			await process_frame
			if current_scene!=null and current_scene!=w: break
		ck(current_scene!=null and current_scene!=w,"button changes scene "+str(index))
		ck(c.active_level==(index+1 if index<47 else 0),"correct destination "+str(index))
		ck(not paused and not c.transitioning,"movement unlocked "+str(index))
		if failures: break
	if failures==0:
		for index in range(38,48):
			c.active_level=0
			c.return_portal=c.Catalog.PORTAL_ORDER[index-1]
			change_scene_to_file(c.Catalog.hub_path(5))
			await scene_changed
			var hub=current_scene
			for tick in 8: await physics_frame
			ck(current_scene==hub and c.active_level==0,"return stays in hub "+str(index))
			if current_scene!=hub: break
			ck(hub.get_node("Portals").get_children().all(func(g):return not g.overlaps_body(hub.player)),"return outside every portal "+str(index))
			ck(hub.geometry.nearest(hub.player.position).distance_to(hub.player.position)<12,"return remains on walkable floor "+str(index))
	if failures==0:
		# Existing affected saves have already cleared 5-4, then accidentally replayed it.
		ck(c.enter_level(41),"re-enter completed 5-4")
		await scene_changed
		current_scene.spawn_enemies=false
		current_scene.set_process(false)
		ck(not current_scene.state.finished and 41 in c.completed,"replay keeps historical clear")
		ck(c.return_to_hub(),"leave unfinished replay via pause action")
		await scene_changed
		for tick in 8: await physics_frame
		ck(c.active_level==0 and c.is_unlocked(42),"5-5 remains accessible without replaying 5-4")
	d.close()
	if current_scene!=null: current_scene.queue_free()
	await process_frame
	print("CHAPTER5 EXIT BUTTONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
