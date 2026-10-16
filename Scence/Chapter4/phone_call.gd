extends Node
## Mandatory post-rescue call. Audio and retry timer run while the world is paused.
signal completed
var state: Dictionary
var ringtone: AudioStreamPlayer
var speech: AudioStreamPlayer
var retry_timer: Timer
var phase := "waiting"
var old_music_mute := false
var music_bus := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_bus = AudioServer.get_bus_index("Music")
	old_music_mute = AudioServer.is_bus_mute(music_bus)
	AudioServer.set_bus_mute(music_bus, true)
	Story.story_voice.stop()
	for actor in get_tree().get_nodes_in_group("characters"):
		if actor.get("voice") != null: actor.voice.stop()
	ringtone = AudioStreamPlayer.new()
	ringtone.bus = &"Voice"
	ringtone.stream = preload("res://Audio/菲比/菲比电话铃声.mp3").duplicate()
	ringtone.stream.loop = false
	ringtone.volume_db = float(preload("res://Audio/character_voice.gd").clip_gains.get("res://Audio/菲比/菲比电话铃声.mp3", 0.0))
	add_child(ringtone)
	ringtone.finished.connect(_missed)
	speech = AudioStreamPlayer.new()
	speech.bus = &"Voice"
	add_child(speech)
	retry_timer = Timer.new()
	retry_timer.one_shot = true
	retry_timer.wait_time = 1.0
	add_child(retry_timer)
	retry_timer.timeout.connect(_ring)
	begin.call_deferred()

func begin() -> void:
	if not Dialogue.open("来电 · 菲比", ["菲比正在呼叫……"], [], self, _choose, _closed, false):
		return
	if state.get("phone_answered", false): _answer()
	else: _ring()

func _process(_delta: float) -> void:
	# A resumed scene may still be closing another modal on the first frame.
	if phase == "waiting" and not Dialogue.active and not get_tree().paused: begin()

func _ring() -> void:
	if phase in ["answered", "complete"]: return
	phase = "ringing"
	Dialogue.show_page("来电 · 菲比", "睦子米已经获救。\n菲比正在给你打电话……", [{"id":"answer", "text":"接听电话"}], _portrait())
	ringtone.play()

func _missed() -> void:
	if phase != "ringing": return
	ringtone.stop()
	phase = "missed"
	state.phone_missed_calls = int(state.get("phone_missed_calls", 0)) + 1
	Dialogue.show_page("未接来电 · 菲比", "无人接听，电话已自动挂断。\n菲比正在重新拨打……", [], _portrait())
	retry_timer.start()

func _answer() -> void:
	phase = "answered"
	retry_timer.stop()
	ringtone.stop()
	state.phone_answered = true
	Campaign.save_progress()
	Dialogue.show_page("通话中 · 菲比", "你已经有睦子米陪你了，对吧？我们四个有点生气，决定一起离开一阵子。什么时候回来……还没想好。坤坤，接下来交给你了。", [{"id":"sorry", "text":"等你们回来，我会认真解释"}, {"id":"respect", "text":"我尊重你们，路上注意安全"}], _portrait())
	speech.stream = preload("res://Audio/菲比/菲比生气.mp3")
	speech.volume_db = float(preload("res://Audio/character_voice.gd").clip_gains.get(speech.stream.resource_path, 0.0))
	speech.play()

func _choose(id: String) -> void:
	if id == "answer" and phase == "ringing":
		_answer()
	elif phase == "answered" and id in ["sorry", "respect"]:
		state.phone_response = id
		phase = "complete"
		Dialogue.close()

func _portrait() -> Texture2D:
	var frames: SpriteFrames = Campaign.character_definition("phoebe").animations
	return frames.get_frame_texture(&"idle" if frames.has_animation(&"idle") else &"down", 0)

func _closed() -> void:
	if phase != "complete": return
	state.cinematic_seen = true
	if "28:outro" not in Story.progress().seen: Story.progress().seen.append("28:outro")
	Campaign.save_progress()
	completed.emit()
	queue_free()

func _exit_tree() -> void:
	phase = "complete"
	if is_instance_valid(ringtone): ringtone.stop()
	if is_instance_valid(speech): speech.stop()
	if is_instance_valid(retry_timer): retry_timer.stop()
	# Scene changes and interrupted calls must not leave the global game paused/muted.
	if is_instance_valid(Dialogue) and Dialogue.active and Dialogue.source == self:
		Dialogue.on_closed = Callable()
		Dialogue.close()
	if music_bus >= 0: AudioServer.set_bus_mute(music_bus, old_music_mute)
