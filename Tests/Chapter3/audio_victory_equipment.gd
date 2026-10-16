extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=2) -> void:
	for i in n: await process_frame
func run() -> void:
	var campaign=root.get_node("Campaign")
	var global=root.get_node("Global")
	campaign.saving_enabled=false
	campaign.reset_state()
	var world=load("res://Scence/Levels/level_27.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	var actors: Array=[]
	for family in ["naiwa","penguin"]:
		var profile=load("res://Characters/Voices/"+family+".tres")
		for stage in ["minion","mini","full"]:
			var enemy=world.spawn_kind(family+"_"+stage,false)
			enemy.set_physics_process(false)
			actors.append(enemy)
			check(enemy.voice.profile==profile and enemy.voice.player.bus==&"EnemyVoice","shared full voice profile and enemy bus: "+family+stage)
			check(profile.max_duration==0 and not profile.ultimate.is_empty() and not profile.death.is_empty(),"all stages retain full voice events: "+family+stage)
	check(world.player.voice.player.bus==&"Voice" and world.captive.voice.player.bus==&"Voice","player and neutral captive stay on character bus")
	var voice_level: float=global.audio_levels.Voice
	var music_level: float=global.audio_levels.Music
	global.set_audio_level("EnemyVoice",-50)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("EnemyVoice")) and global.audio_levels.Voice==voice_level and global.audio_levels.Music==music_level,"enemy mute independent of character and music volume")
	global.set_audio_level("EnemyVoice",-17)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("EnemyVoice")) and global.settings.get_value("audio","EnemyVoice")==-17,"enemy slider unmutes and updates persistent settings")
	var hud: Node
	for child in world.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	hud.toggle_pause()
	var slider=hud.pause_panel.find_child("EnemyVoiceVolume",true,false)
	check(slider!=null,"pause menu provides enemy volume slider")
	slider.value=-23
	check(global.audio_levels.EnemyVoice==-23,"slider changes enemy bus")
	hud.toggle_pause()
	campaign.profile.gugu_unlocked=true
	campaign.profile.weapons.append("penguin_rock")
	campaign.select_character("gugu")
	hud.inventory_panel.select_category(2)
	check(hud.inventory_panel.build_entries().filter(func(e): return e.name.begins_with("凑企鹅原石")).size()==1,"inventory shows a single fixed stone entry")
	for index in [0,1,8,18,27]:
		campaign.active_level=index
		campaign.profile.equipped="pili_blade"
		campaign.profile_changed.emit()
		check(campaign.effective_weapon()=="penguin_rock" and world.player.normal_weapon.weapon_id=="penguin_rock" and not campaign.can_equip_weapon("pili_blade"),"Gugu stone-only in map "+str(index))
	check(not world.player.drop_weapon() and not campaign.destroy_weapon("penguin_rock"),"stone cannot be discarded or destroyed")
	campaign.profile.equipped="fists"
	campaign.profile_changed.emit()
	check(campaign.effective_weapon()=="penguin_rock","default weapon resolves to stone rather than fists or wings")
	check(load("res://Weapons/Definitions/pili_blade.gd").new().weapon_name=="屠龙刀","weapon renamed while retaining save ID")
	campaign.active_level=27
	world.state.boss_started=true
	world.ensure_final_bosses()
	for enemy in world.living(): enemy.take_damage(1000000,"true")
	await frames()
	var popup=get_nodes_in_group("victory_video")[0]
	check(world.state.finished and popup.video==null and popup.prompt.visible and paused,"victory prompts first without autoplay")
	check(campaign.profile.gugu_unlocked and "penguin_rock" in campaign.profile.weapons,"rewards granted before video choice")
	popup.prompt.find_child("SkipVideo",true,false).pressed.emit()
	await frames()
	check(not paused and get_nodes_in_group("victory_video").is_empty(),"decline resumes game")
	AudioServer.set_bus_mute(0,false)
	var game_buses: Array=["Music","Voice","EnemyVoice","Effects"]
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Voice"),true)
	var original_mutes: Dictionary={}
	for bus in game_buses: original_mutes[bus]=AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))
	var video_bus:=AudioServer.get_bus_index("Video")
	var audio_capture:=AudioEffectCapture.new()
	audio_capture.buffer_length=3.0
	var effect_index:=AudioServer.get_bus_effect_count(video_bus)
	AudioServer.add_bus_effect(video_bus,audio_capture)
	popup=load("res://Scence/Chapter3/victory_video.gd").new()
	world.add_child(popup)
	popup.prompt.find_child("PlayVideo",true,false).pressed.emit()
	check(popup.video.is_playing() and not AudioServer.is_bus_mute(0) and popup.video.bus==&"Video" and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Video")) and paused,"video plays on an audible dedicated bus")
	check(game_buses.all(func(bus): return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))),"all gameplay buses muted without muting video")
	await create_timer(1.5).timeout
	var samples:=audio_capture.get_buffer(audio_capture.get_frames_available())
	var peak:=0.0
	for sample in samples: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	check(peak>.00001,"video soundtrack produces actual nonzero audio samples")
	AudioServer.remove_bus_effect(video_bus,effect_index)
	popup.video.finished.emit()
	await frames()
	check(not AudioServer.is_bus_mute(0) and not paused and global.audio_levels.EnemyVoice==-23,"natural end restores audio and pause state without changing settings")
	check(game_buses.all(func(bus): return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))==original_mutes[bus]),"natural end restores mixed muted/unmuted gameplay states")
	AudioServer.set_bus_mute(0,true)
	popup=load("res://Scence/Chapter3/victory_video.gd").new()
	world.add_child(popup)
	popup.play_video()
	popup.close()
	await frames()
	check(AudioServer.is_bus_mute(0) and not paused,"skip preserves originally muted master")
	check(game_buses.all(func(bus): return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))==original_mutes[bus]),"skip restores each gameplay bus")
	AudioServer.set_bus_mute(0,false)
	popup=load("res://Scence/Chapter3/victory_video.gd").new()
	world.add_child(popup)
	popup.play_video()
	popup.queue_free()
	await frames()
	check(not AudioServer.is_bus_mute(0) and not paused,"scene cleanup restores audio without leaving game muted")
	check(game_buses.all(func(bus): return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))==original_mutes[bus]),"scene cleanup restores each gameplay bus")
	world.queue_free()
	await frames()
	print("Audio / victory / fixed equipment: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
