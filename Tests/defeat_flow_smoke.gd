extends SceneTree
var failures := 0
var checks := 0
func _initialize():
	call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func defeat_screen(level: Node) -> Node:
	for child in level.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"):
			return child
	return null
func leave_safe_circle(level: Node2D) -> void:
	for cell in level.geometry.base_free:
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.is_spawn_safe(point):
			level.player.position=point
			return
func run():
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	check(campaign.enter_level(1),"enter first level")
	await scene_changed
	var level = current_scene
	level.player.set_physics_process(false)
	campaign.grant_drop("iron_pistol")
	preload("res://Tests/puzzle_helper.gd").solve(level.switches[0])
	await process_frame
	check(not campaign.level_state(1).switches.is_empty(),"puzzle progress before defeat")
	leave_safe_circle(level)
	level.player.invulnerable = 0
	level.player.take_damage(level.player.max_health*2,"true")
	level.player._physics_process(4)
	check(paused and defeat_screen(level)!=null,"defeat screen shown")
	defeat_screen(level).choose(true)
	await scene_changed
	level = current_scene
	check(not paused and level.level_index==1 and level.player.health==level.player.max_health,"retry loads living player in same level")
	check(campaign.level_state(1).doors.is_empty() and get_nodes_in_group("enemies").is_empty(),"retry resets unfinished exploration")
	check("iron_pistol" in campaign.profile.weapons,"retry preserves equipment")
	level.player.set_physics_process(false)
	leave_safe_circle(level)
	level.player.invulnerable = 0
	level.player.take_damage(level.player.max_health*2,"true")
	level.player._physics_process(4)
	defeat_screen(level).choose(false)
	await scene_changed
	await process_frame
	check(campaign.active_level==0 and current_scene.get("level_index")==null and paused and campaign.profile.health==0,"retreat preserves fallen party in hub")
	check(not campaign.enter_level(1),"fallen party cannot reenter before recovery")
	current_scene.get_node("HubRecovery").retry(1)
	await scene_changed
	check(current_scene.player.health==current_scene.player.max_health,"reentry restores the party")
	current_scene.queue_free()
	await process_frame
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("DEFEAT FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
