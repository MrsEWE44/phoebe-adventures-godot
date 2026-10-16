extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func settle() -> void:
	for i in 3:
		await physics_frame
		await process_frame
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	change_scene_to_file("res://Scence/Chapter2.tscn")
	await scene_changed
	await settle()
	current_scene.get_node("Chapter3Passage")._entered(current_scene.player)
	await scene_changed
	await settle()
	check(current_scene.scene_file_path=="res://Scence/Chapter3.tscn","ocean passage changes to chapter3")
	var preview=current_scene.get_node("Portals/Chapter4Preview")
	var requests: Array=[]
	preview.transition_requested.connect(func(id,chapter,level): requests.append([id,chapter,level]))
	preview._entered(current_scene.player)
	await settle()
	check(requests.is_empty(),"chapter4 requires level 40")
	campaign.profile.player_level=40
	preview.refresh()
	preview._entered(current_scene.player)
	await settle()
	check(requests.size()==1 and requests[0][1]==4 and current_scene.scene_file_path=="res://Scence/Chapter3.tscn","chapter4 emits request without scene change")
	current_scene.get_node("NPCs/Guide").interact()
	check(root.get_node("Dialogue").active and paused,"guide opens modal dialogue")
	root.get_node("Dialogue").close()
	current_scene.get_node("Portals/Ice01")._entered(current_scene.player)
	await scene_changed
	await settle()
	check(current_scene.level_index==18,"first ice portal enters 3-1")
	current_scene.spawn_enemies=false
	check(campaign.unfinished_attempt(),"unfinished arena retains checkpoint until completed")
	current_scene.finish()
	await settle()
	current_scene.show_exit_choices()
	check(root.get_node("Dialogue").active,"victory exit offers destination selection")
	root.get_node("Dialogue").select("next_level")
	await scene_changed
	await settle()
	check(current_scene.level_index==19,"exit selection enters next arena")
	current_scene.spawn_enemies=false
	current_scene.finish()
	await settle()
	current_scene.show_exit_choices()
	root.get_node("Dialogue").select("hub")
	await scene_changed
	await settle()
	check(current_scene.scene_file_path=="res://Scence/Chapter3.tscn","arena exit returns to third hub")
	var actor=current_scene.player
	check(current_scene.geometry.floor_cells.has(current_scene.geometry.cell_at(actor.position)),"return lands inside walkable terrain")
	check(actor.position.distance_to(current_scene.get_node("Portals/Ice02").position)<80,"return appears near correct gate")
	check(actor.position.distance_to(current_scene.get_node("Portals/Ice02").position)>20,"return does not immediately reenter")
	print("Chapter3 transitions: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
