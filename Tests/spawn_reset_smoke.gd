extends SceneTree
const Catalog=preload("res://Scence/Levels/catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func frames(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame
func clear_of_triggers(actor: CharacterBody2D) -> bool:
	var query:=PhysicsShapeQueryParameters2D.new()
	var collision: CollisionShape2D=actor.get_node("CollisionShape2D")
	query.shape=collision.shape
	query.transform=collision.global_transform
	query.collision_mask=34
	query.collide_with_areas=true
	return actor.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	for index in range(1,18):
		campaign.reset_state()
		campaign.hub_chapter=Catalog.chapter(index)
		for completed in range(1 if index<8 else 8,index+1): campaign.completed.append(completed)
		campaign.return_portal=Catalog.PORTAL_ORDER[index-1]
		change_scene_to_file(Catalog.hub_path(campaign.hub_chapter))
		await scene_changed
		await frames()
		var hub=current_scene
		var actor: CharacterBody2D=hub.get_node("Player" if index>=8 else "菲比")
		var geometry=hub.geometry
		check(actor.is_physics_processing(),"return resumes movement %d"%index)
		check(geometry.floor_cells.has(geometry.cell_at(actor.position)),"return on connected floor %d"%index)
		check(clear_of_triggers(actor),"return outside walls/ocean/portals %d"%index)
		var spawn: Vector2=Vector2(836,610) if index<8 else hub.get_node("Spawn").position
		var path: PackedVector2Array=geometry.path(actor.position,spawn)
		check(path.size()>1,"return path reaches original spawn %d"%index)
		var original:=actor.position
		if path.size()>1:
			check(actor.move_and_collide(path[1]-actor.position)==null,"real movement works after return %d"%index)
		actor.position=original
		for invalid in [Vector2(-500,-500),Vector2(1800,1100),Vector2(10,930)]:
			var safe: Vector2=geometry.safe_spawn(invalid,actor)
			check(safe.is_finite() and geometry.floor_cells.has(geometry.cell_at(safe)),"invalid preferred point repaired %d"%index)
		await frames()
		check(current_scene==hub and campaign.active_level==0,"return does not bounce into a portal %d"%index)
	# Work against an isolated save; real player progress is never reset by tests.
	campaign.save_path="res://.godot/reset_smoke.json"
	campaign.saving_enabled=true
	campaign.profile.coins=321
	campaign.profile.player_level=75
	campaign.profile.experience=123
	campaign.profile.weapon_upgrades={"harpoon":10,"fists":8}
	campaign.profile.armor=true
	campaign.profile.amulet=true
	campaign.profile.diving_armor=true
	campaign.profile.equipment_owned=["swift_boots"]
	campaign.profile.equipment_slots.feet="swift_boots"
	campaign.profile.weapons=["harpoon"]
	campaign.profile.ikun_unlocked=true
	campaign.profile.nuonuo_unlocked=true
	campaign.level_state(8).doors=["door_1"]
	check(campaign.save_progress(),"seed old progress")
	var before_profile: Dictionary=campaign.profile.duplicate(true)
	var before_states: Dictionary=campaign.states.duplicate(true)
	var hud: Node
	for child in current_scene.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	hud.toggle_pause()
	hud.reset_dialog.popup_centered(Vector2i(520,200))
	await frames(1)
	hud.reset_dialog.get_cancel_button().pressed.emit()
	await frames(1)
	check(campaign.profile==before_profile and campaign.states==before_states and paused,"cancel reset preserves save and paused game")
	var sound: Dictionary=root.get_node("Global").audio_levels.duplicate()
	hud.reset_dialog.popup_centered(Vector2i(520,200))
	hud.reset_dialog.get_ok_button().pressed.emit()
	await scene_changed
	await frames()
	check(current_scene.scene_file_path==Catalog.hub_path(1) and not paused,"confirmed reset restarts first hub")
	check(campaign.completed.is_empty() and campaign.states.is_empty() and campaign.active_level==0,"reset clears both chapter progress")
	check(campaign.profile.character=="phoebe" and campaign.profile.health==100 and campaign.profile.energy==200,"reset restores starting character and stats")
	check(campaign.player_level()==1 and campaign.profile.experience==0,"confirmed reset restores level 1 and zero XP")
	check(campaign.player_stats()=={"health":100.0,"attack":20.0,"defense":10.0},"reset restores base health attack and defense")
	check(campaign.player_defense("physical")==10 and campaign.player_defense("magic")==10 and campaign.equipment_bonus("speed_bonus")==0,"reset removes defense and speed bonuses")
	check(campaign.profile.weapon_upgrades.is_empty() and campaign.weapon_multiplier("fists")==1.0 and campaign.profile.equipment_owned.is_empty(),"reset removes weapon upgrades and equipment")
	var fresh_player=current_scene.get_node("菲比")
	check(fresh_player.combat_level==1 and fresh_player.max_health==100 and fresh_player.health==100 and not fresh_player.is_dead,"live player uses level 1 stats immediately")
	check(is_equal_approx(fresh_player.attack_damage(20),20*(fresh_player.definition.home_damage_multiplier if fresh_player.home_buff else 1.0)),"live attack has no old level or weapon growth")
	for id in campaign.CHARACTER_IDS:
		check(campaign.profile.party_health[id]==campaign.character_definition(id).max_health,"party base health restored for "+id)
	check(campaign.profile.weapons.is_empty() and campaign.profile.coins==0 and not campaign.profile.ikun_unlocked and not campaign.profile.nuonuo_unlocked,"reset clears inventory and unlocks")
	check(root.get_node("Global").audio_levels==sound,"reset keeps audio settings")
	var fresh: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(campaign.save_path))
	var backup: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(campaign.save_path+".bak"))
	check(fresh==backup and backup.profile.coins==0,"backup cannot resurrect old progress")
	check(fresh.profile.player_level==1 and backup.profile.experience==0,"primary and backup persist level 1")
	var corrupt=FileAccess.open(campaign.save_path,FileAccess.WRITE)
	corrupt.store_string("invalid save")
	corrupt.close()
	check(campaign.load_progress() and campaign.profile.coins==0 and not campaign.profile.ikun_unlocked,"fallback reload also remains reset")
	check(campaign.player_level()==1 and campaign.player_stats().attack==20 and campaign.player_stats().defense==10,"fallback reload preserves base stats")
	check(not campaign.enter_level(8),"reset level 1 cannot bypass chapter level requirement")
	# Promote the isolated fixture to test the defeat-screen reset in chapter two.
	campaign.profile.player_level=20
	check(campaign.enter_level(8),"qualified fixture enters underwater chapter")
	await scene_changed
	var level=current_scene
	level.player.set_physics_process(false)
	for cell in level.geometry.base_free:
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.is_spawn_safe(point):
			level.player.position=point
			break
	level.player.invulnerable=0
	level.player.take_damage(9999)
	level.player._physics_process(4)
	await frames()
	var death_reset: ConfirmationDialog
	for child in level.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"):
			for node in child.get_children():
				if node is ConfirmationDialog: death_reset=node
	check(death_reset!=null and paused,"death screen offers reset")
	death_reset.popup_centered(Vector2i(520,200))
	death_reset.get_ok_button().pressed.emit()
	await scene_changed
	await frames()
	check(current_scene.scene_file_path==Catalog.hub_path(1) and campaign.profile.health==100 and campaign.states.is_empty(),"reset from death discards unfinished level and restores living player")
	check(campaign.player_level()==1 and campaign.profile.experience==0 and campaign.player_defense("physical")==10,"defeat-screen restart also restores level and defense")
	campaign.profile.coins=77
	campaign.profile.player_level=45
	var good_path: String=campaign.save_path
	campaign.save_path="res://.godot/nonexistent_reset_parent/save.json"
	check(not campaign.restart_campaign() and campaign.profile.coins==77,"failed save does not destroy in-memory progress")
	check(campaign.player_level()==45,"failed reset preserves previous level")
	campaign.save_path=good_path
	campaign.saving_enabled=false
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(good_path+suffix)
	print("Spawn/reset checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
