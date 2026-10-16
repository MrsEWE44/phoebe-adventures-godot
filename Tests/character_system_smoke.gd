extends SceneTree
var checks := 0
var failures := 0
var campaign: Node
var world: Node2D
var hero: CharacterBody2D
func _initialize():
	call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func actor(id: String, p: Vector2):
	var unit = load("res://Characters/Actors/%s.tscn" % id).instantiate()
	unit.position = p
	world.add_child(unit)
	unit.set_physics_process(false)
	return unit
func clear_shots():
	for shot in get_nodes_in_group("projectiles"):
		shot.queue_free()
	await process_frame
func run():
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	world = Node2D.new()
	root.add_child(world)
	hero = load("res://Player/Phoebe.tscn").instantiate()
	hero.position = Vector2(300,300)
	world.add_child(hero)
	hero.set_physics_process(false)
	var neutral = actor("soldier",Vector2(330,300))
	for id in ["soldier","orc","demon","blood_monster"]:
		var unit = actor(id,Vector2(1000,1000))
		check(unit is GameCharacter,"inherits shared character "+id)
		check(unit.health==unit.definition.max_health and unit.speed==unit.definition.movement_speed,"definition stats "+id)
		check(unit.energy==unit.definition.max_energy and unit.ultimate!=null,"energy and ultimate "+id)
		for animation in [&"idle",&"walk",&"hit",&"death",&"ultimate"]:
			check(unit.animated_sprite.sprite_frames.get_frame_count(animation)>0,"source sprite strip "+id+" "+animation)
		unit.queue_free()
	await process_frame
	for type in ["physical","magic"]:
		neutral.take_damage(99999,type)
	check(neutral.health==neutral.max_health and not neutral.is_dead,"neutral immune to both damage types")
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.position = Vector2(370,300)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3,100)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	var shielded = actor("orc",Vector2(390,300))
	await physics_frame
	await physics_frame
	load("res://Combat/ultimate_effect.gd").release(hero,hero.ultimate,Vector2.RIGHT)
	check(shielded.health==shielded.max_health,"area ultimate cannot hit through terrain")
	wall.queue_free()
	shielded.queue_free()
	await process_frame
	var victim = actor("orc",Vector2(350,300))
	var outside = actor("orc",Vector2(600,300))
	check(hero.trigger_ultimate(Vector2.RIGHT),"player casts area ultimate")
	check(hero.cast_sprite.visible and not hero.animated_sprite.visible,"generated casting animation active")
	check(hero.weapon_mount.definition.weapon_id=="phoebe_relic","ultimate weapon displayed")
	check(campaign.ultimate_charges("phoebe")==2,"charge consumed and stored")
	check(not hero.trigger_ultimate() and not hero.attack() and not hero.drop_weapon(),"windup blocks repeat casts, attack and dropping")
	campaign.profile.nuonuo_unlocked = true
	check(not campaign.switch_character(),"cannot switch during windup")
	hero.take_damage(1)
	check(not hero.reaction_sprite.visible,"hit cannot overlay casting sprite")
	hero.tick_character(1)
	check(victim.is_dead and outside.health==outside.max_health,"area affects nearby enemy only")
	check(neutral.health==neutral.max_health,"area ultimate excludes NPC")
	check(not hero.cast_sprite.visible,"casting sprite cleaned up")
	victim.queue_free()
	outside.queue_free()
	await process_frame
	# Charges have a hard cap and do not waste potions at the cap.
	campaign.profile.ultimate_potions = 5
	for i in 3:
		check(campaign.consume_ultimate_potion(),"charge potion %d" % i)
	check(campaign.ultimate_charges("phoebe")==5 and not campaign.consume_ultimate_potion() and campaign.profile.ultimate_potions==2,"charge cap preserves potion")
	campaign.profile.health = 20
	campaign.profile_changed.emit()
	check(neutral.trigger_ultimate(),"NPC support ultimate")
	neutral.tick_character(1)
	check(campaign.profile.health==55,"NPC support heals nearby player")
	# Real projectile sweep from Nuonuo's ultimate hits the enemy.
	campaign.profile.character = "nuonuo"
	campaign.profile_changed.emit()
	hero.ultimate_cooldown = 0
	var boss = actor("demon",Vector2(380,300))
	await physics_frame
	await physics_frame
	check(hero.trigger_ultimate(Vector2.RIGHT),"Nuonuo casts high damage shot")
	hero.tick_character(1)
	check(get_nodes_in_group("projectiles").size()==1,"single high damage ultimate projectile")
	for shot in get_nodes_in_group("projectiles"):
		shot.set_physics_process(false)
		shot._physics_process(.3)
	check(boss.health==boss.max_health-150,"Nuonuo ultimate deals configured damage")
	await clear_shots()
	var blood = actor("blood_monster",Vector2(900,300))
	blood.ultimate_cooldown = 0
	check(blood.trigger_ultimate(Vector2.LEFT),"boss has usable ultimate")
	blood.tick_character(2)
	check(get_nodes_in_group("projectiles").size()==3,"boss configured three-shot burst")
	for shot in get_nodes_in_group("projectiles"):
		check(shot.hostile and shot.damage==40,"boss shots use enemy faction and configured damage")
	await clear_shots()
	blood.queue_free()
	# Death during windup must cancel the pending attack.
	hero.ultimate_cooldown = 0
	hero.invulnerable = 0
	check(hero.trigger_ultimate(Vector2.RIGHT),"second ultimate starts")
	hero.take_damage(9999)
	hero.tick_character(1)
	check(hero.is_dead and get_nodes_in_group("projectiles").is_empty() and not hero.cast_sprite.visible,"death cancels queued ultimate")
	hero._respawn()
	# Drop at feet, wait, walk away and return to recover exactly once.
	for loot in get_nodes_in_group("loot"):
		loot.queue_free()
	await process_frame
	campaign.grant_drop("iron_pistol")
	check(hero.drop_weapon(),"G drop API")
	check("iron_pistol" not in campaign.profile.weapons and campaign.profile.equipped=="fists","drop updates inventory and equipped")
	var dropped = get_nodes_in_group("loot")[0]
	dropped.set_physics_process(false)
	dropped._physics_process(2)
	check(not dropped.claimed,"standing on dropped weapon does not auto-reclaim")
	hero.position += Vector2(60,0)
	dropped._physics_process(.1)
	hero.position -= Vector2(60,0)
	dropped._physics_process(.1)
	check(dropped.claimed and "iron_pistol" in campaign.profile.weapons,"walking away and back recovers weapon")
	world.queue_free()
	await process_frame
	# Scene-authored chests, NPCs, monsters and saved boss defeat.
	for index in range(1,8):
		campaign.reset_state()
		var level = load("res://Scence/Levels/level_%02d.tscn" % index).instantiate()
		root.add_child(level)
		level.player.set_physics_process(false)
		check(level.guide is GameCharacter and level.guide.character_type==2,"neutral soldier in level %d" % index)
		check(level.get_node("Chests").get_child_count()==3,"three authored chests %d" % index)
		var no_doors: Array[Node2D] = []
		level.geometry.update_doors(no_doors)
		for chest in level.get_node("Chests").get_children():
			check(not level.geometry.path(level.player.position,chest.position).is_empty(),"reachable chest %d/%s" % [index,chest.chest_id])
			check(chest.find_children("*","PhysicsBody2D").is_empty() and chest.get_node("InteractionArea").collision_layer==0,"chest cannot obstruct movement")
		for enemy in get_nodes_in_group("enemies"):
			enemy.set_physics_process(false)
			check(enemy is GameCharacter,"all enemy families use base")
			if enemy.character_type==3:
				enemy.take_damage(99999,"magic")
				check(enemy.persistent_id in campaign.level_state(index).bosses_defeated,"boss defeat saved")
		var chest = level.get_node("Chests/Chest3")
		chest.interact()
		chest.interact()
		check(campaign.profile.ultimate_potions==1,"chest grants only once")
		check("chest_3" in campaign.level_state(index).opened_chests,"opened state saved")
		await create_timer(.65).timeout
		check(not is_instance_valid(chest),"opened chest disappears after animation")
		level.queue_free()
		await process_frame
		var reloaded = load("res://Scence/Levels/level_%02d.tscn" % index).instantiate()
		reloaded.spawn_enemies = false
		root.add_child(reloaded)
		await process_frame
		check(reloaded.get_node("Chests").get_child_count()==2,"opened chest does not respawn")
		reloaded.queue_free()
		await process_frame
	# Save/reload under an isolated test filename, preserving actual campaign data.
	campaign.save_path = "res://.godot/character_system_test.json"
	campaign.saving_enabled = true
	campaign.profile.ultimate_charges.phoebe = 1
	check(campaign.save_progress(),"test save writes successfully")
	campaign.reset_state()
	check(campaign.load_progress() and campaign.ultimate_charges("phoebe")==1,"ultimate charges survive disk reload")
	check("chest_3" in campaign.level_state(7).opened_chests,"chest claim survives disk reload")
	var voice: Resource = load("res://Characters/Voices/nuonuo.tres")
	for event in ["idle","death","battle","angry","afraid","terrified","proud","hurt","skill","ultimate","victory","exhausted","dialogue"]:
		var streams: Array = voice.get(event)
		check(not streams.is_empty(),"Nuonuo voice event "+event)
		for stream in streams:
			check(stream.get_length()>0 and "坤坤" not in stream.resource_path,"valid Nuonuo voice asset "+event)
	campaign.saving_enabled = false
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(campaign.save_path+suffix)
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.2).timeout
	print("CHARACTER SYSTEM: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
