extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func frames() -> void:
	await process_frame
	await physics_frame
	await process_frame
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var level=load("res://Scence/Levels/level_01.tscn").instantiate()
	root.add_child(level)
	level.player.set_physics_process(false)
	level.adventure.set_process(false)
	level.adventure.start_patrol()
	var state: Dictionary=campaign.level_state(1)
	var patrol: Dictionary=state.encounters.patrol
	# Model an older save with three original enemies: one dead and one wounded.
	patrol.actors=patrol.actors.slice(0,3)
	patrol.actors[0].dead=true
	patrol.actors[0].health=0
	patrol.actors[1].health=7
	var original: Array=patrol.actors.duplicate(true)
	for enemy in get_nodes_in_group("enemies"): enemy.free()
	level.adventure.live.clear()
	state.encounters.finished={"kind":"battle","cleared":true,"actors":[],"reward":"health"}
	state.density_revision=0
	level.adventure._upgrade_density()
	check(patrol.actors.size()==8,"old patrol reinforced to eight total, without resurrecting kills")
	check(patrol.actors.slice(0,3)==original,"old IDs, species, position, damage and deaths preserved")
	check(state.encounters.finished.actors.is_empty(),"cleared room remains cleared")
	for record in patrol.actors.slice(3):
		var point:=Vector2(record.position[0],record.position[1])
		check(not level.is_spawn_safe(point) and not level.geometry.path(level.player.position,point).is_empty(),"reinforcement reachable outside safe circle")
	var upgraded: Dictionary=state.duplicate(true)
	level.adventure._upgrade_density()
	check(state==upgraded,"upgrade is idempotent")
	campaign.save_path="res://.godot/density_migration_test.json"
	campaign.saving_enabled=true
	check(campaign.save_progress(),"save reinforced encounter")
	level.queue_free()
	await frames()
	check(campaign.load_progress(),"reload reinforced encounter")
	level=load("res://Scence/Levels/level_01.tscn").instantiate()
	root.add_child(level)
	level.player.set_physics_process(false)
	await frames()
	check(get_nodes_in_group("enemies").size()==7,"reload spawns survivors only")
	var wounded:=false
	for enemy in get_nodes_in_group("enemies"):
		if enemy.persistent_id==str(original[1].id): wounded=enemy.health==7
	check(wounded,"wounded enemy health survives disk reload")
	check(campaign.level_state(1).encounters.patrol.actors.size()==8,"reload cannot duplicate reinforcements")
	level.queue_free()
	await frames()
	campaign.saving_enabled=false
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(campaign.save_path+suffix)
	print("Density migration checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
