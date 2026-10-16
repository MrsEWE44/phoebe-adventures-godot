extends SceneTree
## Save/reload edited scenes, then verify physics and navigation use the edits.
const Catalog = preload("res://Scence/Levels/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func physical_hit(level: Node2D, p: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1
	query.shape = shape
	query.transform = Transform2D(0,p)
	query.collision_mask = 2
	return not level.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	for index in range(1,18):
		var level = load(Catalog.scene_path(index)).instantiate()
		check(level.get_node("Terrain") is StaticBody2D,"saved terrain %d" % index)
		for polygon in level.get_node("Terrain").get_children():
			check(polygon is CollisionPolygon2D and polygon.owner == level and polygon.build_mode==CollisionPolygon2D.BUILD_SEGMENTS and polygon.polygon.size()>=3,"editable floor contour %d %s" % [index,polygon.name])
		for door in level.get_node("Doors").get_children():
			var collider = door.get_node("Barrier/CollisionShape2D")
			check(collider.owner==level and collider.shape!=null,"saved door shape %d" % index)
			check(str(door.config.id) in Catalog.all_door_ids(index),"completion reads scene door %d" % index)
		for trap in level.get_node("Traps").get_children():
			check(trap is Area2D and trap.get_node("CollisionShape2D").owner==level,"saved trap area %d" % index)
		check(level.get_node("ReturnPortal/CollisionShape2D").owner==level,"saved portal %d" % index)
		level.free()

	var original = load(Catalog.scene_path(1)).instantiate()
	original.spawn_enemies = false
	root.add_child(original)
	await process_frame
	var spawn: Vector2 = original.get_node("Spawn").position
	var obstacle_point: Vector2 = original.geometry.nearest(spawn+Vector2(0,-65))
	var door_point: Vector2 = original.geometry.nearest(spawn+Vector2(65,-30))
	var trap_point: Vector2 = original.geometry.nearest(spawn+Vector2(-100,-60))
	original.free()

	var edited = load(Catalog.scene_path(1)).instantiate()
	edited.spawn_enemies = false
	var obstacle := CollisionPolygon2D.new()
	obstacle.name = "EditorAddedObstacle"
	obstacle.position = obstacle_point
	obstacle.rotation = .25
	obstacle.scale = Vector2(1.2,.8)
	obstacle.polygon = PackedVector2Array([Vector2(-12,-8),Vector2(12,-8),Vector2(12,8),Vector2(-12,8)])
	edited.get_node("Terrain").add_child(obstacle)
	obstacle.owner = edited
	var door = edited.get_node("Doors").get_child(0)
	var door_path: NodePath = edited.get_path_to(door)
	door.position = door_point-Vector2(8,0)
	var door_shape = door.get_node("Barrier/CollisionShape2D")
	door_shape.position = Vector2(8,0)
	door_shape.rotation = .4
	door_shape.shape.size = Vector2(20,18)
	var trap = edited.get_node("Traps").get_child(0)
	var trap_path: NodePath = edited.get_path_to(trap)
	trap.position = trap_point-Vector2(7,0)
	var trap_shape = trap.get_node("CollisionShape2D")
	trap_shape.position = Vector2(7,0)
	trap_shape.rotation = .3
	trap_shape.shape.size = Vector2(18,14)
	edited.get_node("ReturnPortal").position = spawn
	edited.get_node("ReturnPortal/CollisionShape2D").position = Vector2(10,0)
	edited.get_node("ReturnPortal/CollisionShape2D").shape.radius = 17
	var expected_count: int = edited.get_node("Terrain").get_child_count()
	var packed := PackedScene.new()
	check(packed.pack(edited)==OK,"pack authored edits")
	check(ResourceSaver.save(packed,"res://.godot/edited_collision_test.tscn")==OK,"save authored edits")
	edited.free()
	var reloaded = load("res://.godot/edited_collision_test.tscn").instantiate()
	root.add_child(reloaded)
	for hazard in reloaded.get_node("Traps").get_children():
		hazard.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(reloaded.get_node("Terrain").get_child_count()==expected_count,"runtime preserves saved terrain without duplication")
	check(reloaded.get_node("Terrain/EditorAddedObstacle").position==obstacle_point,"runtime preserves polygon position")
	check(physical_hit(reloaded,obstacle_point),"edited rotated polygon blocks physical body")
	check(reloaded.geometry.nav.is_point_solid(reloaded.geometry.cell_at(obstacle_point)),"edited polygon blocks enemy navigation")
	door = reloaded.get_node(door_path)
	check(door.collision.position==Vector2(8,0) and door.collision.shape.size==Vector2(20,18),"saved door size and offset preserved")
	check(physical_hit(reloaded,door_point),"edited door physically blocks")
	check(reloaded.geometry.nav.is_point_solid(reloaded.geometry.cell_at(door_point)),"edited door blocks navigation")
	campaign.open_door(1,str(door.config.id))
	reloaded.refresh_doors()
	await physics_frame
	await physics_frame
	check(not physical_hit(reloaded,door_point),"opened edited door removes physical block")
	check(not reloaded.geometry.nav.is_point_solid(reloaded.geometry.cell_at(door_point)),"opened edited door removes navigation block")
	trap = reloaded.get_node(trap_path)
	check(trap.position==trap_point-Vector2(7,0) and trap.collision.shape.size==Vector2(18,14),"saved trap transform and size preserved")
	reloaded.player.position = trap_point
	await physics_frame
	await physics_frame
	check(trap.overlaps_body(reloaded.player),"edited trap Area detects body")
	trap.time = 0
	var health: int = campaign.profile.health
	trap._physics_process(0)
	check(campaign.profile.health<health,"edited trap triggers damage")
	reloaded.player.position = spawn
	await physics_frame
	await physics_frame
	check(not trap.overlaps_body(reloaded.player),"outside edited trap does not overlap")
	check(reloaded.exit_inside,"saved moved portal emits entered")
	check(reloaded.exit_area.get_node("CollisionShape2D").shape.radius==17,"saved portal radius preserved")
	reloaded.queue_free()
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("EDITOR COLLISIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
