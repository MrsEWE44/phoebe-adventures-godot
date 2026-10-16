extends SceneTree
var checks:=0
var failures:=0
var campaign: Node
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	campaign.reset_state(40)
	check(campaign.Catalog.TOTAL_LEVELS>=37,"chapter-four levels remain in campaign")
	check(campaign.is_unlocked(28),"chapter-four entry unlocked at 40")
	campaign.profile.player_level=39
	check(not campaign.is_unlocked(28),"level 40 gate")
	campaign.reset_state(40)
	campaign.hub_chapter=4
	campaign.ensure_character_allowed()
	check(campaign.profile.character=="phoebe","chapter-four entry keeps current character")
	for id in ["phoebe","nuonuo","doro","gugu"]: check(campaign.character_allowed(id),id+" available through 4-1")
	check(not campaign.character_allowed("q_penguin"),"Q penguin remains chapter-three only")
	for i in range(28,38):
		campaign.active_level=i
		var scene: PackedScene=load(campaign.Catalog.scene_path(i))
		check(scene!=null,"scene "+str(i))
		if scene==null: continue
		var world=scene.instantiate()
		world.spawn_enemies=false
		root.add_child(world)
		await process_frame
		await physics_frame
		world.set_process(false)
		check(world.geometry.base_free.size()>300,"reachable floor "+str(i))
		var route: PackedVector2Array=world.geometry.path(world.get_node("Spawn").position,world.get_node("Portals/Exit").position)
		check(route.size()>0,"exit route "+str(i))
		check(world.geometry.nearest(world.get_node("Portals/Exit").position).distance_to(world.get_node("Portals/Exit").position)<18,"exit inside floor "+str(i))
		check(world.get_node("Portals/LockedEntrance").locked,"entry locked")
		check(world.get_node("Portals/Exit").locked,"exit locked before victory")
		check(root.get_node("Story").entry(i).has("intro"),"story entry")
		for species in ["naiwa_mini","penguin_full","tensura_minion","tensura_mini","tensura_full","weiro_full"]:
			var enemy=world.spawn_kind(species,true)
			check(enemy!=null and enemy.health>0,"spawn "+species)
			check(enemy.use_scene_collision_shapes,"editable hurtbox "+species)
			enemy.set_physics_process(false)
			if species=="tensura_full" and i>=33: check(not enemy.ability_allowed("beam"),"real Tensura has no hand beam")
			if species=="tensura_minion": check(not enemy.ability_allowed("beam"),"young Tensura no beam")
			if species=="weiro_full": check(enemy.ability_allowed("beam") and enemy.ability_allowed("music_summon"),"impostor skills")
			enemy.record.dead=true
			enemy.queue_free()
		await process_frame
		if i==34:
			world.state.elapsed=120
			world.finish()
			check(not world.state.finished,"survive beyond 120 seconds")
			world.state.elapsed=121
		if i==35: world.state.escaped=true
		if i==37: world.state.ending_phase="done"
		world.finish()
		if i==28:
			for id in ["phoebe","nuonuo","doro","gugu"]: check(not campaign.character_allowed(id),id+" leaves after 4-1 victory")
			check(campaign.profile.character=="ikun","victory hands control to Ikun")
		world.cinematic_pending=false
		check(i in campaign.completed,"completion saved "+str(i))
		check(not world.get_node("Portals/Exit").locked,"exit opens "+str(i))
		world.queue_free()
		await process_frame
	check(campaign.profile.mutsumi_unlocked and campaign.profile.soyo_unlocked and campaign.profile.anon_unlocked,"rescued music characters")
	check(campaign.character_definition("anon").character_id=="anon_dragon","upgraded Anon form")
	check(campaign.profile.music_forms.soyo_full,"Soyo evolution")
	check(campaign.effective_weapon("soyo")=="conductor","Soyo conductor locked")
	campaign.active_level=0
	var hub=load("res://Scence/Chapter4.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await physics_frame
	check(hub.geometry.base_free.size()>200,"hub connected floor")
	for portal in hub.get_node("Portals").get_children():
		check(hub.geometry.nearest(portal.position).distance_to(portal.position)<20,"hub portal reachable "+portal.name)
	hub.queue_free()
	await process_frame
	print("CHAPTER4 RULES: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
