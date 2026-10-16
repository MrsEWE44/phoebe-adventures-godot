extends SceneTree

var checks := 0
var failures := 0
const Catalog = preload("res://Scence/Levels/catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	change_scene_to_file("res://Scence/Main.tscn")
	await scene_changed
	await frames(3)
	for index in range(1,8):
		var hub: Node2D = current_scene
		var player: CharacterBody2D = hub.get_node("菲比")
		var target: Area2D
		for portal in hub.get_node("Level/Level1/Environment/Portals").get_children():
			var number: int = Catalog.portal_level(portal.portal_id)
			check(portal.enabled==(number<=index),"hub lock flag %d at step %d"%[number,index])
			if number>index:
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = player.get_node("CollisionShape2D").shape
				query.transform = Transform2D(0,portal.get_node("CollisionShape2D").global_position)
				query.collision_mask = 2
				check(not hub.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"locked entrance physically solid %d"%number)
			if number==index:
				target = portal
		var collision: CollisionShape2D = target.get_node("CollisionShape2D")
		var start := target.global_position+Vector2(0,60)
		if index==3:
			start = Vector2(245,310)
		elif index==4:
			start = Vector2(254,200)
		player.position = start
		await frames(3)
		if index==3:
			Input.action_press("left")
			await frames(48)
			Input.action_release("left")
		Input.action_press("up")
		for frame in 110:
			await frames(1)
			if is_instance_valid(current_scene) and current_scene.get("level_index")!=null:
				break
		Input.action_release("up")
		await frames(3)
		check(current_scene.get("level_index")==index,"actual walking changes to 1-%d"%index)
		if current_scene.get("level_index")!=index:
			break
		var level: Node2D = current_scene
		for enemy in get_nodes_in_group("enemies"):
			enemy.queue_free()
		check(campaign.unfinished_attempt(),"unfinished stage retains a resumable checkpoint")
		for mechanism in level.switches:
			preload("res://Tests/puzzle_helper.gd").solve(mechanism)
		await preload("res://Tests/puzzle_helper.gd").open_until_final(level)
		await frames(2)
		for enemy in get_nodes_in_group("enemies"):
			enemy.take_damage(99999,"magic")
		await frames(2)
		if index==6:
			campaign.rescue_nuonuo()
		check(campaign.return_to_hub(),"completed stage returns")
		await scene_changed
		await frames(6)
		check(current_scene.get("level_index")==null,"hub remains stable without portal bounce")
		var returned_player: CharacterBody2D = current_scene.get_node("菲比")
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = returned_player.get_node("CollisionShape2D").shape
		query.transform = returned_player.global_transform
		query.collision_mask = 34
		query.collide_with_areas = true
		check(returned_player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"return spawn clear %d"%index)
	# Restart at the hub must resume an unfinished active level.
	campaign.reset_state()
	campaign.active_level = 1
	change_scene_to_file("res://Scence/Main.tscn")
	for i in 15:
		await frames(1)
	check(current_scene.get("level_index")==1,"launch resumes unfinished stage")
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.25).timeout
	print("TRANSITIONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
