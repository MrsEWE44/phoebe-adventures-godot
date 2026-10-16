extends SceneTree

var failures := 0
var checks := 0
var campaign: Node
const Catalog = preload("res://Scence/Levels/catalog.gd")

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
	check(campaign.unlocked_level()==1,"new campaign starts at 1-1")
	check(not campaign.is_unlocked(2),"next level locked")
	check(campaign.profile.health==100 and campaign.profile.energy==200,"initial stats")
	for index in range(1,8):
		var scene: PackedScene = load(Catalog.scene_path(index))
		check(scene!=null,"scene %d exists"%index)
		if scene == null:
			continue
		var level = scene.instantiate()
		level.spawn_enemies = false
		root.add_child(level)
		await process_frame
		await physics_frame
		check(level.player!=null,"player loaded %d"%index)
		check(level.geometry.wall_count>40,"separate terrain edges %d"%index)
		var origin: Vector2 = level.player.position
		for mechanism in level.switches:
			var nearest: Vector2 = level.geometry.nearest(mechanism.position)
			check(nearest.distance_to(mechanism.position)<25,"switch on floor %d %s %s -> %s"%[index,mechanism.config.id,mechanism.position,nearest])
			var path: PackedVector2Array = level.geometry.path(origin,nearest)
			check(not path.is_empty(),"switch reachable %d %s at %s"%[index,mechanism.config.id,nearest])
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = level.player.get_node("CollisionShape2D").shape
			query.collision_mask = 2
			var obstruction := Vector2.ZERO
			for point in path:
				if point.distance_to(mechanism.position)<(12 if mechanism.kind=="plate" else 30):
					break
				query.transform = Transform2D(0,point)
				if not level.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
					obstruction = point
					break
			check(obstruction==Vector2.ZERO,"physical path with doors closed %d %s at %s"%[index,mechanism.config.id,obstruction])
		for door in level.doors:
			var nearest: Vector2 = level.geometry.nearest(door.position)
			check(nearest.distance_to(door.position)<35,"door at floor %d %s"%[index,door.config.id])
		check(index not in campaign.completed,"not completed before switches %d"%index)
		for mechanism in level.switches:
			preload("res://Tests/puzzle_helper.gd").solve(mechanism)
		for door in level.doors: door.interact()
		await physics_frame
		check(campaign.level_state(index).doors.size()==level.doors.size(),"all doors open %d"%index)
		for door in level.doors:
			check(not level.geometry.path(origin,door.position).is_empty(),"opened door reachable %d %s"%[index,door.config.id])
		if index==6:
			check(index not in campaign.completed,"rescue required")
			check(campaign.rescue_nuonuo(),"rescue final NPC")
			check(campaign.switch_character(),"unlocked character switch")
			check(level.player.current_character=="nuonuo","nuonuo animation bound")
		check(index in campaign.completed,"completed %d"%index)
		level.queue_free()
		await process_frame
	campaign.active_level = 7
	campaign.saving_enabled = true
	campaign.save_path = "res://.godot/campaign_test_save.json"
	check(campaign.save_progress(),"save write")
	check(campaign.save_progress(),"save replaces existing")
	campaign.reset_state()
	check(campaign.load_progress(),"load")
	check(campaign.completed.size()==7 and campaign.profile.nuonuo_unlocked,"completion persists")
	campaign.reset_state()
	campaign.active_level = 1
	campaign.activate_switch(1,"rune_1")
	campaign.checkpoint(1,Vector2(836,700))
	campaign.profile.health = 73
	campaign.profile.energy = 146
	campaign.save_progress()
	campaign.reset_state()
	check(campaign.load_progress(),"unfinished save load")
	check(campaign.active_level==1 and campaign.completed.is_empty(),"unfinished stays active")
	check(campaign.level_state(1).switches.has("rune_1") and campaign.profile.health==73,"mechanism and stats persisted")
	campaign.saving_enabled = false
	root.get_node("Global").set_process(false)
	for node in root.get_node("Global").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await create_timer(.25).timeout
	print("CAMPAIGN: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
