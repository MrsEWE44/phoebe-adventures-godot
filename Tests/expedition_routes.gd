extends SceneTree
const Helper=preload("res://Tests/puzzle_helper.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func approach(level: Node2D,target: Vector2,limit: float) -> Vector2:
	var best:=Vector2.INF
	var distance:=limit
	for cell in level.geometry.reachable_cells(level.player.position):
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if point.distance_to(target)<distance:
			distance=point.distance_to(target)
			best=point
	return best
func approach_door(level: Node2D,door: Node2D) -> Vector2:
	for cell in level.geometry.reachable_cells(level.player.position):
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if door.interaction_distance(point)<42: return point
	return Vector2.INF
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	for index in range(1,18):
		campaign.reset_state()
		var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		level.spawn_enemies=false
		root.add_child(level)
		level.player.set_physics_process(false)
		var total: int=level.switches.size()+level.doors.size()
		var done:=0
		for step in total+1:
			var advanced:=false
			for mechanism in level.switches:
				if mechanism.activated or not mechanism.prerequisites_met(): continue
				var point:=approach(level,mechanism.position,14 if mechanism.puzzle.mode=="hold" else 36)
				if not point.is_finite(): continue
				level.player.position=point
				Helper.solve(mechanism)
				check(mechanism.activated,"reachable puzzle solves %d/%s"%[index,mechanism.name])
				done+=1
				advanced=true
			for door in level.doors:
				if not level.can_open_door(door): continue
				var point:=approach_door(level,door)
				if not point.is_finite(): continue
				level.player.position=point
				door.interact()
				check(door.activated,"reachable door opens %d/%s"%[index,door.name])
				done+=1
				advanced=true
			if not advanced: break
		check(done==total,"no key behind its own locked door %d (%d/%d)"%[index,done,total])
		check(approach(level,level.get_node("ReturnPortal").position,30).is_finite(),"exit reachable %d"%index)
		if index in [6,16]: check(approach(level,level.npc.position,36).is_finite(),"companion reachable")
		for chest in level.get_node("Chests").get_children():
			check(approach(level,chest.position,32).is_finite(),"authored chest reachable %d/%s"%[index,chest.name])
		for actor in get_nodes_in_group("story_guides"):
			if actor.get_parent()==level:
				check(approach(level,actor.position,36).is_finite(),"service NPC reachable %d/%s"%[index,actor.name])
		if done!=total:
			for mechanism in level.switches+level.doors:
				if not mechanism.activated: print("Remaining: ",mechanism.name," at ",mechanism.position," nearest reachable: ",approach(level,mechanism.position,9999)," permitted: ",level.can_open_door(mechanism) if mechanism in level.doors else mechanism.prerequisites_met())
		level.queue_free()
		await process_frame
	print("Expedition route checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
