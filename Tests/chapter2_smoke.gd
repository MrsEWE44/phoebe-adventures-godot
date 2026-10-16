extends SceneTree
const Catalog = preload("res://Scence/Levels/catalog.gd")
const Helper = preload("res://Tests/puzzle_helper.gd")
var checks := 0
var failures := 0
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	check(campaign.is_unlocked(8) and not campaign.is_unlocked(9),"second chapter independent initial lock")
	var hub = load("res://Scence/Chapter2.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	check(hub.get_node("Portals").get_child_count()==10,"ten portal nodes")
	check(hub.get_node("NPCs").get_child_count()==3,"guide, supplies and weapons")
	for portal in hub.get_node("Portals").get_children():
		var point: Vector2 = portal.position+Vector2(0,32)
		check(hub.geometry.nearest(point).distance_to(point)<15,"hub door reachable: "+str(portal.name))
		check(not hub.geometry.path(hub.player.position,point).is_empty(),"hub path: "+str(portal.name))
	check(not campaign.purchase("harpoon"),"insufficient currency rejected")
	campaign.profile.coins = 250
	check(campaign.purchase("harpoon") and campaign.profile.coins==195,"purchase charged exactly once")
	check(not campaign.purchase("harpoon") and campaign.profile.coins==195,"owned weapon cannot double charge")
	check(campaign.purchase("diving_armor") and campaign.profile.diving_armor,"diving equipment")
	check(campaign.purchase("health") and campaign.profile.health_potions==1,"potion stock")
	hub.queue_free()
	await process_frame
	for index in range(8,18):
		campaign.level_state(index).seed = 20260924+index
		var level = load(Catalog.scene_path(index)).instantiate()
		root.add_child(level)
		level.player.set_physics_process(false)
		level.player.invulnerable = 10000
		level.adventure.start_patrol()
		await Helper.clear_enemies(level)
		check(level.get_node("Terrain").get_child_count()<=250,"compact saved boundary terrain %d" % index)
		for polygon in level.get_node("Terrain").get_children():
			check(polygon is CollisionPolygon2D and polygon.owner==level and polygon.build_mode==CollisionPolygon2D.BUILD_SEGMENTS,"editor-owned floor contour")
		check(level.geometry.nearest(level.get_node("Spawn").position).distance_to(level.get_node("Spawn").position)<12,"spawn lies on road %d" % index)
		for mechanism in level.switches:
			var p: Vector2 = mechanism.position
			check(level.geometry.nearest(p).distance_to(p)<10,"authored switch reachable %d/%s" % [index,mechanism.name])
			check(not level.geometry.path(level.player.position,p).is_empty(),"switch connected %d/%s" % [index,mechanism.name])
			# Traverse the path with the real foot collider, checking every step against saved walls.
			var route: PackedVector2Array=level.geometry.path(level.get_node("Spawn").position,p)
			level.player.position=route[0]
			var blocked:=false
			for step in route:
				if level.player.move_and_collide(step-level.player.position)!=null:
					blocked=true
					break
			check(not blocked,"physical walk reaches puzzle %d/%s" % [index,mechanism.name])
			Helper.solve(mechanism)
			await process_frame
			await physics_frame
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
		for vent in level.get_node("Traps").get_children():
			check(level.geometry.nearest(vent.position).distance_to(vent.position)<10,"vent footprint stays on a usable road")
		await Helper.open_until_final(level)
		check(level.doors.size()==campaign.level_state(index).doors.size(),"all doors open %d" % index)
		check(index not in campaign.completed,"combat required after unsealing %d" % index)
		var saved_rooms:=JSON.stringify(campaign.level_state(index).encounters)
		var wounded=get_nodes_in_group("enemies")[0]
		wounded.take_damage(3,"magic")
		var wounded_id: String=wounded.persistent_id
		var wounded_hp: float=wounded.health
		level.adventure.snapshot()
		saved_rooms=JSON.stringify(campaign.level_state(index).encounters)
		campaign.save_path="res://.godot/chapter2-partial-save.json"
		campaign.saving_enabled=true
		campaign.save_progress()
		level.queue_free()
		await process_frame
		campaign.reset_state()
		check(campaign.load_progress(),"load unfinished chapter2 save")
		campaign.saving_enabled=false
		check(campaign.active_level==index,"unfinished chapter2 remains active")
		level=load(Catalog.scene_path(index)).instantiate()
		root.add_child(level)
		level.player.set_physics_process(false)
		level.player.invulnerable=10000
		await process_frame
		check(JSON.parse_string(saved_rooms)==campaign.level_state(index).encounters,"rooms do not reroll after reload")
		var restored:=false
		for actor in get_nodes_in_group("enemies"):
			actor.set_physics_process(false)
			if actor.persistent_id==wounded_id:
				restored=is_equal_approx(actor.health,wounded_hp)
		check(restored,"wounded water guardian health restored")
		var bosses := 0
		for enemy in get_nodes_in_group("enemies"):
			bosses += int(enemy.character_type==3)
			check(enemy.definition.aquatic,"water creature or submerged guardian")
			check(enemy.hurtbox_shape.shape.size.y>=18,"full body damage area")
			check(level.geometry.nearest(enemy.position).distance_to(enemy.position)<9,"spawn inside floor")
			enemy.take_damage(99999,"magic")
		await process_frame
		check(bosses>=1,"final door guardian %d" % index)
		if index==16: check(campaign.rescue_companion("ikun"),"rescue Ikun before finale")
		check(index in campaign.completed,"stage completes after all guardians die %d" % index)
		check(campaign.profile.ikun_unlocked==(index>=16),"basketball player unlocked at penultimate level %d" % index)
		for chest in get_nodes_in_group("chests"):
			check(level.geometry.nearest(chest.position).distance_to(chest.position)<10,"chest can be reached %d/%s" % [index,chest.name])
		level.queue_free()
		await process_frame
		print("Chapter2 stage verified: ",Catalog.label(index))
	check(campaign.party_ids().has("ikun"),"ikun added to selectable roster")
	check(campaign.switch_character() and campaign.profile.character=="ikun","third character selected even without nuonuo")
	var definition: Resource = campaign.character_definition("ikun")
	check(definition.default_weapon=="basketball" and definition.skill_weapon=="basketball","basketball player defaults")
	check(definition.voice_profile.idle.size()==3 and definition.voice_profile.hurt.size()==2 and definition.voice_profile.death.size()==2,"requested voice slots")
	check(definition.reaction_animations.has_animation("death") and definition.ultimate_animations.has_animation("ultimate"),"death and ultimate animation resources")
	campaign.save_path = "res://.godot/chapter2-test-save.json"
	campaign.saving_enabled = true
	check(campaign.save_progress(),"save second chapter")
	campaign.reset_state()
	check(campaign.load_progress(),"load second chapter")
	check(campaign.second_chapter_complete() and campaign.profile.ikun_unlocked and campaign.profile.character=="ikun","chapter and character survive restart")
	check(campaign.profile.diving_armor and "harpoon" in campaign.profile.weapons,"purchases survive restart")
	campaign.saving_enabled = false
	root.get_node("Global").get_node("AudioStreamPlayer").stop()
	print("Chapter2 checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
