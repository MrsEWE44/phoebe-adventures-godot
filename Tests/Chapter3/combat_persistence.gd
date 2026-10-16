extends SceneTree
var checks:=0
var failures:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func frames(n:=2) -> void:
	for i in n:
		await process_frame
		await physics_frame
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.save_path="res://.godot/chapter3_test_save.json"
	for index in range(18,27):
		campaign.level_state(index).arena={"finished":true}
		campaign.complete_arena(index)
	campaign.hub_chapter=3
	campaign.profile.character="q_penguin"
	var arena=load("res://Scence/Levels/level_27.tscn").instantiate()
	arena.spawn_enemies=false
	root.add_child(arena)
	var player=arena.player
	player.set_physics_process(false)
	player.position=Vector2(690,460)
	await frames()
	var boss=arena.spawn_kind("penguin_full",true,Vector2(770,455))
	boss.set_physics_process(false)
	boss.emerge_remaining=0
	arena.state.boss_started=true
	arena.state.wave=5
	await frames()
	check(campaign.profile.character=="phoebe","legacy playable Q becomes legal player")
	player.tick_character(.5)
	check(campaign.select_character("doro"),"Doro selectable after unlock")
	check(not campaign.equip_weapon("pili_blade"),"Doro cannot equip another weapon")
	check(player.max_health==campaign.player_stats("doro").health and player.normal_weapon.homing and player.normal_weapon.auto_fire,"Doro HP and automatic homing weapon")
	player.invulnerable=0
	player.take_damage(240)
	check(not player.is_dead and player.health>0,"Doro survives one full boss stone")
	player.apply_status(4,.9,12,4)
	check(player.movement_factor()==0,"sonic binding immobilizes player")
	player.tick_character(1.0)
	check(player.movement_factor()==.5,"binding expires into slow")
	campaign.select_character("phoebe")
	check(player.dot_remaining==0 and player.movement_factor()==1,"switching character clears previous body status")
	boss.take_damage(10,"true")
	check(boss.reaction_sprite.visible and not boss.animated_sprite.visible,"boss hit animation starts")
	boss._physics_process(.5)
	check(not boss.reaction_sprite.visible and boss.animated_sprite.visible,"boss recovers from hit animation")
	check(not bool(boss.record.summoned),"summon telegraph does not prematurely save completed summon")
	boss.execute("summon")
	var full_count: int=arena.living().filter(func(e): return e.definition.character_id=="naiwa_full").size()
	boss.execute("summon")
	check(full_count==4 and arena.living().size()==5,"summon creates exactly four full Naiwa once")
	for enemy in arena.living(): enemy.set_physics_process(false)
	arena.update_music()
	check(root.get_node("Global").boss_track=="penguin","final full boss music takes priority")
	arena.state.elapsed=117.25
	var saved_hp: float=boss.health
	arena.snapshot()
	campaign.saving_enabled=true
	check(campaign.save_progress(),"arena checkpoint writes isolated save")
	campaign.saving_enabled=false
	arena.queue_free()
	await frames()
	check(campaign.load_progress(),"arena checkpoint reloads")
	check(campaign.level_state(27).arena.elapsed==117.25,"elapsed checkpoint survives disk reload")
	arena=load("res://Scence/Levels/level_27.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	await frames()
	check(arena.living().size()==5,"five surviving boss actors restored")
	for enemy in arena.living():
		enemy.set_physics_process(false)
		if enemy.definition.character_id=="penguin_full":
			check(is_equal_approx(enemy.health,saved_hp) and enemy.record.summoned,"boss HP and summon state persist")
	check(arena.player.current_character!="q_penguin","relaunch uses a legal player")
	arena.video_started=true
	arena.ensure_final_bosses()
	for enemy in arena.living(): enemy.take_damage(enemy.max_health*10,"true")
	arena.finish()
	await frames()
	check(arena.living().is_empty(),"victory removes remaining summoned enemies")
	check("penguin_rock" in campaign.profile.weapons and campaign.profile.gugu_unlocked,"final rewards")
	# Finished scene loaded directly must remain clear.
	arena.queue_free()
	await frames()
	arena=load("res://Scence/Levels/level_27.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	await frames()
	check(arena.living().is_empty(),"finished checkpoint never restores leftover actors")
	arena.queue_free()
	await frames()
	# A fresh replay keeps the historical completion and earned character.
	campaign.states.erase("27")
	campaign.level_state(27).cleared_before=true
	campaign.level_state(27).arena={"finished":false,"q_spent":false}
	campaign.saving_enabled=true
	campaign.save_progress()
	campaign.saving_enabled=false
	campaign.load_progress()
	check(27 in campaign.completed and campaign.profile.gugu_unlocked,"replay save retains historical completion and unlocked character")
	check(campaign.unfinished_attempt(),"replay progress remains unfinished until its own battle ends")
	# Friendly meteor affects every combat faction, excluding neutral characters.
	var world:=Node2D.new()
	root.add_child(world)
	var victims: Array=[]
	for type in [0,1,2,3]:
		var unit=load("res://Characters/character_base.gd").new()
		unit.character_type=type
		unit.max_health=1000
		unit.player_controlled=false
		world.add_child(unit)
		unit.set_physics_process(false)
		victims.append(unit)
	var hazard=load("res://Scence/Chapter3/hazard.gd").new()
	hazard.friendly_fire=true
	world.add_child(hazard)
	hazard.set_physics_process(false)
	hazard.strike(100)
	for type in 4: check(victims[type].health==(1000 if type==2 else 900),"meteor target faction %d"%type)
	world.queue_free()
	await frames()
	print("Chapter3 combat/persistence: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

