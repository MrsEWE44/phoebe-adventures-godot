extends SceneTree
var checks := 0
var failures := 0
var campaign: Node
const Helper = preload("res://Tests/puzzle_helper.gd")
func _initialize():
	call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func stop_actors(level: Node):
	level.player.set_physics_process(false)
	level.player.invulnerable = 1000
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
func run():
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	for index in range(1,8):
		campaign.level_state(index).seed = 20260924+index
		var path := "res://Scence/Levels/level_%02d.tscn" % index
		var level = load(path).instantiate()
		root.add_child(level)
		stop_actors(level)
		check(level.adventure!=null,"level has adventure rules %d" % index)
		check(get_nodes_in_group("enemies").is_empty(),"no enemies appear before unsealing %d" % index)
		for mechanism in level.switches:
			var route: PackedVector2Array = level.geometry.path(level.player.position,mechanism.position)
			check(not route.is_empty(),"unsolved puzzle reachable %d/%s" % [index,mechanism.name])
			check(not mechanism.puzzle.is_empty(),"authored puzzle %d/%s" % [index,mechanism.name])
			if mechanism.puzzle.mode in ["sequence","memory"]:
				mechanism.choose(str((int(mechanism.puzzle.sequence[0])+1)%4))
				check(not mechanism.activated and mechanism.sequence_index==0,"wrong rune cannot open seal")
			elif mechanism.puzzle.mode=="direction":
				mechanism.turns=posmod(int(mechanism.puzzle.target)+1,4)
				mechanism.choose("confirm")
				check(not mechanism.activated,"wrong direction cannot open seal")
			elif mechanism.puzzle.mode=="hold":
				var before: Vector2 = level.player.position
				level.player.position = mechanism.position
				mechanism._process(.2)
				level.player.position = before
				mechanism._process(.1)
				check(not mechanism.activated and mechanism.charge_elapsed==0,"leaving plate resets charge")
			Helper.solve(mechanism)
			check(mechanism.activated,"solved mechanism activates %d/%s"%[index,mechanism.name])
			await process_frame
			await physics_frame
			stop_actors(level)
		await Helper.open_until_final(level)
		check(campaign.level_state(index).doors.size()==level.doors.size(),"every door opens %d" % index)
		check(campaign.level_state(index).encounters.size()==level.doors.size()+1,"one persistent encounter per door plus patrol %d" % index)
		check(index not in campaign.completed,"uncleared rooms block completion %d" % index)
		var bosses := 0
		for enemy in get_nodes_in_group("enemies"):
			check(not level.geometry.path(level.player.position,enemy.position).is_empty(),"spawn is reachable %d/%s" % [index,enemy.persistent_id])
			check(enemy.hurtbox.collision_layer==8 and enemy.hurtbox_shape.shape.size.y>15,"full-body damage area")
			if enemy.character_type==3:
				bosses += 1
		check(bosses>=1 if index!=1 else not get_nodes_in_group("enemies").is_empty(),"final encounter remains to clear %d" % index)
		# Preserve active rooms and a damaged enemy across scene reload.
		var first = get_nodes_in_group("enemies")[0]
		first.take_damage(1,"magic")
		var persistent_id: String = first.persistent_id
		var expected_hp: float = first.health
		level.adventure.snapshot()
		var rolled := JSON.stringify(campaign.level_state(index).encounters)
		level.queue_free()
		await process_frame
		campaign.save_path = "res://.godot/adventure_test_save.json"
		campaign.saving_enabled = true
		check(campaign.save_progress(),"encounter save writes")
		campaign.reset_state()
		check(campaign.load_progress(),"encounter disk reload")
		campaign.saving_enabled = false
		check(index not in campaign.completed,"all-open unfinished combat does not become completed on load")
		level = load(path).instantiate()
		root.add_child(level)
		await process_frame
		stop_actors(level)
		check(JSON.parse_string(rolled)==campaign.level_state(index).encounters,"reload does not reroll rooms %d" % index)
		var restored := false
		for enemy in get_nodes_in_group("enemies"):
			if enemy.persistent_id==persistent_id:
				restored = is_equal_approx(enemy.health,expected_hp)
		check(restored,"enemy health restored %d" % index)
		for enemy in get_nodes_in_group("enemies"):
			enemy.take_damage(99999,"magic")
		await process_frame
		check(campaign.encounters_cleared(index),"all rooms cleared %d" % index)
		check(level.adventure.cleared_count()==level.doors.size(),"room objective count %d" % index)
		if index==6:
			check(campaign.rescue_nuonuo(),"rescue after final guardian")
		check(index in campaign.completed,"exploration puzzle combat completion %d" % index)
		for room_id in campaign.level_state(index).encounters:
			var room: Dictionary=campaign.level_state(index).encounters[room_id]
			if room.kind!="npc": check(level.get_node("Chests").has_node("room_"+str(room_id)),"cleared combat and treasure rooms produce rewards")
		level.queue_free()
		await process_frame
	# Real torso hits, projectile thickness and neutral immunity in an isolated arena.
	campaign.reset_state()
	campaign.active_level=1 # This fixture is a battle, not the hub recovery scene.
	var arena := Node2D.new()
	root.add_child(arena)
	var hero = load("res://Player/Phoebe.tscn").instantiate()
	delete_camera(hero)
	arena.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector2(150,300)
	var enemy = load("res://Characters/Actors/orc.tscn").instantiate()
	enemy.position = Vector2(300,300)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	var shot = load("res://Combat/projectile.gd").new()
	shot.position = Vector2(230,276)
	shot.damage = 10
	shot.damage_type = "magic"
	shot.speed = 1000
	arena.add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(.1)
	check(enemy.health==enemy.max_health-10,"projectile hits upper body above feet")
	var neutral = load("res://Characters/Actors/soldier.tscn").instantiate()
	arena.add_child(neutral)
	neutral.take_damage(9999,"magic")
	check(neutral.health==neutral.max_health and neutral.hurtbox.collision_layer==0,"NPC immune and excluded from projectile queries")
	# Context-driven voices: removed character menu, fear once, anger after repeated hits.
	check(not hero.has_method("interact_with_character"),"player interaction menu removed")
	hero.combat_voice.enter_area("new_test_room")
	check(hero.combat_voice.pending=="afraid","new room requests fear")
	hero.combat_voice.pending = ""
	hero.combat_voice.enter_area("new_test_room")
	check(hero.combat_voice.pending.is_empty(),"same room does not repeat fear")
	for i in 3:
		hero.combat_voice.hurt()
	check(hero.combat_voice.pending=="angry","repeated damage triggers anger")
	hero.combat_voice.pending = ""
	hero.combat_voice.elapsed = 20
	hero.combat_voice.next_line = 0
	for i in 4:
		hero.combat_voice.attacked()
	check(hero.combat_voice.pending=="battle","battle uses former interactive voice slots")
	check(AudioServer.get_bus_index("Voice")>0 and AudioServer.get_bus_index("Music")>0,"separate audio buses")
	var global = root.get_node("Global")
	check(global.audio_levels.Music<=-28,"music default reduced")
	hero.voice.stop()
	hero.voice.elapsed = 10
	hero.voice.play_event("death")
	await create_timer(.1).timeout
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))==global.audio_levels.Music,"music volume remains independent during speech")
	# Death rotates living party members once, then opens the defeat screen.
	campaign.profile.nuonuo_unlocked = true
	hero.invulnerable = 0
	hero.take_damage(9999)
	hero._physics_process(4)
	check(not hero.is_dead and hero.current_character=="nuonuo","death automatically selects living teammate")
	check(campaign.profile.party_health.phoebe==0 and not campaign.switch_character(),"dead teammate cannot be manually reused")
	hero.invulnerable = 0
	hero.take_damage(9999)
	hero._physics_process(4)
	check(hero.is_dead and paused,"party defeat pauses game")
	var screen: Node
	for child in arena.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"):
			screen = child
	check(screen!=null and screen.active,"defeat offers restart and retreat")
	paused = false
	arena.queue_free()
	await process_frame
	global.set_process(false)
	for child in global.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("ADVENTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func delete_camera(hero: Node):
	hero.get_node("Camera2D").enabled = false
