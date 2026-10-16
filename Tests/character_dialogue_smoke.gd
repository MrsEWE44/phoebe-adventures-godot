extends SceneTree

var checks := 0
var failures := 0
var events: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func run() -> void:
	var campaign = root.get_node("Campaign")
	var dialogue = root.get_node("Dialogue")
	campaign.saving_enabled = false
	campaign.reset_state()
	var level = load("res://Scence/Levels/level_01.tscn").instantiate()
	level.spawn_enemies = false
	root.add_child(level)
	await physics_frame
	await process_frame
	var player = level.player
	player.set_physics_process(false)
	player.voice.spoken.connect(func(event: String,slot: int,text: String): events.append({"event":event,"slot":slot,"text":text}))
	player.note_activity()
	player._update_idle(4.0)
	check(events.is_empty(),"idle voice does not trigger before exceeding four seconds")
	player._update_idle(.01)
	check(events.size()==1 and events[-1].event=="idle","idle crosses four-second threshold")
	player._update_idle(40)
	check(events.size()==1,"no repeated idle voice in same idle session")
	player.voice.stop()
	player.voice.elapsed = 1
	player.note_activity()
	player._update_idle(4.01)
	check(events.size()==2,"activity rearms idle voice")
	player.voice.stop()
	player.note_activity()
	paused = true
	player._update_idle(8)
	check(events.size()==2 and player.idle_elapsed==0,"pause time does not count as idle")
	paused = false
	var previous := -1
	var slots: Dictionary = {}
	for i in 20:
		player.voice.elapsed = 1
		check(player.voice.play_event("interaction"),"interaction clip plays")
		var slot: int = events[-1].slot
		check(slot!=previous,"random interaction avoids immediate repetition")
		previous = slot
		slots[slot] = true
	check(slots.size()>=2,"interaction has multiple audio slots")
	player.voice.stop()
	player.voice.elapsed = 1
	check(not player.has_method("interact_with_character"),"player interaction menu removed")
	for event in ["angry","afraid","terrified","proud"]:
		player.voice.elapsed = 1
		player.voice.stop()
		player.voice.cooldowns.clear()
		player.combat_voice.pending = ""
		player.combat_voice.next_line = 0
		player.combat_voice.request(event)
		player.combat_voice._process(.1)
		check(player.voice.last_event==event,"context emotion: "+event)
		check(not dialogue.active,"emotion does not open dialogue")
	player.voice.stop()
	level.guide.voice.elapsed = 1
	level.guide.interact()
	check(dialogue.active and dialogue.speaker_label.text=="守路人·阿灯","fixed NPC story identity")
	check(not dialogue.choices.any(func(option): return option.id=="mechanisms"),"story guide no longer duplicates scholar service")
	dialogue.close()
	level.get_node("Service_puzzle").interact()
	dialogue.select("mechanisms")
	check(dialogue.content_label.text.contains("提示 1/"),"NPC progressive puzzle instructions")
	dialogue.close()
	level.guide.interact()
	dialogue.select("progress")
	check(dialogue.content_label.text.contains("0 /"),"NPC reads current door state")
	for child in level.get_children():
		if child is CanvasLayer:
			child.toggle_pause()
			check(not child.pause_panel.visible,"pause menu cannot stack on dialogue")
	var close_key := InputEventKey.new()
	close_key.physical_keycode = KEY_ESCAPE
	close_key.pressed = true
	Input.parse_input_event(close_key)
	await process_frame
	check(not dialogue.active and not paused,"Esc closes modal without opening pause menu")
	level.guide.voice.stop()
	player.voice.elapsed = 1
	player.invulnerable = 0
	for cell in level.geometry.reachable_cells(player.position):
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.is_spawn_safe(point): player.position=point;break
	player.take_damage(999,"physical")
	check(player.is_dead and campaign.profile.health==0,"death state")
	check(player.voice.last_event=="death" and player.voice.player.playing,"death voice plays immediately")
	var count := events.size()
	player.take_damage(999,"physical")
	player._update_idle(10)
	check(events.size()==count,"death cannot repeat or trigger idle")
	check(not player.attack(),"dead character cannot attack")
	player.voice.elapsed = 1
	check(not player.voice.play_event("interaction"),"death voice has priority")
	player._physics_process(4)
	check(player.is_dead and paused,"party defeat requires a choice")
	paused = false
	player._respawn()
	await physics_frame
	await process_frame
	await process_frame
	player.voice.stop()
	level.queue_free()
	await process_frame
	var nuonuo = load("res://Player/Nuonuo.tscn").instantiate()
	root.add_child(nuonuo)
	check(nuonuo.current_character=="nuonuo","inherited Nuonuo scene works independently")
	check(nuonuo.has_method("note_activity") and nuonuo.has_method("attack"),"both heroes inherit common movement and combat")
	check(nuonuo.animated_sprite.sprite_frames.get_frame_count("up")==4,"Nuonuo directional animation")
	nuonuo.queue_free()
	await process_frame
	campaign.reset_state()
	var final_level = load("res://Scence/Levels/level_06.tscn").instantiate()
	final_level.spawn_enemies = false
	root.add_child(final_level)
	await process_frame
	final_level.npc.interact()
	check(dialogue.active and dialogue.speaker_label.text=="糯糯","rescue NPC has dialogue")
	dialogue.select("rescue")
	check(not campaign.profile.nuonuo_unlocked,"dialogue cannot bypass sealed doors")
	dialogue.close()
	for mechanism in final_level.switches:
		preload("res://Tests/puzzle_helper.gd").solve(mechanism)
	await preload("res://Tests/puzzle_helper.gd").open_until_final(final_level)
	final_level.npc.voice.elapsed = 1
	final_level.npc.interact()
	dialogue.select("rescue")
	check(campaign.profile.nuonuo_unlocked and 6 in campaign.completed,"rescue choice unlocks character after all doors")
	check(is_instance_valid(final_level.npc),"NPC remains for final thank-you dialogue")
	dialogue.close()
	await process_frame
	check(not is_instance_valid(final_level.npc),"rescued NPC leaves after dialogue finishes")
	final_level.queue_free()
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("CHARACTER / DIALOGUE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
