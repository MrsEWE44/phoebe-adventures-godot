extends "res://Scence/Chapter4/phone_call.gd"
var page:=0
func _ring() -> void:
	if phase in ["answered","complete"]: return
	phase="ringing"
	Dialogue.show_page("地狱深处的来电 · 菲比","通讯器突然响起，信号里夹着锁链拖动的声音。",[{"id":"answer","text":"接听：菲比，是你吗？"}],_portrait())
	ringtone.play()
func _answer() -> void:
	phase="answered"
	retry_timer.stop()
	ringtone.stop()
	state.phone_answered=true
	page=int(state.get("hell_phone_page",0))
	show_call_page()
func show_call_page() -> void:
	var lines: Array=["你终于接电话了！不是说过要等我们吗？我们只是想证明……没有你也能走下去。结果那条路，根本不是出口。","别笑我。我把大家带错了地方。他们把Doro、咕嘎、糯糯分开关起来，说只要我留下，就不再追她们。我现在听不见她们的声音了。","先去橘色牢笼找Doro，再找咕嘎和糯糯。别直接相信最深处那扇门，它在模仿我们的声音。你会来吗？这次……请把我们一起带回去。"]
	Dialogue.show_page("菲比 · "+("生气" if page==0 else "委屈"),lines[page],[{"id":"listen","text":"我在听，慢慢说"}] if page<2 else [{"id":"promise","text":"会的，我一个也不会落下"},{"id":"comfort","text":"先保护好自己，我们马上来"}],_portrait())
	Story.play_emotion("phoebe","angry" if page==0 else "afraid" if page==1 else "dialogue")
	state.hell_phone_page=page
	Campaign.save_progress()
func _choose(id: String) -> void:
	if id=="answer": _answer()
	elif id=="listen": page+=1;show_call_page()
	elif id in ["promise","comfort"]:
		state.hell_phone_reply=id
		phase="complete"
		Dialogue.close()
func _closed() -> void:
	if phase!="complete": return
	state.hell_phone_done=true
	Campaign.save_progress()
	completed.emit()
	queue_free()
