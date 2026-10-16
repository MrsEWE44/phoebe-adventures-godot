extends Node2D
## Save each boundary: memory movie -> dialogue pages -> departure -> victory.
var world: Node2D
var animated_sprite: AnimatedSprite2D
var voice: Node
var departing:=false
var movie: Node
var camera_offset:=Vector2.ZERO
const PAGES=[
	["penguin_full","凑企鹅","afraid","这段旋律……我想起来了。我也曾站在你们身边。真正的主唱，一直是我。可我却把同伴当成了敌人。"],
	["soyo","soyo狸","dialogue","我们想找回的从来不只有乐曲，还有一起唱歌的人。天素罗和大家承受的伤痛，你不能再逃避。"],
	["anon","千早爱音","dialogue","你曾经的歌声没有消失。但道歉不是一首歌的结尾。那些被你伤害的人，还在等你面对他们。"],
	["penguin_full","凑企鹅","terrified","对不起……我毁掉了本该一起完成的舞台。我会记住你们，也记住自己的过错。让我带着这份愧疚，先走一段路吧。"]
]
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	position=world.get_node("ArenaCenter").position
	var camera: Camera2D=world.player.get_node("Camera2D")
	camera_offset=camera.position
	camera.position=position-world.player.position+Vector2(0,65)
	animated_sprite=AnimatedSprite2D.new()
	var spec=Campaign.character_definition("penguin_full")
	animated_sprite.sprite_frames=spec.animations
	animated_sprite.scale=spec.sprite_scale
	animated_sprite.position=spec.sprite_offset
	add_child(animated_sprite)
	animated_sprite.play("idle")
	voice=preload("res://Audio/character_voice.gd").new()
	add_child(voice)
	Story.story_voice.stop()
	for actor in get_tree().get_nodes_in_group("characters"):
		if actor.get("voice")!=null: actor.voice.stop()
		if actor.get_parent()==world and actor.is_dead: actor.queue_free()
	Global.set_boss_music("memory4")
	begin.call_deferred()
func begin() -> void:
	match str(world.state.ending_phase):
		"memory":
			movie=preload("res://Scence/Chapter3/victory_video.gd").new()
			movie.stream_path="res://Videos/chapter4_memory.ogv"
			movie.prompt_title="凑企鹅的记忆"
			movie.completed.connect(_memory_finished.call_deferred)
			add_child(movie)
			movie.play_video.call_deferred()
		"dialogue": show_page()
		"farewell": depart()
func _memory_finished() -> void:
	world.state.ending_phase="dialogue"
	Campaign.save_progress()
	Global.set_boss_music("memory4")
	show_page()
func show_page() -> void:
	var index:=clampi(int(world.state.get("ending_page",0)),0,PAGES.size()-1)
	var page: Array=PAGES[index]
	if not Dialogue.open(str(page[1]),[str(page[3])],[{"id":"epilogue_continue","text":"听他说下去" if index==0 else ("向凑企鹅告别" if index==PAGES.size()-1 else "继续") }],self,_choose,Callable(),false): return
	var spec=Campaign.character_definition(str(page[0]))
	Dialogue.show_page(str(page[1]),str(page[3]),Dialogue.choices,spec.animations.get_frame_texture("idle",0))
	voice.stop()
	voice.profile=spec.voice_profile
	voice.elapsed=99
	voice.cooldowns.clear()
	voice.play_event(str(page[2]))
func _choose(_id: String) -> void:
	Dialogue.close()
	voice.stop()
	world.state.ending_page=int(world.state.get("ending_page",0))+1
	if int(world.state.ending_page)>=PAGES.size():
		world.state.ending_phase="farewell"
		Campaign.save_progress()
		depart()
	else:
		Campaign.save_progress()
		show_page()
func depart() -> void:
	if departing: return
	departing=true
	get_tree().paused=true
	animated_sprite.play("left")
	var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(animated_sprite,"modulate:a",0.0,2.5)
	tween.tween_property(self,"position",position+Vector2(90,0),2.5)
	tween.chain().tween_callback(complete)
func complete() -> void:
	if world.state.get("ending_phase","")=="done": return
	get_tree().paused=false
	hide()
	voice.stop()
	world.player.get_node("Camera2D").position=camera_offset
	world.state.ending_phase="done"
	var seen: Array=Story.progress().seen
	if "37:outro" not in seen: seen.append("37:outro")
	world.finish()
	Campaign.save_progress()
	world.present_cinematic.call_deferred()
	queue_free()
