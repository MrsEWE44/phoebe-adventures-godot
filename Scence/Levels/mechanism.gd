extends Node2D

@export var config: Dictionary = {}
var level: Node2D
var kind := "lever"
var activated := false
var turns := 0
var time := 0.0
var openness := 0.0
var collision: CollisionShape2D
var label: Label
var puzzle: Dictionary = {}
var charge_elapsed := 0.0
var sequence_index := 0
var circuit: Array = []
var valves: Array = [0,0,0]
var mistakes := 0
var cooldown_until := 0.0
var hint_step:=0

func _ready() -> void:
	level = get_parent().get_parent()
	kind = str(config.get("type", "lever"))
	var data := preload("res://Scence/Levels/catalog.gd").load_level(level.level_index)
	puzzle = data.get("adventure",{}).get("puzzles",{}).get(str(config.id),{})
	var progress: Dictionary = Campaign.level_state(level.level_index).get("puzzles",{}).get(str(config.id),{})
	turns = int(progress.get("turns",0))
	sequence_index = int(progress.get("sequence",0))
	circuit = progress.get("circuit",puzzle.get("initial",[0,0,0,0])).duplicate()
	valves = progress.get("valves",[0,0,0]).duplicate()
	mistakes = int(progress.get("mistakes",0))
	hint_step=int(progress.get("hint_step",0))
	label = Label.new()
	label.text = str(config.get("label", "机关"))
	label.position = Vector2(-45, -32)
	label.size.x = 90
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	if kind == "door":
		collision = $Barrier/CollisionShape2D
	else:
		add_to_group("interactables")
	refresh()

func refresh() -> void:
	var state: Dictionary = Campaign.level_state(level.level_index)
	activated = str(config.id) in state.doors if kind == "door" else str(config.id) in state.switches
	if kind == "door":
		collision.set_deferred("disabled", activated)
	label.modulate = Color("79eed7") if activated else Color("ffe3a0")
	queue_redraw()

func interaction_distance(point: Vector2) -> float:
	if kind!="door" or collision==null or collision.shape==null: return position.distance_to(point)
	# The editor may offset a gate's blocker from its painted doorway. Interact
	# with the reachable face of that saved shape, not the inaccessible origin.
	var bounds:=collision.shape.get_rect()
	var local:=collision.to_local(level.to_global(point))
	var closest:=collision.to_global(local.clamp(bounds.position,bounds.end))
	return level.to_global(point).distance_to(closest)

func hint() -> String:
	if kind=="door": return "E · 开启封印门" if level.can_open_door(self) else "封印门 · 需清场并解开关联机关"
	if activated:
		return str(config.label) + " · 已启动"
	if puzzle.get("mode")=="hold":
		return "站稳踏板 · %d%%" % int(100*charge_elapsed/float(puzzle.get("seconds",1.2)))
	return "E · 调查 %s" % config.label

func interact() -> void:
	if kind=="door":
		level.open_sealed_door(self)
		return
	if activated:
		return
	if not prerequisites_met():
		var labels:=PackedStringArray()
		for dependency in puzzle.get("requires_switches",[]):
			for other in level.switches:
				if str(other.config.id)==str(dependency): labels.append(str(other.config.label))
		Campaign.message.emit("此机关尚未供能：先完成 "+"、".join(labels))
		return
	if not puzzle.is_empty():
		if puzzle.get("mode")=="hold":
			return
		var options: Array = []
		if puzzle.mode in ["riddle","cipher"]:
			for i in puzzle.options.size(): options.append({"id":str(i),"text":str(puzzle.options[i])})
			options.append({"id":"hint","text":"需要提示（逐步解释，不消耗物品）"})
			if puzzle.mode=="cipher": options.append({"id":"reset","text":"清空已输入暗语"})
		elif puzzle.mode=="direction":
			options = [{"id":"left","text":"向左旋转"},{"id":"right","text":"向右旋转"},{"id":"confirm","text":"确认光束方向"}]
		elif puzzle.mode=="circuit":
			for i in circuit.size(): options.append({"id":str(i),"text":"切换灯柱 %d（连带相邻灯）"%(i+1)})
		elif puzzle.mode=="balance":
			for i in 3: options.append({"id":str(i),"text":"调节阀门 %s（权重 %d）"%[["A","B","C"][i],i+1]})
			options.append({"id":"confirm","text":"提交压力配比"})
		else:
			if puzzle.mode=="memory": options.append({"id":"observe","text":"观察铭文并记住顺序"})
			for i in 4:
				options.append({"id":str(i),"text":["火","水","风","土"][i]})
		Dialogue.open(str(config.label),[puzzle_text()],options,self,choose)
		return
	turns += 1
	if turns >= int(config.get("steps", 1)):
		finish_puzzle()
	refresh()

