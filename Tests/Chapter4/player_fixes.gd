extends SceneTree
var checks := 0
var failures := 0
func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c = root.get_node("Campaign")
	var dialogue = root.get_node("Dialogue")
	c.saving_enabled = false
	root.get_node("Story").automatic_enabled = false
	c.reset_state(40)
	c.hub_chapter = 4
	c.active_level = 28
	change_scene_to_file(c.Catalog.scene_path(28))
	await scene_changed
	# Press real UI buttons through every exit: callbacks alone miss reserved IDs.
	for index in range(28, 38):
		var world = current_scene
		world.spawn_enemies = false
		world.set_process(false)
		world.state.finished = true
		world.state.cinematic_seen = true
		c.complete_arena(index)
		world.show_exit_choices()
		ck(dialogue.active and paused, "exit dialogue pauses 4-%d" % (index-27))
		var desired := "next_level" if index < 37 else "hub"
		var found := false
		for button in dialogue.choices_box.get_children():
			if button.get_meta("choice_id") == desired:
				found = true
				button.pressed.emit()
				break
		ck(found, "exit button exists %d" % index)
		for tick in 60:
			await process_frame
			if current_scene != null and current_scene != world: break
		ck(current_scene != null and current_scene != world, "real scene transition %d" % index)
		ck(c.active_level == (index+1 if index < 37 else 0), "destination %d" % index)
		ck(not paused and not c.transitioning, "input unlocked after transition %d" % index)
		if failures: quit(1); return
	# Isolated arena with all chapter rewards available.
	c.active_level = 31
	c.states.erase("31")
	change_scene_to_file(c.Catalog.scene_path(31))
	await scene_changed
	var w = current_scene
	w.spawn_enemies = false
	w.set_process(false)
	w.player.set_physics_process(false)
	w.player.position = w.geometry.nearest(w.get_node("ArenaCenter").position)
	ck(c.select_character("anon"), "select Anon")
	for form in ["anon", "anon_glasses", "anon_dragon"]:
		c.profile.music_forms.glasses = form != "anon"
		c.profile.music_forms.dragon = form == "anon_dragon"
		c.profile_changed.emit()
		ck(w.player.definition.character_id == form, "active Anon form refresh: "+form)
	w.player.casting_remaining = 0
	w.player.direction = Vector2.LEFT
	w.player._update_animation()
	var sprite: AnimatedSprite2D = w.player.animated_sprite
	ck(sprite.animation == &"left" and not sprite.flip_h, "dragon moving left is not mirrored")
	ck(sprite.sprite_frames.get_frame_texture(&"left",0).region.position.x < 400, "dragon uses left-facing source column")
	w.player.direction = Vector2.RIGHT
	w.player._update_animation()
	ck(sprite.flip_h, "dragon moving right mirrors left-facing frame")
	for full in [false, true]:
		c.profile.music_forms.soyo_full = full
		c.profile_changed.emit()
		if c.profile.character != "soyo": ck(c.select_character("soyo"), "select Soyo form")
		ck(w.player.definition.character_id == ("soyo_full" if full else "soyo"), "Soyo form applies without switching away")
		var p = w.player
		p.definition = p.definition.duplicate()
		var factor: float = p.definition.damage_multiplier
		ck(is_equal_approx(factor, 2.0 if full else 1.6), "Soyo form multiplier")
		for skill in [false, true]:
			var boosted: float = p.attack_damage(100, skill)
			p.definition.damage_multiplier = 1.0
			var previous: float = p.attack_damage(100, skill)
			p.definition.damage_multiplier = factor
			ck(is_equal_approx(boosted, previous*factor), "Soyo basic/skill damage scales")
	for species in ["penguin_minion", "penguin_mini", "penguin_full"]:
		var e = w.spawn_kind(species, false, w.player.position+Vector2(90,0))
		e.set_physics_process(false)
		e.combat_target = w.player
		e.emerge_remaining = 0
		e.attack_clock = 20
		e.special_clock = 20
		e.speech_clock = 0
		e.voice.stop()
		e.voice.elapsed = 99
		e.voice.cooldowns.clear()
		e._physics_process(.01)
		ck(e.voice.last_event == "taunt" and e.voice.player.playing, species+" combat taunt audible")
		ck(e.voice.player.stream.resource_path.ends_with("凑企鹅嘲笑.mp3"), species+" correct taunt clip")
		ck(e.voice.player.bus == &"EnemyVoice", species+" enemy volume bus")
		ck(not e.voice.play_event("taunt"), species+" taunt cooldown")
		ck(e.voice.play_event("death"), species+" death overrides taunt")
		e.queue_free()
		await process_frame
	var target = w.spawn_kind("naiwa_minion",false,w.player.position+Vector2(90,0))
	target.set_physics_process(false)
	var ally = w.make_ally("penguin_full",w.player.position)
	ally.set_physics_process(false)
	ally.voice.stop()
	ally.voice.elapsed = 99
	ally.voice.cooldowns.clear()
	ally.taunt_clock = 0
	ally.fire_clock = 20
	ally._physics_process(.01)
	ck(ally.voice.last_event == "taunt" and ally.voice.player.playing, "friendly penguin taunts enemies")
	ck(ally.voice.player.bus == &"Voice", "friendly taunt uses party bus")
	for form in ["anon_glasses", "anon_dragon"]:
		var frames: SpriteFrames = load("res://Art/Chapter4/"+form+".tres")
		for animation in [&"idle", &"left", &"up", &"down"]:
			for frame in frames.get_frame_count(animation):
				ck(frames.get_frame_texture(animation,frame).get_size() == Vector2(402,402), "uniform padded frame: "+form)
	var texture: Texture2D = load("res://Art/Chapter4/anon_glasses_transparent.png")
	var pixels := texture.get_image()
	ck(pixels.detect_alpha() != Image.ALPHA_NONE, "glasses texture has transparency")
	ck(pixels.get_pixel(0,0).a == 0, "glasses background corner transparent")
	ck(load("res://Art/Chapter4/anon_glasses.tres").get_frame_texture(&"idle",0).atlas == texture, "glasses animations use transparent texture")
	print("CHAPTER4 PLAYER FIXES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
