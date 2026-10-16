extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(60)
	for i in range(28,40):
		c.level_state(i).arena={"finished":true}
		c.complete_arena(i)
	c.active_level=0
	c.hub_chapter=5
	var w=load("res://Scence/Chapter5.tscn").instantiate()
	root.add_child(w)
	await physics_frame
	await process_frame
	await process_frame
	w.player.position=Vector2(790,660)
	w.player.get_node("Camera2D").zoom=Vector2(.66,.66)
	await capture("res://.godot/chapter5-hub.png")
	w.queue_free()
	await process_frame
	c.active_level=40
	w=load(c.Catalog.scene_path(40)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	w.player.position=w.geometry.nearest(w.get_node("ArenaCenter").position+Vector2(-30,70))
	w.player.set_physics_process(false)
	c.profile.reimu_unlocked=true
	c.select_character("reimu")
	w.player.get_node("Camera2D").zoom=Vector2(1.65,1.65)
	for i in 8:
		var e=w.spawn_kind(["kangaroo_red_mini","fatkangaroo_green_mini","mouse_purple_full","naiwa_red_mini","dog_plain_full","hell_boss_1","mouse_green_small","naiwa_purple_full"][i],false,w.player.position+Vector2.from_angle(i*TAU/8)*145)
		e.set_physics_process(false)
		e.emerge_remaining=0
	await capture("res://.godot/chapter5-arena.png")
	c.select_character("miku")
	await capture("res://.godot/chapter5-miku.png")
	w.state.battle_done=true
	w.state.ending_page=0
	w.start_ending()
	await process_frame
	await capture("res://.godot/chapter5-story.png")
	root.get_node("Dialogue").close()
	w.queue_free()
	await process_frame
	var pages: Array=[
		["miku","reimu","omo","omo_spin"],
		["fatkangaroo_green","fatkangaroo_red","mouse_green","mouse_red"],
		["mouse_purple","dog_purple","kangaroo_red","naiwa_green"],
		["dog_green","dog_red","kangaroo_green","kangaroo_purple"],
		["fatkangaroo_purple","naiwa_purple","naiwa_red"]]
	for i in pages.size():
		var gallery=preload("res://Tests/Chapter5/frame_preview.gd").show_page(root,pages[i])
		await capture("res://.godot/chapter5-frames-%d.png"%i)
		gallery.queue_free()
		await process_frame
	quit()
