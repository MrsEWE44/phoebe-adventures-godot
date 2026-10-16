extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func hud(world: Node) -> Node:
	for child in world.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): return child
	return null
func settle() -> void:
	for tick in 3:
		await physics_frame
		await process_frame
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(40)
	ck(not c.travel_scroll_unlocked() and not c.use_travel_scroll(1),"scroll unavailable before chapter four")
	for index in range(28,37):
		c.level_state(index).arena={"finished":true}
		c.complete_arena(index)
	c.active_level=37
	c.hub_chapter=4
	change_scene_to_file(c.Catalog.scene_path(37))
	await scene_changed
	var w=current_scene
	w.spawn_enemies=false
	c.select_character("soyo")
	for i in 3: w.conduct(w.player)
	await settle()
	w.state.wave=4
	var boss=w.spawn_kind("penguin_full",true)
	boss.record.final_conductor=true
	boss.health=boss.max_health*.5
	boss.set_physics_process(false)
	var boss_hp: float=boss.health
	var old_level: int=c.player_level()
	var old_coins: int=c.profile.coins
	var old_weapons: Array=c.profile.weapons.duplicate()
	ck(c.item_count("travel_scroll")==1,"old chapter-four progress grants permanent scroll")
	var menu=hud(w)
	menu.toggle_pause()
	var back=menu.pause_panel.find_child("ReturnToHub",true,false)
	ck(back!=null and not back.disabled,"unfinished 4-10 has usable return button")
	back.pressed.emit()
	await scene_changed
	await settle()
	ck(c.active_level==0 and current_scene.scene_file_path==c.Catalog.hub_path(4),"return actually leaves 4-10")
	ck(not paused and not c.transitioning,"hub input restored")
	ck(c.level_state(37).arena.wave==4 and 37 not in c.completed,"unfinished progress preserved, no false clear")
	ck(c.enter_level(37),"reenter unfinished 4-10")
	await scene_changed
	w=current_scene
	w.spawn_enemies=false
	ck(w.state.wave==4 and w.music_allies.size()==3,"wave and musicians resume")
	var restored=preload("res://Scence/Chapter4/final_battle.gd").boss(w)
	ck(restored!=null and is_equal_approx(restored.health,boss_hp),"boss HP resumes")
	for enemy in w.living(): enemy.set_physics_process(false)
	menu=hud(w)
	menu.toggle_pause()
	menu.pause_panel.find_child("RetryLevel",true,false).pressed.emit()
	await scene_changed
	w=current_scene
	w.spawn_enemies=false
	ck(w.state.wave==0 and w.state.deploy_count==0 and not w.state.get("failed",false),"retry resets encounter and band deployment")
	ck(c.player_level()==old_level and c.profile.coins==old_coins and c.profile.weapons==old_weapons,"retry retains level money equipment")
	ck(c.profile.health==c.player_stats().health and not w.player.is_dead,"retry restores playable character")
	ck(not paused,"retry unpauses")
	# Actual item entry, icon, button and destination selection.
	menu=hud(w)
	menu.toggle_inventory()
	menu.inventory_panel.select_category(0)
	var entries: Array=menu.inventory_panel.build_entries().filter(func(e):return e.id=="travel_scroll")
	ck(entries.size()==1 and entries[0].icon!=null and entries[0].tag.contains("无限"),"inventory shows permanent scroll icon")
	menu.inventory_panel.selected="travel_scroll"
	menu.inventory_panel.activate_selected()
	var picker=menu.inventory_panel.get_children().filter(func(n):return n is AcceptDialog)[0]
	picker.find_child("Chapter1",true,false).pressed.emit()
	await scene_changed
	await settle()
	ck(c.active_level==0 and c.hub_chapter==1,"inventory scroll reaches chapter one")
	for chapter in [2,3,4,1,2,3,4]:
		ck(c.use_travel_scroll(chapter),"repeat scroll travel to %d"%chapter)
		await scene_changed
		await settle()
		ck(current_scene.scene_file_path==c.Catalog.hub_path(chapter) and not paused,"correct stable destination %d"%chapter)
		ck(c.item_count("travel_scroll")==1 and c.profile.coins==old_coins,"scroll is not consumed or charged")
		var player: Node2D=current_scene.player if current_scene.get("player")!=null else current_scene.get_node("菲比")
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=player.get_node("CollisionShape2D").shape
		query.transform=player.global_transform
		query.collision_mask=34
		query.collide_with_areas=true
		query.exclude=[player.get_rid()]
		ck(player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"destination spawn clear of terrain and portals")
	for index in [1,8,18]:
		ck(c.enter_level(index),"enter earlier chapter sublevel")
		await scene_changed
		await settle()
		menu=hud(current_scene)
		menu.toggle_pause()
		menu.pause_panel.find_child("ReturnToHub",true,false).pressed.emit()
		await scene_changed
		await settle()
		ck(c.active_level==0 and c.hub_chapter==c.Catalog.chapter(index),"unfinished earlier chapter returns to own hub")
		ck(not paused and index not in c.completed,"return does not award completion")
	# Unlock survives visiting older maps and reloading an isolated save.
	c.use_travel_scroll(1)
	await scene_changed
	await settle()
	c.save_path="res://.godot/travel-scroll-save.json"
	c.saving_enabled=true
	c.save_progress()
	c.saving_enabled=false
	c.reset_state(1)
	ck(c.load_progress() and c.travel_scroll_unlocked(),"permanent unlock survives old-map reload")
	c.reset_state(1)
	ck(not c.travel_scroll_unlocked(),"full reset removes unlock")
	print("TRAVEL SCROLL / ESCAPE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
