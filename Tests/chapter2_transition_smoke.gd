extends SceneTree
const Catalog = preload("res://Scence/Levels/catalog.gd")
var checks := 0
var failures := 0
var campaign: Node

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	change_scene_to_file("res://Scence/Main.tscn")
	await scene_changed
	var main = current_scene
	main.get_node("菲比").position = Vector2(1094,680)
	Input.action_press("down")
	await frames(35)
	Input.action_release("down")
	check(current_scene.scene_file_path==Catalog.hub_path(2),"physical shore contact enters second hub")
	if current_scene.scene_file_path!=Catalog.hub_path(2):
		quit(1)
		return
	for index in range(8,18):
		var hub = current_scene
		var portal = hub.get_node("Portals/"+str(Catalog.PORTAL_ORDER[index-1]))
		for entrance in hub.get_node("Portals").get_children():
			var id: int = Catalog.portal_level(entrance.portal_id)
			check(entrance.enabled==campaign.is_unlocked(id),"portal lock state matches campaign")
			check(entrance.get_node("Barrier/CollisionShape2D").disabled==entrance.enabled,"locked portal has editor-authored solid barrier")
		hub.player.position = portal.position+Vector2(0,35)
		await frames(2)
		Input.action_press("up")
		await frames(24)
		Input.action_release("up")
		check(current_scene.scene_file_path==Catalog.scene_path(index),"walk into portal "+Catalog.label(index))
		if current_scene.scene_file_path!=Catalog.scene_path(index):
			break
		var level = current_scene
		check(campaign.active_level==index,"active stage persists")
		# Keep an unfinished checkpoint and revisit through the ordinary launch hub.
		campaign.checkpoint(index,level.get_node("Spawn").position)
		change_scene_to_file("res://Scence/Main.tscn")
		await scene_changed
		await frames(4)
		check(current_scene.scene_file_path==Catalog.scene_path(index),"unfinished water stage resumes on launch")
		level=current_scene
		campaign.completed.append(index)
		campaign.return_to_hub()
		await scene_changed
		await frames(4)
		check(current_scene.scene_file_path==Catalog.hub_path(2),"completed stage returns to correct chapter")
		check(current_scene.player.position.distance_to(current_scene.get_node("Portals/"+str(Catalog.PORTAL_ORDER[index-1])).position)>30,"safe portal return avoids immediate reentry")
		await frames(12)
		check(campaign.active_level==0,"no portal bounce after returning")
		print("Transition verified ",Catalog.label(index))
	if current_scene.scene_file_path==Catalog.hub_path(2):
		current_scene.player.position=current_scene.get_node("ReturnPortal").position
		await frames(3)
		check(current_scene.return_inside,"central return trigger detects player")
		var key:=InputEventKey.new()
		key.physical_keycode=KEY_E
		key.pressed=true
		current_scene._unhandled_input(key)
		await frames(4)
		check(current_scene.scene_file_path==Catalog.hub_path(1),"central door returns to shore")
	# Retry and retreat must both remain in the second chapter, even with a fresh profile.
	campaign.reset_state()
	check(campaign.enter_level(8),"enter chapter2 for defeat flow")
	await scene_changed
	current_scene.player.set_physics_process(false)
	preload("res://Tests/puzzle_helper.gd").solve(current_scene.switches[0])
	await process_frame
	for cell in current_scene.geometry.base_free:
		var point: Vector2=current_scene.geometry.nav.get_point_position(cell)
		if not current_scene.is_spawn_safe(point):
			current_scene.player.position=point
			break
	current_scene.player.invulnerable=0
	current_scene.player.take_damage(99999)
	current_scene.player._physics_process(4)
	var defeat: Node
	for child in current_scene.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"):defeat=child
	check(defeat!=null and paused,"water stage defeat opens retry dialog")
	defeat.choose(true)
	await scene_changed
	check(current_scene.level_index==8 and current_scene.player.health==100 and not paused,"retry same water stage")
	check(campaign.level_state(8).doors.is_empty(),"retry resets unfinished seals")
	current_scene.player.set_physics_process(false)
	for cell in current_scene.geometry.base_free:
		var point: Vector2=current_scene.geometry.nav.get_point_position(cell)
		if not current_scene.is_spawn_safe(point):
			current_scene.player.position=point
			break
	current_scene.player.invulnerable=0
	current_scene.player.take_damage(99999)
	current_scene.player._physics_process(4)
	for child in current_scene.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"):defeat=child
	defeat.choose(false)
	await scene_changed
	await frames(4)
	check(current_scene.scene_file_path==Catalog.hub_path(2) and campaign.active_level==0,"defeat retreat goes to water hub")
	check(campaign.enter_level(8),"can reenter after water retreat")
	await scene_changed
	check(current_scene.player.health==100,"reentry after retreat restores health")
	print("Chapter2 transition checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
