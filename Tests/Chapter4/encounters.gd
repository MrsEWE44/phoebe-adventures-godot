extends SceneTree
var count:=0
var failures:=0
func ck(value: bool, text: String) -> void:
	count+=1
	if not value: failures+=1;push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	for index in range(28,37):
		c.reset_state(40)
		c.hub_chapter=4
		c.active_level=index
		c.ensure_character_allowed()
		var world=load(c.Catalog.scene_path(index)).instantiate()
		root.add_child(world)
		world.set_process(false)
		world.player.invulnerable=9999
		await process_frame
		for wave in 5:
			world.next_delay=0
			world._process(61 if index==34 else .01)
			ck(world.living().size()<=32,"enemy cap "+str(index))
			if index==34:
				for enemy in world.living(): ck(enemy.definition.character_id.ends_with("mini"),"rest stage only middle enemies")
			for enemy in world.living():
				enemy.set_physics_process(false)
				enemy.take_damage(enemy.max_health*100,"true")
			await process_frame
			if world.state.finished: break
		world.next_delay=0
		world._process(.01)
		ck(world.state.finished,"normal encounter completes "+str(index))
		world.cinematic_pending=false
		world.queue_free()
		await process_frame
	# Exercise new AI attacks and summon genealogy under a hard live-actor cap.
	c.reset_state(40)
	c.active_level=33
	c.hub_chapter=4
	var world=load(c.Catalog.scene_path(33)).instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	await process_frame
	world.player.invulnerable=9999
	var boss=world.spawn_kind("weiro_full")
	boss.combat_target=world.player
	boss.target_point=world.player.position
	boss.execute("beam")
	boss.execute("leap")
	ck(boss.leap_remaining>0,"tail leap activated")
	boss.execute("music_summon")
	ck(world.living().any(func(e):return e.definition.character_id=="tensura_full"),"impostor summons real Tensura")
	for i in 60: world.spawn_kind("tensura_minion")
	ck(world.living().size()==32,"excess spawns rejected")
	boss.execute("music_summon")
	ck(world.living().size()==32,"summons cannot exceed cap")
	for i in 35: await physics_frame
	ck(not world.player.is_dead,"telegraph AI runs")
	world.queue_free()
	await process_frame
	# A protected musician falling is a recoverable defeat, not a false victory.
	c.reset_state(40)
	c.active_level=37
	c.hub_chapter=4
	world=load(c.Catalog.scene_path(37)).instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	await process_frame
	world.spawn_performer("mutsumi",0)
	world.music_allies[0].take_damage(99999,"true")
	ck(world.state.get("failed",false) and paused,"musician death opens defeat")
	ck(not world.state.finished,"failed protection cannot win")
	paused=false
	world.queue_free()
	await process_frame
	print("CHAPTER4 ENCOUNTERS: %d checks, %d failures"%[count,failures])
	quit(1 if failures else 0)
