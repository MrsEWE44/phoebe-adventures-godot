extends Node

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2
var audio_levels := {"Music":-28.0,"Voice":3.0,"EnemyVoice":-5.0,"Effects":-12.0}
var settings := ConfigFile.new()
var settings_path := ""
var boss_track:=""
var boss_player: AudioStreamPlayer
var scene_music:=""
var character_music:=""
var music_character:=""
func set_boss_music(track: String) -> void:
	_sync_character_music()
	if scene_music!=track:
		scene_music=track
		# A newly reached ending starts its own cue; a later character switch may
		# select a personal theme once the round's Omo lock has ended.
		if track.begins_with("victory") or track=="memory4": character_music=""
	_refresh_music()
func _sync_character_music() -> void:
	var campaign:=get_node_or_null("/root/Campaign")
	if campaign==null: return
	var selected: String=str(campaign.profile.get("character",""))
	if selected==music_character: return
	music_character=selected
	character_music={"miku":"sakura","reimu":"badapple"}.get(selected,"")
func _profile_music_changed() -> void:
	_sync_character_music()
	_refresh_music()
func _connect_music_signals() -> void:
	var campaign:=get_node("/root/Campaign")
	campaign.profile_changed.connect(_profile_music_changed)
	_profile_music_changed()
func _refresh_music() -> void:
	var track: String=character_music if not character_music.is_empty() else scene_music
	var campaign:=get_node_or_null("/root/Campaign")
	if campaign!=null and preload("res://Scence/Chapter5/music_rules.gd").omo_locked(campaign): track="omo"
	_play_music(track)
func _play_music(track: String) -> void:
	if boss_track==track: return
	boss_track=track
	if boss_player==null:
		boss_player=AudioStreamPlayer.new()
		boss_player.bus=&"Music"
		add_child(boss_player)
		boss_player.finished.connect(func():
			if not boss_track.is_empty(): boss_player.play())
	boss_player.stop()
	audio_stream_player.stream_paused=not track.is_empty()
	audio_stream_player_2.stream_paused=not track.is_empty()
	if not track.is_empty():
		var music_path: String={"sakura":"res://BGM/千本樱.mp3","badapple":"res://BGM/badapple.mp3","omo":"res://BGM/你看到的我.mp3","penguin":"res://BGM/第三关最终BOSS战背景音乐.mp3","naiwa":"res://BGM/奶娃BOSS战背景音乐.mp3","victory3":"res://BGM/第三关最终BOSS战通关背景音乐.mp3","victory4":"res://BGM/第四关最终BOSS战通关背景音乐.mp3","memory4":"res://BGM/第四关最终BOSS被击败时的背景音乐.mp3"}.get(track,"res://BGM/奶娃BOSS战背景音乐.mp3")
		boss_player.stream=load(music_path).duplicate()
		if boss_player.stream is AudioStreamMP3: boss_player.stream.loop=true
		boss_player.volume_db=0 if track.begins_with("victory") or track in ["memory4","sakura","badapple","omo"] else 20
		boss_player.play()
func play_sfx(kind: String) -> void:
	preload("res://Audio/game_sfx.gd").play(self,kind)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_music_signals.call_deferred()
	settings_path=Storage.settings_file()
	if not Storage.script_run() and settings.load(settings_path)==OK:
		for bus in audio_levels:
			audio_levels[bus] = clampf(float(settings.get_value("audio",bus,audio_levels[bus])),-50,6)
	for bus in audio_levels:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),audio_levels[bus])
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),audio_levels[bus]<=-50)

func set_audio_level(bus: String, value: float) -> void:
	if not audio_levels.has(bus):
		return
	audio_levels[bus] = clampf(value,-50,6)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),audio_levels[bus])
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),audio_levels[bus]<=-50)
	settings.set_value("audio",bus,audio_levels[bus])
	if not Storage.script_run():
		var error:=settings.save(settings_path)
		if error!=OK: push_error("无法保存音量设置："+settings_path+"（"+error_string(error)+"）")

func _exit_tree() -> void:
	audio_stream_player.stop()
	audio_stream_player_2.stop()


func _on_audio_stream_player_2_finished() -> void:
	audio_stream_player.play()


func _on_audio_stream_player_finished() -> void:
	audio_stream_player_2.play()
