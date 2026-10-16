extends Node
## Content lives in Data/campaign.json; progress belongs to Campaign's atomic save.
const DATA_PATH="res://Story/Data/campaign.json"
const STEPS=["move","talk","attack","inventory","skill","potion","ultimate","chest"]
const INSTRUCTIONS={"move":"WASD 移动，沿小路走几步", "talk":"听入口向导说明，点击剧情选项", "attack":"离开蓝色安全圈，左键 / J 普通攻击", "inventory":"按 B 打开背包，认识物品分类", "skill":"离开安全圈，右键 / K 释放技能", "potion":"技能消耗能量后，按 R 使用能量药剂", "ultimate":"离开安全圈，按 F 释放角色大招", "chest":"清怪或开门后，靠近宝箱按 E 打开"}
var data: Dictionary={}
var world_ref: WeakRef
var pending: Array[Dictionary]=[]
var running: Dictionary={}
var awaiting_video:=false
var automatic_enabled:=true
var story_voice: Node
var last_voice_character:=""
var last_voice_emotion:=""
var guide_hints: Dictionary={}
var tutorial_origin:=Vector2.ZERO

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	automatic_enabled=not (OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s"))
	data=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	data.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Story/Data/chapter4.json")),true)
	data.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Story/Data/chapter5.json")),true)
	story_voice=preload("res://Audio/character_voice.gd").new()
	add_child(story_voice)
	Dialogue.closed.connect(story_voice.stop)
	Campaign.level_completed.connect(_completed)

func progress() -> Dictionary:
	if not Campaign.profile.get("story") is Dictionary: Campaign.profile.story={}
	var s: Dictionary=Campaign.profile.story
	for key in ["seen","tutorial","npc_intros"]:
		if not s.get(key) is Array: s[key]=[]
	for key in ["choices","visits"]:
		if not s.get(key) is Dictionary: s[key]={}
	return s

func world() -> Node:
	return world_ref.get_ref() if world_ref!=null else null

func entry(index: int) -> Dictionary:
	return data.get(str(index),{})

func enter_world(node: Node2D) -> void:
	if not is_instance_valid(node): return
	if world()==node: return # One automatic greeting per actual scene entry.
	if Dialogue.active and Dialogue.source==self: Dialogue.close()
	world_ref=weakref(node)
	pending.clear()
	running.clear()
	awaiting_video=false
	guide_hints.clear()
	var index: int=node.level_index
	progress().visits[str(index)]=true
	tutorial_origin=node.player.position
	if not node.player.ultimate_started.is_connected(_tutorial_ultimate): node.player.ultimate_started.connect(_tutorial_ultimate)
	if automatic_enabled and index==1 and index not in Campaign.completed and not progress().get("supplies",false):
		progress().supplies=true
		Campaign.profile.health_potions+=2
		Campaign.profile.energy_potions+=3
		Campaign.profile.ultimate_potions+=1
		Campaign.profile_changed.emit()
	if automatic_enabled:
		grant_field_kit(index)
		if index>=38 and (bool(node.state.get("battle_done",false)) or (index==42 and not node.state.get("hell_phone_done",false))):
			pass
		elif index==37 and not str(node.state.get("ending_phase","")).is_empty():
			pass # The resumable memory/epilogue sequence owns this encounter's ending.
		elif index==28 and index in Campaign.completed and not node.state.get("cinematic_seen",false):
			pass # The mandatory rescue phone call owns this ending, including after reload.
		elif index in Campaign.completed:
			# Completion is saved before the dialogue. Resume an unseen ending after reload.
			enqueue(index,"outro")
			awaiting_video=index==27 and "27:outro" not in progress().seen
			if pending.is_empty(): pending.append({"index":index,"phase":"intro","key":str(index)+":intro","brief":true})
		else:
			# Even an old save with a watched narrative gets a visible NPC briefing.
			pending.append({"index":index,"phase":"intro","key":str(index)+":intro","brief":str(index) in progress().npc_intros})
	Campaign.request_save()
	# Present the greeting before the next combat tick; no proximity or E required.
	_process(0)

func grant_field_kit(index: int) -> bool:
	if index not in [1,8] or index in Campaign.completed: return false
	var key:="field_kit_%d"%index
	if progress().get(key,false): return false
	progress()[key]=true
	# Claim flag and equipment share one save. Re-entry and retries cannot farm it.
	var weapon:="bronze_blade" if index==1 else "coral_trident"
	if weapon not in Campaign.profile.weapons: Campaign.grant_drop(weapon,false)
	Campaign.request_save()
	return true

func enqueue(index: int, phase: String) -> void:
	var key:=str(index)+":"+phase
	if key in progress().seen or entry(index).is_empty(): return
	if pending.any(func(p): return p.key==key) or running.get("key","")==key: return
	pending.append({"index":index,"phase":phase,"key":key})

func _completed(index: int) -> void:
	if index in [28,37] or index>=38: return # Chapter four has dedicated phone and final-memory sequences.
	if automatic_enabled and is_instance_valid(world()) and world().level_index==index:
		enqueue(index,"outro")

func request_finale(node: Node) -> void:
	if not automatic_enabled:
		node.add_child(preload("res://Scence/Chapter3/victory_video.gd").new())
		return
	world_ref=weakref(node)
	awaiting_video=true
	enqueue(27,"outro")

func _process(_delta: float) -> void:
	var node:=world()
	if node==null:
		if not running.is_empty() and Dialogue.active and Dialogue.source==self: Dialogue.close()
		pending.clear()
		awaiting_video=false
		return
	if not get_tree().paused and node.level_index==1 and node.player.position.distance_to(tutorial_origin)>12: note_action("move")
	if not automatic_enabled or Dialogue.active or get_tree().paused or node.player.is_dead: return
	if not pending.is_empty():
		var scene: Dictionary=pending.pop_front()
		play_scene(scene.index,scene.phase,bool(scene.get("brief",false)))
	elif awaiting_video and running.is_empty():
		awaiting_video=false
		node.add_child(preload("res://Scence/Chapter3/victory_video.gd").new())

func play_scene(index: int, phase: String, brief:=false) -> bool:
	if Dialogue.active or get_tree().paused or entry(index).is_empty(): return false
	running={"index":index,"phase":phase,"key":str(index)+":"+phase}
	var scene: Dictionary=entry(index)[phase]
	if not Dialogue.open("剧情",[str(scene.text)],[],self,_choose,_scene_closed):
		running.clear()
		return false
	if phase=="intro":
		running.brief=brief
		show_briefing(index,brief)
	else:
		show_beat(str(scene.speaker),str(scene.emotion),str(scene.text),scene.choices)
	return true

func show_briefing(index: int, brief: bool) -> void:
	story_voice.stop()
	for actor in get_tree().get_nodes_in_group("characters"):
		if actor.get("voice")!=null: actor.voice.stop()
	var content: Dictionary=entry(index)
	var text: String=("你回来了，我们接着上次的进度。\n当前任务："+str(content.task)) if brief else str(content.briefing)+"\n\n"+str(content.task)
	if brief and index in Campaign.completed: text="这里的挑战已经完成，奖励和救援进展都已记录。你可以整理补给，从出口返回主图或继续下一关。"
	var options: Array=[{"id":"begin","text":"明白了，继续行动"},{"id":"recap","text":"请从头讲讲这里发生了什么"}] if brief else content.intro.choices
	var frames: SpriteFrames=preload("res://Characters/Definitions/soldier.tres").animations
	var animation: StringName=&"down" if frames.has_animation("down") else frames.get_animation_names()[0]
	Dialogue.show_page(npc_name(index)+" · 剧情引导",text,options,frames.get_frame_texture(animation,0))
	if progress().get("voices",true): Global.play_sfx("potion")

func show_beat(character: String, emotion: String, text: String, options: Array) -> void:
	for actor in get_tree().get_nodes_in_group("characters"):
		if actor.get("voice")!=null: actor.voice.stop()
	var spec: Resource=Campaign.character_definition(character)
	var frames: SpriteFrames=spec.animations
	var animation: StringName=&"down" if frames.has_animation("down") else frames.get_animation_names()[0]
	var icon:=frames.get_frame_texture(animation,0)
	var title: String=str(spec.display_name)+" · "+str({"dialogue":"关切 / 思考","proud":"自信","afraid":"担忧","angry":"生气","victory":"高兴","battle":"认真"}.get(emotion,"回应"))
	Dialogue.show_page(title,text,options,icon)
	play_emotion(character,emotion)

func play_emotion(character: String, emotion: String) -> void:
	last_voice_character=character
	last_voice_emotion=emotion
	story_voice.stop()
	if not bool(progress().get("voices",true)): return
	# Explicit speaker, never the currently selected player. Reuse emotional clips.
	story_voice.profile=Campaign.character_definition(character).voice_profile
	story_voice.cooldowns.clear()
	story_voice.last_event=""
	story_voice.elapsed=100
	story_voice.play_event(emotion)

func _choose(id: String) -> void:
	if running.is_empty(): return
	if int(running.index)==1 and running.phase=="intro": note_action("talk")
	if running.get("brief",false):
		if id=="begin": Dialogue.close();return
		if id=="recap":
			running.brief=false
			show_briefing(int(running.index),false)
			return
	if id=="continue":
		if int(running.index)==27 and running.phase=="outro" and not running.get("epilogue",false):
			running.epilogue=true
			Dialogue.show_page("新的篇章",str(entry(27).epilogue),[{"id":"continue","text":"知道了，继续"}])
			story_voice.stop()
		else: Dialogue.close()
		return
	var scene: Dictionary=entry(int(running.index))[str(running.phase)]
	for option in scene.choices:
		if str(option.id)!=id: continue
		progress().choices[running.key]=id
		Campaign.request_save()
		show_beat(str(option.get("speaker","phoebe")),str(option.emotion),str(option.reply),[{"id":"continue","text":"继续 · 更新旅程目标"}])
		return

func _scene_closed() -> void:
	story_voice.stop()
	if running.is_empty(): return
	if running.key not in progress().seen: progress().seen.append(running.key)
	if running.phase=="intro" and str(running.index) not in progress().npc_intros: progress().npc_intros.append(str(running.index))
	Campaign.save_progress()
	running.clear()

func note_action(action: String) -> void:
	if Campaign.active_level!=1 or 1 in Campaign.completed or action not in STEPS: return
	if action in progress().tutorial: return
	progress().tutorial.append(action)
	Campaign.request_save()
	Campaign.message.emit("练习完成："+str(INSTRUCTIONS[action])+"。旅程手册 L 可查看下一步。")

func _tutorial_ultimate() -> void:
	note_action("ultimate")

func objective(index: int) -> String:
	if entry(index).is_empty(): return "旅程手册 L · 查看故事与操作提示"
	if index==1 and 1 not in Campaign.completed:
		for step in STEPS:
			if step not in progress().tutorial: return "新手练习 · "+str(INSTRUCTIONS[step])+"（L 手册）"
	return "剧情 · "+str(entry(index).goal)+"（L 手册）"

func open_journal() -> bool:
	if not Dialogue.open("旅程手册",["记录寻找好友的旅程。"],[],self,_journal_choice,story_voice.stop): return false
	journal_home()
	return true

func journal_home() -> void:
	var text:="菲比与糯糯、Doro、咕嘎是朋友；坤坤是途中结识的外来伙伴。Q 币企鹅为第三章临时雇佣兵，由玩家操控，120 金币一场。\n"
	var index:=Campaign.active_level
	if data.has(str(index)): text+="\n当前目标："+str(entry(index).task)
	Dialogue.show_page("旅程手册",text,[{"id":"chapter_1","text":"第一章 · 海岸那头的回声"},{"id":"chapter_2","text":"第二章 · 沉在水下的消息"},{"id":"chapter_3","text":"第三章 · 把朋友带回家"},{"id":"chapter_4","text":"第四章 · 迷失的合奏"},{"id":"chapter_5","text":"第五章 · 余烬中的约定"},{"id":"tutorial","text":"操作练习与快捷键"},{"id":"voice","text":"剧情情绪语音："+("开" if progress().get("voices",true) else "关")}])

func _journal_choice(id: String) -> void:
	if id=="home": journal_home();return
	if id=="voice":
		progress().voices=not bool(progress().get("voices",true))
		story_voice.stop()
		Campaign.save_progress()
		journal_home()
		return
	if id=="tutorial":
		var text:=""
		for step in STEPS: text+=("✓ " if step in progress().tutorial else "○ ")+str(INSTRUCTIONS[step])+"\n"
		text+="V 武器绝招；G 丢弃（专属武器不可丢）；Tab 切换角色；M 地图；L 旅程手册。教学不是通关硬门槛。"
		Dialogue.show_page("操作练习",text,[{"id":"home","text":"返回手册"}]);return
	if id.begins_with("chapter_"):
		var chapter:=int(id.trim_prefix("chapter_"))
		var options: Array=[]
		for i in range(1,Campaign.Catalog.TOTAL_LEVELS+1):
			if Campaign.Catalog.chapter(i)!=chapter: continue
			if str(i) in progress().visits or i in Campaign.completed:
				options.append({"id":"log_"+str(i),"text":Campaign.Catalog.label(i)+" · "+str(entry(i).title)})
		options.append({"id":"home","text":"返回手册"})
		Dialogue.show_page("已发现的旅程", "这里只记录已经到达的关卡，尚未探索的故事不会提前揭示。",options);return
	if id.begins_with("log_"):
		var index:=int(id.trim_prefix("log_"))
		var text:=str(entry(index).clue)+"\n\n目标："+str(entry(index).task)
		if index in Campaign.completed: text+="\n\n"+str(entry(index).outro.text)
		if index==27 and 27 in Campaign.completed: text+="\n\n"+str(entry(27).epilogue)
		var options: Array=[{"id":"replay_"+str(index)+"_intro","text":"重看入场剧情"}]
		if index in Campaign.completed: options.append({"id":"replay_"+str(index)+"_outro","text":"重看结局剧情"})
		options.append({"id":"home","text":"返回手册"})
		Dialogue.show_page(str(entry(index).title),text,options);return
	if id.begins_with("replay_"):
		var parts:=id.split("_")
		Dialogue.close()
		play_scene(int(parts[1]),parts[2])

func npc_name(index: int) -> String:
	return str(entry(index).get("npc","旅程向导"))

func hint(index: int) -> String:
	var node:=world()
	if node==null or node.level_index!=index: return str(entry(index).get("task","先整理背包，再探索下一道门。"))
	for mechanism in node.switches:
		if mechanism.activated: continue
		var hints: Array=mechanism.puzzle.get("hints",[mechanism.puzzle.get("clue","观察机关")])
		var key:=str(index)+str(mechanism.config.id)
		var step:=mini(int(guide_hints.get(key,0)),hints.size()-1)
		guide_hints[key]=step+1
		return str(mechanism.config.label)+" · 提示 %d/%d\n"%[step+1,hints.size()]+str(hints[step])+"\n再次询问可获得更明确的提示。"
	return node.adventure.hint_text() if node.adventure!=null else str(entry(index).task)
