extends Node
signal completed
var world: Node2D
var movie: Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	begin.call_deferred()
func begin() -> void:
	if world.state.get("ending_dialogue_done",false) and not world.state.get("ending_video",false): commit();return
	if world.state.get("ending_video",false): show_movie();return
	if not Dialogue.open("余烬中的约定",[""],[],self,choose,closed,false): return
	show_page()
func pages() -> Array:
	return Story.entry(world.level_index).ending
func show_page() -> void:
	var index: int=clampi(int(world.state.get("ending_page",0)),0,pages().size()-1)
	var page: Dictionary=pages()[index]
	var options: Array=page.get("choices",[{"id":"continue","text":"继续"}])
	if world.level_index==46 and index==pages().size()-1 and not str(Campaign.profile.hell.omo_choice).is_empty(): options=[{"id":"continue","text":"决定已经记录，继续"}]
	Story.show_beat(page.speaker,page.emotion,page.text,options)
func choose(id: String) -> void:
	world.state.ending_choice=id
	if id in ["hug","tease"]:
		Campaign.save_progress()
		Story.show_beat("phoebe","victory" if id=="hug" else "angry", "哼……这次就原谅你啦。再抱紧一点，不许再把我们弄丢。" if id=="hug" else "才、才没有哭！刚才只是地狱里的灰进眼睛了……你要是敢告诉别人，我就一直跟着你！",[{"id":"continue","text":"一起回家"}])
		return
	if id in ["give","keep"]:
		if not Campaign.choose_omo(id=="give"): return
		Dialogue.show_page("奥摩 · 约定", "胶囊交给我了。我会在下一座牢狱清出一条路，亲自把菲比交还给你们。之后我要回到自己的时空。" if id=="give" else "我尊重你的决定。胶囊的坐标已经刻好，它会在未来把你带到我的时代。现在，我只能祝你们平安。最深处的守卫，你们必须自己面对。",[{"id":"finish","text":"记下约定"}])
		return
	if id=="finish": finish_dialogue();return
	if int(world.state.get("ending_page",0))+1<pages().size():
		world.state.ending_page=int(world.state.get("ending_page",0))+1
		Campaign.save_progress()
		show_page()
	else: finish_dialogue()
func finish_dialogue() -> void:
	world.state.ending_video=world.level_index in [40,47]
	world.state.ending_dialogue_done=true
	Campaign.save_progress()
	Dialogue.close()
	if world.state.ending_video: show_movie()
	else: commit()
func closed() -> void:
	Story.story_voice.stop()
func show_movie() -> void:
	if movie!=null: return
	movie=preload("res://Scence/Chapter3/victory_video.gd").new()
	movie.stream_path="res://Videos/chapter5_badapple.ogv" if world.level_index==40 else "res://Videos/chapter5_phoebe.ogv"
	movie.prompt_title="认识博丽灵梦：是否播放 Bad Apple？" if world.level_index==40 else "菲比的和好礼物"
	movie.completed.connect(commit)
	add_child(movie)
	if world.level_index==47: movie.play_video()
func commit() -> void:
	world.state.ending_video=false
	world.commit_clear()
	completed.emit()
	queue_free()
func _exit_tree() -> void:
	if Dialogue.active and Dialogue.source==self:
		Dialogue.on_closed=Callable()
		Dialogue.close()
	Story.story_voice.stop()
