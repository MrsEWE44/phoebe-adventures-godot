extends SceneTree
var checks := 0
var failures := 0
func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	var c = root.get_node("Campaign")
	var story = root.get_node("Story")
	var dialogue = root.get_node("Dialogue")
	c.saving_enabled = false
	c.reset_state(40)
	c.hub_chapter = 4
	c.active_level = 28
	story.automatic_enabled = true
	var world = load(c.Catalog.scene_path(28)).instantiate()
	world.spawn_enemies = false
	root.add_child(world)
	await frames()
	dialogue.close()
	world.set_process(false)
	var music := AudioServer.get_bus_index("Music")
	var voice := AudioServer.get_bus_index("Voice")
	AudioServer.set_bus_mute(music, false)
	world.finish()
	await frames()
	var call = world.phone_call
	ck(call != null and dialogue.active and paused, "victory opens mandatory paused call immediately")
	ck(story.pending.is_empty() and story.running.is_empty(), "no competing rescue outro")
	ck(AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(voice), "music silent and voice audible")
	ck(call.ringtone.playing and not call.ringtone.stream.loop, "ringtone plays once per call")
	ck(dialogue.choices.size() == 1 and dialogue.choices[0].id == "answer", "explicit answer choice")
	dialogue.select("close")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	dialogue._input(escape)
	ck(dialogue.active and call.phase == "ringing", "Esc and close cannot skip unanswered call")
	# Use an actual short stream to exercise AudioStreamPlayer.finished, not a manual callback.
	var short_ring := AudioStreamWAV.new()
	short_ring.mix_rate = 22050
	short_ring.format = AudioStreamWAV.FORMAT_16_BITS
	var short_samples := PackedByteArray()
	short_samples.resize(4410)
	short_ring.data = short_samples
	call.retry_timer.wait_time = .12
	call.ringtone.stream = short_ring
	call.ringtone.play()
	await create_timer(.3).timeout
	ck(int(world.state.get("phone_missed_calls",0)) >= 1, "natural ringtone end records missed call")
	ck(not world.state.get("cinematic_seen",false) and paused, "missed call never completes story")
	await create_timer(.45).timeout
	ck(int(world.state.phone_missed_calls) >= 2, "unanswered call repeatedly redials")
	call.retry_timer.stop()
	call._ring()
	dialogue.select("answer")
	ck(call.phase == "answered" and not call.ringtone.playing and call.retry_timer.is_stopped(), "answer cancels ring and retries")
	ck(call.speech.playing and call.speech.stream.resource_path.ends_with("菲比生气.mp3"), "answer plays Phoebe supplied voice immediately")
	ck(world.state.phone_answered and not world.state.get("cinematic_seen",false), "answered and completed are distinct states")
	var missed: int = world.state.phone_missed_calls
	await create_timer(.25).timeout
	ck(world.state.phone_missed_calls == missed and call.phase == "answered", "stale retry cannot interrupt conversation")
	c.save_path = "res://.godot/chapter4-phone-save.json"
	c.saving_enabled = true
	ck(c.save_progress(), "save answered conversation")
	world.queue_free()
	await frames()
	ck(not paused and not AudioServer.is_bus_mute(music), "scene teardown restores audio and input")
	ck(c.load_progress(), "reload phone checkpoint")
	story.automatic_enabled = true
	world = load(c.Catalog.scene_path(28)).instantiate()
	world.spawn_enemies = false
	root.add_child(world)
	await frames()
	call = world.phone_call
	ck(call.phase == "answered" and call.speech.playing and not call.ringtone.playing, "answered reload resumes Phoebe without ringing again")
	dialogue.select("respect")
	await frames()
	ck(world.state.cinematic_seen and "28:outro" in story.progress().seen, "response persists completed call")
	ck(not dialogue.active and not paused and not AudioServer.is_bus_mute(music), "normal completion restores music and gameplay")
	c.saving_enabled = false
	world.queue_free()
	await frames()
	# Preserve an existing music mute rather than forcibly enabling it on completion.
	AudioServer.set_bus_mute(music, true)
	call = load("res://Scence/Chapter4/phone_call.gd").new()
	call.state = {"phone_answered":false}
	root.add_child(call)
	await frames()
	dialogue.select("answer")
	dialogue.select("sorry")
	await frames()
	ck(AudioServer.is_bus_mute(music), "original music mute preserved")
	AudioServer.set_bus_mute(music, false)
	var penguin = load("res://Characters/Voices/penguin.tres")
	ck(penguin.hurt[0].resource_path.ends_with("凑企鹅受伤声音.mp3"), "new penguin hurt recording selected")
	ck(penguin.death[0].resource_path.ends_with("凑企鹅被击败声音.mp3"), "new penguin defeat recording selected")
	ck(penguin.proud[0].resource_path.ends_with("凑企鹅嘲笑.mp3"), "new penguin laugh used for proud state")
	ck(penguin.ultimate[0].resource_path.contains("非常生气"), "strong anger reserved for ultimate")
	var shared = load("res://Characters/Voices/tensura.tres")
	for id in ["soyo","soyo_full","tensura_minion","tensura_mini","tensura_full","weiro_minion","weiro_mini","weiro_full"]:
		ck(load("res://Characters/Definitions/"+id+".tres").voice_profile == shared, "shared Tensura voice: "+id)
	for id in ["anon","anon_glasses","anon_dragon"]:
		var profile = load("res://Characters/Definitions/"+id+".tres").voice_profile
		ck(profile.hurt.size() == 2 and profile.hurt[0].resource_path.contains("哭声"), "Anon hurt variants: "+id)
		ck(profile.victory.size() == 2 and profile.victory[0].resource_path.contains("笑声"), "Anon happy variants: "+id)
	for family in ["mutsumi","anon","tensura","penguin"]:
		var profile = load("res://Characters/Voices/"+family+".tres")
		ck(profile.max_duration == 0, "full recordings: "+family)
		for event in ["idle","battle","hurt","death","angry","afraid","terrified","proud","skill","ultimate","victory","exhausted","dialogue"]:
			ck(not profile.get(event).is_empty(), family+" event: "+event)
	var mutsumi = load("res://Characters/Voices/mutsumi.tres")
	ck(mutsumi.idle.size() == 2 and mutsumi.hurt.size() == 2 and mutsumi.dialogue.size() == 2, "Mutsumi random variants")
	ck(c.character_definition("mutsumi").voice_profile == mutsumi, "Mutsumi generated voice wired")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2
	var effect_index := AudioServer.get_bus_effect_count(voice)
	AudioServer.add_bus_effect(voice, capture)
	var generated_voice = load("res://Audio/character_voice.gd").new()
	generated_voice.profile = mutsumi
	root.add_child(generated_voice)
	ck(generated_voice.play_event("battle"), "generated female voice starts")
	await create_timer(.8).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()): peak = maxf(peak, maxf(absf(sample.x),absf(sample.y)))
	ck(peak > .0001, "generated voice produces actual audio samples")
	AudioServer.remove_bus_effect(voice, effect_index)
	generated_voice.queue_free()
	story.automatic_enabled = false
	c.active_level = 33
	world = load(c.Catalog.scene_path(33)).instantiate()
	world.spawn_enemies = false
	root.add_child(world)
	await frames()
	world.set_process(false)
	var enemy = world.spawn_kind("weiro_full")
	enemy.set_physics_process(false)
	enemy.voice.stop()
	enemy.voice.last_event = ""
	enemy.execute("music_summon")
	ck(enemy.voice.last_event == "ultimate", "Weiro summon triggers shared ultimate voice")
	enemy.voice.stop()
	enemy.voice.last_event = ""
	enemy.voice.cooldowns.clear()
	enemy.target_point = enemy.position+Vector2.RIGHT*100
	enemy.execute("leap")
	ck(enemy.voice.last_event == "skill", "Tensura family leap triggers skill voice")
	enemy.take_damage(enemy.max_health*10,"true")
	ck(enemy.voice.last_event == "death" and enemy.voice.player.playing, "enemy plays full death recording")
	enemy._physics_process(2.0)
	ck(not enemy.is_queued_for_deletion(), "death animation timeout does not cut off voice")
	enemy.voice.stop()
	enemy._physics_process(.01)
	ck(enemy.is_queued_for_deletion(), "dead enemy cleans up after voice")
	world.queue_free()
	await frames()
	print("CHAPTER4 PHONE/AUDIO: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
