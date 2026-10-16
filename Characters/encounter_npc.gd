extends "res://Characters/fixed_npc.gd"
var room_id := ""
func interact() -> void:
	if Dialogue.active or level==null: return
	Dialogue.open(display_name,["我刚从门后脱困，包里也许还剩点东西。机关我不擅长，那得请教入口的刻文师。"],[{"id":"gift","text":"友善地问：有什么能帮我的？"},{"id":"rumor","text":"聊聊你在门后见到的事"}],self,_talk)
func _talk(id: String) -> void:
	var rumors: Array[String]=["我听到有人不停重复同一句话，连喘气都一样。后来才想明白，那声音根本没在和我说话。","隔壁的旅人抱着药瓶睡着了。问他为什么不喝，他说，留着就觉得自己还能走出去。","我研究了一整天：门打开之后，至少不用再撞门了。别笑，我刚才真的撞过。"]
	Dialogue.reply(Campaign.claim_encounter_gift(level.level_index,room_id) if id=="gift" else rumors[posmod((str(level.level_index)+room_id).hash(),rumors.size())])
	Story.play_emotion("phoebe","proud" if id=="gift" else "dialogue")