func puzzle_text() -> String:
	if puzzle.get("mode")=="riddle": return str(puzzle.clue)+"\n选择符合全部条件的谜底；答错可重试。"
	if puzzle.get("mode")=="cipher":
		return str(puzzle.clue)+"\n已输入 %d / %d 段。"%[sequence_index,puzzle.sequence.size()]
	if puzzle.get("mode")=="circuit":
		var lamps:=PackedStringArray()
		for i in circuit.size(): lamps.append("%d %s"%[i+1,"亮" if int(circuit[i]) else "暗"])
		return str(puzzle.clue)+"\n灯柱："+"  ·  ".join(lamps)
	if puzzle.get("mode")=="balance": return str(puzzle.clue)+"\nA %d / B %d / C %d · 当前总压 %d / 目标 %d"%[int(valves[0]),int(valves[1]),int(valves[2]),int(valves[0])+int(valves[1])*2+int(valves[2])*3,int(puzzle.target)]
	var status := "当前方向：%s" % ["北","东","南","西"][posmod(turns,4)] if puzzle.get("mode")=="direction" else "已输入：%d / %d" % [sequence_index,puzzle.get("sequence",[]).size()]
	return ("记住铭文顺序，再输入四种符文。" if puzzle.get("mode")=="memory" else str(puzzle.get("clue","")))+"\n"+status

func prerequisites_met() -> bool:
	for id in puzzle.get("requires_switches",[]):
		if id not in Campaign.level_state(level.level_index).switches: return false
	return true

func choose(id: String) -> void:
	if activated or not prerequisites_met():
		return
	if id=="hint" and puzzle.mode in ["riddle","cipher"]:
		var hints: Array=puzzle.hints
		if Dialogue.active: Dialogue.reply(str(hints[mini(hint_step,hints.size()-1)]))
		hint_step=mini(hint_step+1,hints.size()-1)
		store_puzzle()
		return
	if id=="reset" and puzzle.mode=="cipher":
		sequence_index=0
		store_puzzle()
		if Dialogue.active: Dialogue.reply(puzzle_text())
		return
	if Time.get_ticks_msec()/1000.0<cooldown_until:
		if Dialogue.active: Dialogue.reply("机关正在复位，稍等两秒再尝试。")
		return
	if id=="observe" and puzzle.mode=="memory":
		Dialogue.reply(str(puzzle.clue)+"\n选择第一个符文后，铭文将隐去。")
		return
	if puzzle.mode=="riddle":
		if not id.is_valid_int() or int(id)<0 or int(id)>=puzzle.options.size(): return
		if int(id)==int(puzzle.answer): finish_puzzle()
		else:
			wrong_answer()
			if Dialogue.active: Dialogue.reply("这个答案无法解释全部线索。可以再读刻文，或选择分层提示。\n"+puzzle_text())
			return
	elif puzzle.mode=="circuit":
		var index := int(id)
		for offset in [-1,0,1]:
			var slot := posmod(index+offset,circuit.size())
			circuit[slot]=1-int(circuit[slot])
		if circuit_matches(circuit,puzzle.target): finish_puzzle()
	elif puzzle.mode=="balance":
		if id=="confirm":
			if int(valves[0])+int(valves[1])*2+int(valves[2])*3==int(puzzle.target): finish_puzzle()
			else: wrong_answer()
		else: valves[int(id)]=posmod(int(valves[int(id)])+1,4)
	elif puzzle.mode=="direction":
		if id=="left" or id=="right":
			turns = posmod(turns+(-1 if id=="left" else 1),4)
		elif id=="confirm":
			if turns==int(puzzle.target):
				finish_puzzle()
			else:
				wrong_answer()
				Dialogue.reply("光束没有对准。"+puzzle_text())
				return
	else:
		if not id.is_valid_int() or sequence_index>=puzzle.sequence.size(): return
		if int(id)==int(puzzle.sequence[sequence_index]):
			sequence_index += 1
			if sequence_index==puzzle.sequence.size():
				finish_puzzle()
		else:
			sequence_index = 0
			wrong_answer()
	store_puzzle()
	if Dialogue.active:
		Dialogue.reply((str(puzzle.get("explanation",""))+"\n机关已供能。清场后靠近关联封印门，按 E 开门。") if activated else puzzle_text())
	queue_redraw()

