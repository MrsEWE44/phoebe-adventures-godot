extends SceneTree
func _initialize() -> void: call_deferred("run")
func preview_forms() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1280,720)
	backdrop.color = Color("52737d")
	layer.add_child(backdrop)
	var captions := ["眼镜形态 · 正面", "奶龙形态 · 向左", "奶龙形态 · 向右"]
	for i in 3:
		var sprite := Sprite2D.new()
		var frames: SpriteFrames = load("res://Art/Chapter4/anon_glasses.tres" if i==0 else "res://Art/Chapter4/anon_dragon.tres")
		sprite.texture = frames.get_frame_texture(&"idle" if i==0 else &"left",0)
		sprite.position = Vector2(220+i*410,350)
		sprite.scale = Vector2(.85,.85)
		sprite.flip_h = i==2
		layer.add_child(sprite)
		var label := Label.new()
		label.text = captions[i]
		label.position = Vector2(115+i*410,570)
		label.add_theme_font_size_override("font_size",24)
		layer.add_child(label)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-anon-forms.png")
	layer.queue_free()
	await process_frame
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(40)
	c.hub_chapter=4
	c.ensure_character_allowed()
	await preview_forms()
	var world=load("res://Scence/Chapter4.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.player.get_node("Camera2D").zoom=Vector2(.74,.74)
	world.player.position=Vector2(836,470)
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-hub-preview.png")
	world.queue_free()
	await process_frame
	c.active_level=28
	world=load("res://Scence/Levels/level_28.tscn").instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	await process_frame
	world.player.position=world.geometry.nearest(world.captive.position+Vector2(0,50))
	world.player.get_node("Camera2D").zoom=Vector2(3,3)
	world.player.get_node("Camera2D").position=world.captive.position-world.player.position-Vector2(0,25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-cage-lock.png")
	world.player.position=world.geometry.nearest(world.get_node("Spawn").position)
	world.player.get_node("Camera2D").position=Vector2.ZERO
	world.player.get_node("Camera2D").zoom=Vector2(2,2)
	world.finish()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-phone-ringing.png")
	world.phone_call._missed()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-phone-missed.png")
	world.phone_call.retry_timer.stop()
	world.phone_call._ring()
	root.get_node("Dialogue").select("answer")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-phone-answered.png")
	root.get_node("Dialogue").select("respect")
	world.queue_free()
	await process_frame
	for i in range(28,37):
		c.level_state(i).arena={"finished":true}
		c.complete_arena(i)
	c.states.erase("37")
	c.active_level=37
	world=load("res://Scence/Levels/level_37.tscn").instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	await process_frame
	c.select_character("soyo")
	world.player.position=world.geometry.nearest(world.get_node("ArenaCenter").position+Vector2(-90,100))
	world.player.get_node("Camera2D").zoom=Vector2(1.3,1.3)
	for i in 3: world.conduct(world.player)
	world.set_process(false)
	preload("res://Scence/Chapter4/final_battle.gd").start_wave(world,3)
	for enemy in world.living(): enemy.set_physics_process(false)
	preload("res://Scence/Chapter4/final_battle.gd").pulse(world)
	c.consume_item("battle_overdrive")
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-finale-preview.png")
	var overlay_layer:=CanvasLayer.new()
	overlay_layer.layer=50
	root.add_child(overlay_layer)
	var map=load("res://UI/map_overlay.gd").new()
	map.world=world
	map.size=Vector2(1280,720)
	overlay_layer.add_child(map)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-route-preview.png")
	map.queue_free()
	await process_frame
	var bag=load("res://UI/inventory.gd").new()
	bag.size=Vector2(1280,720)
	overlay_layer.add_child(bag)
	bag.open()
	bag.select_category(0)
	bag.selected="battle_overdrive"
	bag.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-overdrive-inventory.png")
	bag.select_category(3)
	bag.selected="soyo"
	bag.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-party-preview.png")
	overlay_layer.queue_free()
	await process_frame
	var game_hud: Node
	for child in world.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): game_hud=child
	game_hud.toggle_pause()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-pause-travel.png")
	root.gui_embed_subwindows=true
	game_hud.pause_panel.find_child("TravelScroll",true,false).pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-travel-scroll.png")
	for child in game_hud.get_children():
		if child is AcceptDialog: child.hide();child.queue_free()
	game_hud.toggle_pause()
	world.begin_final_ending()
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-memory-preview.png")
	world.final_ending.movie.video.finished.emit()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/chapter4-ending-preview.png")
	root.get_node("Dialogue").close()
	world.queue_free()
	await process_frame
	quit()
