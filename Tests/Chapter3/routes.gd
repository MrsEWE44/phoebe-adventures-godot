extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func walk(level: Node, destination: Vector2) -> bool:
	var path: PackedVector2Array=level.geometry.path(level.player.position,destination)
	if path.is_empty(): return false
	for point in path:
		level.player.move_and_collide(point-level.player.position)
		if level.player.position.distance_to(point)>1: return false
	return true
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	for index in range(17,28):
		campaign.active_level=0
		var level=load("res://Scence/Chapter3.tscn" if index==17 else "res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		if index>17: level.spawn_enemies=false
		root.add_child(level)
		await physics_frame
		await process_frame
		await physics_frame
		level.player.set_physics_process(false)
		for gate in level.get_node("Portals").get_children():
			gate.body_entered.disconnect(gate._entered)
			gate.get_node("Barrier/CollisionShape2D").disabled=true
		await physics_frame
		for gate in level.get_node("Portals").get_children():
			var start: Vector2=level.geometry.safe_spawn(level.get_node("Spawn").position,level.player)
			check(start.is_finite(),"safe start exists")
			level.player.position=start
			check(walk(level,gate.position),"physical walking reaches %d %s"%[index,gate.name])
			var safe: Vector2=level.geometry.safe_spawn(gate.position+Vector2(0,35),level.player)
			check(safe.is_finite() and level.geometry.floor_cells.has(level.geometry.cell_at(safe)),"return spawn inside connected floor")
		level.queue_free()
		await process_frame
	# Chapter2 -> Chapter3 connection is physically reachable on existing geometry.
	campaign.active_level=0
	var ocean=load("res://Scence/Chapter2.tscn").instantiate()
	root.add_child(ocean)
	await physics_frame
	await process_frame
	await physics_frame
	ocean.player.set_physics_process(false)
	var gate=ocean.get_node("Chapter3Passage")
	gate.body_entered.disconnect(gate._entered)
	check(ocean.geometry.nearest(gate.position).distance_to(gate.position)<20,"third chapter passage lies on second chapter floor")
	check(walk(ocean,gate.position),"physical walk from ocean spawn to ice gate")
	ocean.queue_free()
	await process_frame
	print("Chapter3 routes: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
