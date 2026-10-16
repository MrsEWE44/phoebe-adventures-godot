extends SceneTree

var checks := 0
var failures := 0
var spoken: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	var world := Node2D.new()
	root.add_child(world)
	var hero = load("res://Player/Phoebe.tscn").instantiate()
	hero.use_campaign_character = true
	world.add_child(hero)
	hero.set_physics_process(false)
	var voice = hero.voice
	voice.spoken.connect(func(event: String,_slot: int,_text: String): spoken.append(event))
	var files: Dictionary = {}
	for event in ["idle","death","interaction","angry","afraid","terrified","proud","dialogue","hurt","skill","victory","exhausted"]:
		var clips: Array = voice.profile.get(event)
		check(not clips.is_empty(),"configured event "+event)
		for clip: AudioStream in clips:
			check(clip.resource_path.begins_with("res://Audio/菲比/"),"Phoebe uses her own audio "+event)
			check(clip.get_length()>0 and clip.get_length()<2,"valid short decoded clip "+event)
			check(not clip.loop,"voice does not loop "+event)
			files[clip.resource_path] = true
	check(files.size()==14,"all fourteen short voice assets used")
	check(voice.profile.max_duration==0,"real voice clips play in full")
	var expected := {"angry":"菲比生气.mp3","afraid":"菲比害怕.mp3","terrified":"菲比受到惊吓.mp3","proud":"菲八自豪.mp3","death":"菲八不要.mp3","hurt":"菲比挨打伤心.mp3","victory":"菲八成功了.mp3","exhausted":"菲比沮丧.mp3"}
	for event in expected:
		voice.stop()
		voice.elapsed = 1
		check(voice.play_event(event),"plays mapped event "+event)
		check(voice.player.stream in voice.profile.get(event),"correct audio slot "+event)
	voice.stop()
	var previous := ""
	for i in 20:
		voice.elapsed = 1
		check(voice.play_event("interaction"),"random interaction plays")
		var path: String = voice.player.stream.resource_path
		check(path!=previous,"random interaction changes actual file")
		previous = path
	voice.stop()
	voice.elapsed = 1
	voice.cooldowns.clear()
	voice.play_event("angry")
	check(not voice.play_event("skill"),"skill does not interrupt emotion")
	voice.play_event("death")
	check(not voice.play_event("hurt"),"damage does not interrupt death")
	await create_timer(1.6).timeout
	check(not voice.player.playing,"short death voice finishes naturally")
	voice.cooldowns.clear()
	hero.invulnerable = 0
	hero.combat_voice.pending = ""
	hero.combat_voice.next_line = 0
	hero.take_damage(8)
	hero.combat_voice._process(.1)
	check(spoken[-1]=="hurt","nonfatal damage triggers hurt audio")
	var count := spoken.size()
	hero.invulnerable = 0
	hero.take_damage(8)
	check(spoken.size()==count,"repeated damage voice is throttled")
	voice.stop()
	hero.attack_timer = 0
	check(hero.attack(true,false),"skill succeeds")
	check(spoken[-1]=="skill","successful skill triggers audio")
	voice.stop()
	hero.attack_timer = 0
	campaign.profile.energy = 0
	check(not hero.attack(true,false),"empty energy blocks skill")
	check(spoken[-1]=="exhausted","empty energy triggers disappointed response")
	voice.stop()
	for id in load("res://Scence/Levels/catalog.gd").all_door_ids(1):
		campaign.open_door(1,id)
	check(spoken[-1]=="victory","first completion triggers success voice")
	count = spoken.size()
	campaign.check_completion(1)
	check(spoken.size()==count,"completion voice is not replayed by checks")
	voice.stop()
	voice.cooldowns.clear()
	voice.play_event("interaction")
	campaign.profile.nuonuo_unlocked = true
	campaign.switch_character()
	check(not voice.player.playing,"character switch stops outgoing voice")
	check(voice.last_slots.is_empty() and voice.last_event.is_empty(),"character switch resets voice selection")
	world.queue_free()
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("PHOEBE VOICE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
