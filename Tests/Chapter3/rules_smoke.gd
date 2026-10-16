extends SceneTree
var campaign: Node
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=2) -> void:
	for i in n:
		await process_frame
		await physics_frame
func clear_enemies(level: Node) -> void:
	for enemy in level.living():
		enemy.invulnerable=0
		enemy.take_damage(enemy.max_health*2,"true")
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.reset_state()
	campaign.saving_enabled=false
	var hub=load("res://Scence/Chapter3.tscn").instantiate()
	root.add_child(hub)
	hub.player.set_physics_process(false)
	await frames()
	check(hub.geometry.base_free.size()<5000,"hub boundary contains only the drawn floor")
	for gate in hub.get_node("Portals").get_children():
		var point: Vector2=hub.geometry.nearest(gate.position)
		check(point.distance_to(gate.position)<28,"hub gate lies on reachable floor "+gate.name)
		check(not hub.geometry.path(hub.get_node("Spawn").position,point).is_empty(),"hub gate path exists "+gate.name)
	hub.queue_free()
	await frames()
	for index in range(18,28):
		var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		level.player.invulnerable=100000
		level.video_started=true
		await frames()
		check(level.get_node("Terrain").get_child_count()<=4,"few editor-authored boundary polygons")
		check(level.geometry.base_free.size()>1500 and level.geometry.base_free.size()<6000,"arena floor contained %d"%index)
		for point in [level.get_node("Spawn").position,level.get_node("ArenaCenter").position,level.get_node("Portals/Exit").position]:
			check(level.geometry.nearest(point).distance_to(point)<30,"authored arena landmark on floor %d"%index)
		check(level.get_node("Portals/LockedEntrance").locked,"entrance always locked")
		level.next_delay=0
		if index in [24,26]:
			level._process(.1)
			check(level.living().size()>=9,"timed level starts with mobs and boss")
			clear_enemies(level)
			await frames()
			level._process(1)
			check(not level.state.finished and not level.living().is_empty(),"timed level refills after early clear")
			level.state.elapsed=level.config.survival_seconds-1
			level._process(1.1)
			if index==26:
				check(not level.state.finished,"Doro requires all remaining enemies dead after configured survival timer")
				clear_enemies(level)
				await frames()
				level._process(.1)
			check(level.state.finished,"configured time and boss defeated finishes timed arena")
		else:
			for wave in int(level.config.waves):
				level.next_delay=0
				level._process(.01)
				check(level.state.wave==wave+1 and not level.living().is_empty(),"wave begins with living enemies")
				var count: int=level.living().size()
				level._process(10)
				check(level.state.wave==wave+1 and level.living().size()==count,"cannot overlap waves before enemies die")
				for enemy in level.living(): enemy.set_physics_process(false)
				clear_enemies(level)
				await frames()
			level.next_delay=0
			level._process(.01)
			if index==27:
				check(level.state.boss_started and not level.state.finished,"final boss required after five waves")
				var boss: Node2D
				for enemy in level.living():
					enemy.set_physics_process(false)
					if enemy.definition.character_id=="penguin_full": boss=enemy
				boss.execute("summon")
				check(level.living().filter(func(e): return e.definition.character_id=="naiwa_full").size()==4,"final boss summons four full Naiwa")
				boss.take_damage(boss.max_health*2,"true")
				await frames()
		check(level.state.finished and index in campaign.completed,"arena completion saved %d"%index)
		check(not level.get_node("Portals/Exit").locked,"exit unlocks only after victory")
		print("Verified chapter3 ",index-17)
		level.queue_free()
		await frames()
	check(campaign.profile.q_penguin_unlocked and campaign.profile.doro_unlocked and campaign.profile.gugu_unlocked,"three unlock milestones")
	check("penguin_rock" in campaign.profile.weapons,"final boss weapon awarded")
	campaign.hub_chapter=1
	check(not campaign.select_character("q_penguin"),"Q penguin forbidden outside chapter3")
	campaign.hub_chapter=3
	check(campaign.hire_mercenary() and campaign.select_character("q_penguin"),"paid Q penguin is selectable in chapter3")
	campaign.hub_chapter=2
	campaign.ensure_character_allowed()
	check(campaign.profile.character!="q_penguin","leaving chapter3 automatically substitutes legal character")
	print("Chapter3 rules: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
