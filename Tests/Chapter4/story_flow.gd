extends SceneTree
var count:=0
var failed:=0
func ck(value: bool, text: String) -> void:
	count+=1
	if not value: failed+=1;push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	var story=root.get_node("Story")
	var dialogue=root.get_node("Dialogue")
	c.saving_enabled=false
	c.reset_state(40)
	c.hub_chapter=4
	c.ensure_character_allowed()
	story.automatic_enabled=true
	for i in range(28,38):
		c.active_level=i
		var world=load(c.Catalog.scene_path(i)).instantiate()
		world.spawn_enemies=false
		root.add_child(world)
		await process_frame
		await process_frame
		ck(dialogue.active and paused,"automatic paused briefing "+str(i))
		ck(story.running.get("index",0)==i,"correct story index")
		story._choose("plan")
		ck(story.last_voice_character=="ikun","choice voice belongs to speaker")
		story._choose("continue")
		ck(not dialogue.active and not paused,"story releases input")
		ck(get_nodes_in_group("story_guides").filter(func(n):return n.get_parent()==world).size()==4,"four distinct services")
		story.play_scene(i,"outro")
		ck(dialogue.active,"outro opens")
		story._choose("continue_story")
		story._choose("continue")
		ck(not dialogue.active,"outro closes")
		world.queue_free()
		await process_frame
	story.automatic_enabled=false
	c.active_level=28
	var world=load(c.Catalog.scene_path(28)).instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.state.finished=true
	world.present_cinematic()
	await process_frame
	ck(dialogue.active and world.phone_call.ringtone.playing,"Phoebe phone rings")
	dialogue.select("answer")
	ck(not world.phone_call.ringtone.playing and world.phone_call.speech.playing,"answer stops ringtone and plays Phoebe")
	dialogue.on_choice.call("sorry")
	ck(not dialogue.active and world.state.cinematic_seen,"phone acknowledged and saved")
	world.queue_free()
	await process_frame
	# Video keeps its own audio bus, mutes only gameplay, and restores original states.
	for movie in ["chapter4_reveal","chapter4_impostor","chapter4_victory"]:
		var video=load("res://Scence/Chapter3/victory_video.gd").new()
		video.stream_path="res://Videos/"+movie+".ogv"
		root.add_child(video)
		video.play_video()
		ck(video.video.stream!=null and video.video.bus==&"Video","video stream and original audio "+movie)
		ck(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"game music muted during video")
		ck(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Video")),"video audio remains audible")
		video.close()
		await process_frame
		ck(not paused and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"video restores pause and music")
	print("CHAPTER4 STORY: %d checks, %d failures"%[count,failed])
	quit(1 if failed else 0)
