extends CanvasLayer
signal completed
@export var stream_path: String="res://Videos/chapter3_victory.ogv"
@export var prompt_title: String="第三章通关！是否播放通关视频？"
var video: VideoStreamPlayer
var prompt: PanelContainer
var shade: ColorRect
var original_paused:=false
var original_game_mutes: Dictionary={}
var audio_muted:=false
var closing:=false
var restored:=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=80
	add_to_group("victory_video")
	original_paused=get_tree().paused
	get_tree().paused=true
	shade=ColorRect.new()
	shade.color=Color(0,0,0,.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	prompt=PanelContainer.new()
	shade.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.position=shade.size*.5-Vector2(245,110)
	prompt.size=Vector2(490,220)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	prompt.add_child(column)
	var title:=Label.new()
	title.text=prompt_title
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",22)
	column.add_child(title)
	var note:=Label.new()
	note.text="奖励已保存。播放视频原声，游戏声音暂时静音。"
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	for entry in [["PlayVideo","播放视频"],["SkipVideo","不播放，继续游戏"]]:
		var button:=Button.new()
		button.name=entry[0]
		button.text=entry[1]
		button.custom_minimum_size.y=42
		button.pressed.connect(play_video if entry[0]=="PlayVideo" else close)
		column.add_child(button)
		if entry[0]=="PlayVideo": button.grab_focus()

func play_video() -> void:
	if video!=null or closing: return
	prompt.hide()
	shade.color=Color.BLACK
	audio_muted=true
	# Mute only gameplay buses; the dedicated video bus still reaches Master.
	for bus in ["Music","Voice","EnemyVoice","Effects"]:
		var index:=AudioServer.get_bus_index(bus)
		if index<0: continue
		original_game_mutes[bus]=AudioServer.is_bus_mute(index)
		AudioServer.set_bus_mute(index,true)
	video=VideoStreamPlayer.new()
	video.bus=&"Video"
	video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video.expand=true
	video.stream=load(stream_path)
	shade.add_child(video)
	video.finished.connect(close)
	var skip:=Button.new()
	skip.name="CloseVideo"
	skip.text="跳过 / 完成（Esc）"
	shade.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position=shade.size-Vector2(200,60)
	skip.size=Vector2(180,42)
	skip.pressed.connect(close)
	skip.grab_focus()
	video.play()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if closing: return
	closing=true
	if video!=null: video.stop()
	_restore()
	completed.emit()
	queue_free()

func _restore() -> void:
	if restored: return
	restored=true
	if audio_muted:
		for bus in original_game_mutes:
			var index:=AudioServer.get_bus_index(bus)
			if index>=0: AudioServer.set_bus_mute(index,original_game_mutes[bus])
		original_game_mutes.clear()
		audio_muted=false
	get_tree().paused=original_paused

func _exit_tree() -> void:
	_restore()
