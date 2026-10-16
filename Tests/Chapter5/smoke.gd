extends SceneTree
var count:=0
var fails:=0
func ck(ok: bool,label: String) -> void:
	count+=1
	if not ok: fails+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(60)
	for i in range(28,38):
		c.level_state(i).arena={"finished":true}
		c.complete_arena(i)
	c.active_level=0
	c.hub_chapter=5
	var hub=load(c.Catalog.hub_path(5)).instantiate()
	root.add_child(hub)
	await physics_frame
	await process_frame
	await process_frame
	ck(hub.get_node("Portals").get_child_count()==10,"ten hub gates")
	for gate in hub.get_node("Portals").get_children():
		ck(hub.geometry.nearest(gate.position).distance_to(gate.position)<20,"hub gate on connected floor "+str(gate.level_index))
		ck(not hub.geometry.path(hub.player.position,gate.position).is_empty(),"hub route to "+str(gate.level_index))
	hub.queue_free()
	await process_frame
	for i in range(38,48):
		c.active_level=i
		c.level_state(i).arena={"wave":0,"elapsed":0.0,"records":[],"serial":0,"finished":false,"boss_started":false,"hell_phone_done":true}
		var w=load(c.Catalog.scene_path(i)).instantiate()
		w.spawn_enemies=false
		root.add_child(w)
		w.set_process(false)
		w.player.set_physics_process(false)
		await physics_frame
		await process_frame
		ck(w.geometry.base_free.size()>200,"enough playable floor "+str(i))
		for path in ["Spawn","ArenaCenter","RescuePosition","Portals/Exit"]:
			var pos: Vector2=w.get_node(path).position
			ck(w.geometry.nearest(pos).distance_to(pos)<40,"authored marker on floor %s %s"%[i,path])
			ck(not w.geometry.path(w.player.position,pos).is_empty(),"connected "+path)
		ck(w.get_node("Portals/LockedEntrance").locked and w.get_node("Portals/Exit").locked,"doors locked before clear")
		for k in range(5):
			var species: String=w.wave_species(k)
			var enemy=w.spawn_kind(species)
			ck(enemy!=null and enemy.health>0,"spawn "+species)
			if enemy!=null:
				enemy.set_physics_process(false)
				enemy.combat_target=w.player
				enemy.target_point=w.player.position
				enemy.execute("spit")
				enemy.execute("curse")
				enemy.take_damage(enemy.max_health*2,"true")
		if i>=42:
			var boss=w.spawn_kind("hell_boss_%d"%(i-41),true)
			ck(boss!=null,"hell boss "+str(i))
			boss.set_physics_process(false)
		w.queue_free()
		await process_frame
	print("CHAPTER5 MAP/ASSET SMOKE: %d checks, %d failures"%[count,fails])
	quit(1 if fails else 0)