static func circuit_matches(values: Array, target: Array) -> bool:
	if values.size()!=target.size(): return false
	for i in values.size():
		if int(values[i])!=int(target[i]): return false
	return true

func store_puzzle() -> void:
	var state: Dictionary = Campaign.level_state(level.level_index)
	if not state.get("puzzles") is Dictionary:
		state.puzzles = {}
	state.puzzles[str(config.id)] = {"turns":turns,"sequence":sequence_index,"circuit":circuit.duplicate(),"valves":valves.duplicate(),"mistakes":mistakes,"hint_step":hint_step}
	Campaign.save_progress()

func finish_puzzle() -> void:
	if not prerequisites_met(): return
	Campaign.activate_switch(level.level_index,str(config.id))
	level.refresh_doors()
	Global.play_sfx("seal")
	store_puzzle()
	Campaign.message.emit(str(config.label)+" 已供能；清场后按 E 开门。")
	refresh()

func _process(delta: float) -> void:
	time += delta
	openness = move_toward(openness, 1.0 if activated else 0.0, delta * 2)
	if puzzle.get("mode")=="hold" and not activated and is_instance_valid(level.player):
		if prerequisites_met() and not level.player.is_dead and level.player.velocity.length()<2 and level.player.position.distance_to(position)<15:
			charge_elapsed += delta
			if charge_elapsed >= float(puzzle.get("seconds",1.2)):
				finish_puzzle()
		else:
			charge_elapsed = 0
	queue_redraw()

func wrong_answer() -> void:
	mistakes+=1
	if mistakes%2==0: cooldown_until=Time.get_ticks_msec()/1000.0+2.0
	Global.play_sfx("error")
	store_puzzle()

func _draw() -> void:
	var color := Color("64ecd1") if activated else Color("f6c66e")
	if kind == "door":
		draw_set_transform_matrix(global_transform.affine_inverse() * collision.global_transform)
		var w := collision.shape.get_rect().size.x * .5
		draw_arc(Vector2(0,-6), w, PI, TAU, 24, color, 2)
		for x in range(-int(w), int(w)+1, 6):
			draw_line(Vector2(x,-20-24*openness), Vector2(x,5-24*openness), Color(color,1-openness),2)
		draw_circle(Vector2.ZERO, 3, color)
		return
	draw_circle(Vector2.ZERO, 12, Color("353f42"))
	draw_arc(Vector2.ZERO, 13, 0, TAU, 24, color, 1.5)
	if puzzle.get("mode")=="circuit":
		for i in circuit.size(): draw_circle(Vector2((i-(circuit.size()-1)*.5)*6,-17),2.5,Color("71e5c9") if int(circuit[i])==1 else Color("555363"))
	if puzzle.get("mode")=="balance":
		for i in 3: draw_line(Vector2(-7+i*7,-6),Vector2(-7+i*7,-10-int(valves[i])*4),Color("9dceff"),3)
	match kind:
		"plate":
			draw_rect(Rect2(-8,-5+openness*2,16,8), color)
			if charge_elapsed>0:
				draw_arc(Vector2.ZERO,16,-PI/2,-PI/2+TAU*minf(1,charge_elapsed/float(puzzle.get("seconds",1.2))),28,Color("82e9f1"),2)
		"lever":
			var tip := Vector2(-6+openness*12,-17)
			draw_line(Vector2.ZERO, tip, Color("d8c399"),3)
			draw_circle(tip,4,color)
		"mirror", "wheel":
			var angle := turns * PI / 2 - PI/2 + (time if activated else 0.0)
			for i in 4:
				var ray := Vector2.from_angle(angle + i*PI/2)
				draw_line(ray*3,ray*10,color,2)
			if kind == "mirror":
				draw_line(Vector2.ZERO,Vector2.from_angle(angle)*25,Color(color,.6),2)
		"torch":
			draw_line(Vector2.ZERO,Vector2(0,-12),Color("8e7657"),4)
			if activated:
				draw_circle(Vector2(sin(time*9)*2,-16),5+sin(time*12),Color("ffc460"))
			else:
				draw_circle(Vector2(0,-15),3,Color("746a60"))
