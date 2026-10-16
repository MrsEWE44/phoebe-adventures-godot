extends SceneTree
var campaign: Node
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func arena(index: int) -> Node:
	var scene=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.player.set_physics_process(false)
	scene.player.invulnerable=100000
	scene.video_started=true
	return scene
func kill_all(level: Node) -> void:
	for enemy in level.living():
		enemy.invulnerable=0
		enemy.take_damage(enemy.max_health*10,"true")
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var start:=Vector2.ZERO
	var hp:=0.0
	var enemy: Node
	var level: Node
	level=arena(26)
	var captive: Node=level.captive
	check(captive.voice.profile==campaign.character_definition("doro").voice_profile,"Doro existing voice assigned")
	check(captive.role=="doro" and captive.get_node("Cage").visible and not captive.released,"Doro captive at entrance")
	check(captive.position.distance_to(level.get_node("Spawn").position)<100,"Doro rescue starts near player entrance")
	start=captive.position
	captive._physics_process(1)
	check(captive.position==start,"captive cannot roam")
	enemy=level.spawn_kind("orc",false,captive.position+Vector2(0,-85))
	enemy.set_physics_process(false)
	enemy.emerge_remaining=0
	level.player.position=level.geometry.nearest(level.get_node("ArenaCenter").position)
	enemy._physics_process(.01)
	check(enemy.combat_target==level.player,"enemy targets player instead of captive Doro")
	check(enemy.voice.profile==null,"ordinary mobs silent")
	var shot=preload("res://Combat/projectile.gd").new()
	shot.hostile=true
	shot.damage=10
	shot.explosion_radius=60
	shot.position=captive.combat_center()
	level.add_child(shot)
	hp=captive.health
	shot._explode(captive)
	check(captive.health==hp,"captive is immune to hostile area damage")
	shot.queue_free()
	captive.invulnerable=0
	shot=preload("res://Combat/projectile.gd").new()
	shot.damage=10
	shot.explosion_radius=60
	shot.position=captive.combat_center()
	level.add_child(shot)
	hp=captive.health
	shot._explode()
	check(captive.health==hp,"friendly weapon explosion does not damage Doro")
	shot.queue_free()
	await frames()
	captive.invulnerable=0
	shot=preload("res://Combat/projectile.gd").new()
	shot.hostile=true
	shot.damage=20
	shot.position=captive.combat_center()+Vector2(30,0)
	shot.direction=Vector2.LEFT
	shot.speed=180
	level.add_child(shot)
	hp=captive.health
	await frames(15)
	check(captive.health==hp and captive.hurtbox.collision_layer==0,"captive is excluded from hostile projectile sweep")
	level.next_delay=0
	level._process(.01)
	level.state.elapsed=240
	level._process(.01)
	check(not level.state.finished,"240 seconds insufficient with surviving enemies")
	kill_all(level)
	level._process(.01)
	check(level.state.finished and captive.released and campaign.profile.doro_unlocked,"survive and clear unlocks Doro and opens cage")
	level.queue_free()
	await frames()
	campaign.states.erase("26")
	level=arena(26)
	level.captive.take_damage(100000,"true")
	await frames()
	check(not level.state.get("failed",false) and not paused and not level.captive.is_dead,"Doro cannot cause an escort failure")
	level.finish()
	check(not level.state.finished,"survival timer is still required")
	level.queue_free()
	await frames()
	# Exercise the actual retry scene transition.
	campaign.recover_from_defeat(26,true)
	await frames(6)
	level=current_scene
	level.set_process(false)
	level.player.set_physics_process(false)
	check(not level.captive.is_dead and level.captive.health==level.captive.max_health and level.state.elapsed==0,"retry restores living Doro and resets timer")
	level.queue_free()
	await frames()
	level=arena(27)
	check(level.config.survival_seconds==0 and level.captive.role=="gugu","final rescue has no timer")
	hp=level.captive.health
	level.captive.take_damage(100000,"true")
	check(level.captive.health==hp,"Gugu remains safe inside boss cage")
	level.state.boss_started=true
	level.ensure_final_bosses()
	check(level.living().size()==4,"legacy final state fills missing required bosses")
	level.ensure_final_bosses()
	check(level.living().size()==4,"required bosses never duplicate")
	for boss in level.living():
		boss.set_physics_process(false)
		check(boss.voice.profile!=null,"boss has state voice: "+boss.definition.character_id)
		if boss.definition.character_id=="penguin_full": boss.take_damage(100000,"true")
	check(level.captive.voice.profile==campaign.character_definition("gugu").voice_profile,"Gugu existing voice assigned")
	await frames()
	check(not level.state.finished and not level.captive.released,"final boss alone cannot open cage")
	kill_all(level)
	await frames()
	check(level.state.finished and level.captive.released and campaign.profile.gugu_unlocked,"all required bosses free Gugu without elapsed-time gate")
	level.queue_free()
	await frames()
	print("Captive rescue: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
