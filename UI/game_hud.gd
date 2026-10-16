extends CanvasLayer

var world: Node2D
var status: Label
var objective: Label
var hint: Label
var toast: Label
var health: ProgressBar
var energy: ProgressBar
var ultimate_button: Button
var weapon_special_button: Button
var flying_kick_button: Button
var consumable_bar: HBoxContainer
var pause_panel: PanelContainer
var inventory_panel: Control
var reset_dialog: ConfirmationDialog
var map_panel: Control
var message_time := 0.0
var is_level := false
var clock := 0.0
var refresh_elapsed:=0.1
var story_goal: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	is_level = world.get("level_index") != null
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 16
	top.offset_bottom = 103
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.05,.08,.12,.93)
	style.border_color = Color("746b4c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel",style)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	top.add_child(row)
	var bars := VBoxContainer.new()
	bars.custom_minimum_size.x = 190
	row.add_child(bars)
	status = make_label("",16)
	bars.add_child(status)
	health = make_bar(100,Color("e47075"))
	energy = make_bar(200,Color("69aee5"))
	bars.add_child(health)
	bars.add_child(energy)
	objective = make_label("",16)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(objective)
	var buttons := HBoxContainer.new()
	row.add_child(buttons)
	ultimate_button = Button.new()
	ultimate_button.text = "绝杀 F"
	buttons.add_child(ultimate_button)
	ultimate_button.pressed.connect(func():
		var players := get_tree().get_nodes_in_group("players")
		if not players.is_empty() and not get_tree().paused:
			var actor = players[0]
			actor.trigger_ultimate(actor.facing))
	weapon_special_button=Button.new()
	weapon_special_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	weapon_special_button.position=Vector2(18,-157)
	weapon_special_button.size=Vector2(260,62)
	weapon_special_button.add_theme_font_size_override("font_size",18)
	weapon_special_button.add_theme_color_override("font_disabled_color",Color("b4c5d6"))
	for state in ["normal","hover","pressed","disabled"]:
		var skill_style:=StyleBoxFlat.new()
		skill_style.bg_color=Color("162333") if state=="disabled" else Color("203d55")
		if state=="hover": skill_style.bg_color=Color("305a77")
		skill_style.border_color=Color("60768a") if state=="disabled" else Color("a5d9ef")
		skill_style.set_border_width_all(2)
		skill_style.set_corner_radius_all(8)
		weapon_special_button.add_theme_stylebox_override(state,skill_style)
	weapon_special_button.tooltip_text="点击沿角色朝向释放；V 键朝鼠标方向释放。"
	root.add_child(weapon_special_button)
	weapon_special_button.pressed.connect(func():
		var players:=get_tree().get_nodes_in_group("players")
		if not players.is_empty() and not get_tree().paused:
			players[0].trigger_weapon_special(players[0].facing))
	flying_kick_button=Button.new()
	flying_kick_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	flying_kick_button.position=Vector2(290,-157)
	flying_kick_button.size=Vector2(210,62)
	flying_kick_button.theme_type_variation=weapon_special_button.theme_type_variation
	for state in ["normal","hover","pressed","disabled"]:
		flying_kick_button.add_theme_stylebox_override(state,weapon_special_button.get_theme_stylebox(state))
	flying_kick_button.add_theme_color_override("font_disabled_color",Color("b4c5d6"))
	flying_kick_button.tooltip_text="继承凑企鹅的直线飞踢。敌我不分，中立 NPC 免伤；撞墙停止。"
	root.add_child(flying_kick_button)
	flying_kick_button.pressed.connect(func():
		var players:=get_tree().get_nodes_in_group("players")
		if not players.is_empty(): players[0].trigger_flying_kick(players[0].facing))
	story_goal=Button.new()
	story_goal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	story_goal.position=Vector2(18,170)
	story_goal.size=Vector2(590,40)
	story_goal.add_theme_stylebox_override("normal",style)
	story_goal.add_theme_font_size_override("font_size",15)
	root.add_child(story_goal)
	story_goal.pressed.connect(func():
		if menus_available(): Story.open_journal())
	for title in ["地图 M","背包 B","暂停 Esc"]:
		var button := Button.new()
		button.text = title
		buttons.add_child(button)
		button.pressed.connect(toggle_map if title.begins_with("地图") else (toggle_inventory if title.begins_with("背包") else toggle_pause))
	hint = make_label("",19)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -91
	hint.offset_bottom = -58
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var controls := make_label("WASD 移动  左键/J 攻击  右键/K 技能  E 交互  F 大招  V 武器绝招  G 丢弃  H 飞踢  Q/R/T 药剂  Tab 换角色  B 背包",14)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -42
	controls.offset_bottom = -12
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(controls)
	toast = make_label("",19)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 124
	toast.offset_bottom = 167
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)
	Campaign.message.connect(show_message)
	consumable_bar=preload("res://UI/consumable_bar.gd").new()
	consumable_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	consumable_bar.offset_left=-718
	consumable_bar.offset_right=-18
	consumable_bar.offset_top=-157
	consumable_bar.offset_bottom=-99
	root.add_child(consumable_bar)
	map_panel = preload("res://UI/map_overlay.gd").new()
	map_panel.world = world
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.visible = false
	root.add_child(map_panel)
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -250
	pause_panel.offset_right = 250
	pause_panel.offset_top = -230
	pause_panel.offset_bottom = 230
	pause_panel.add_theme_stylebox_override("panel",style)
	pause_panel.visible = false
	root.add_child(pause_panel)
	inventory_panel = preload("res://UI/inventory.gd").new()
	root.add_child(inventory_panel)
	inventory_panel.close_requested.connect(toggle_inventory)
	reset_dialog = preload("res://UI/reset_save_dialog.gd").new()
	add_child(reset_dialog)
	if not is_level: show_hub_recovery.call_deferred()
	show_message(str(world.config.adventure.intro) if is_level else ("第五章地狱：十座牢狱、救回伙伴。左门封锁，右门通关后开启。" if Campaign.hub_chapter==5 else "第四章沼泽：红门4-1开始救援，十关顺序解锁。E与营地NPC交谈。" if Campaign.hub_chapter==4 else "冰封王庭：从红色 3-1 开始；3-7生存三分钟；3-9生存四分钟并清场解救Doro。" if Campaign.hub_chapter==3 else "潮汐遗迹：左下方 2-1 开始；中央洞口 E 返回海岸，E 与商人交易。" if Campaign.hub_chapter==2 else "从左侧 1-1 开始探索；触碰南侧海水可进入第二章。"))

func show_hub_recovery() -> void:
	if Campaign.active_level==0 and float(Campaign.profile.health)<=0:
		world.add_child(preload("res://UI/hub_recovery.gd").new())

func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f2e7ce"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func make_bar(maximum: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.custom_minimum_size = Vector2(190,16)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func _process(delta: float) -> void:
	clock += delta
	message_time -= delta
	toast.visible = message_time>0
	refresh_elapsed+=delta
	if refresh_elapsed<.1: return
	refresh_elapsed=0.0
	story_goal.text=Story.objective(int(world.get("level_index")) if world.get("level_index")!=null else 0)
	consumable_bar.refresh()
	var p: Dictionary = Campaign.profile
	var players := get_tree().get_nodes_in_group("players")
	var actor = players[0] if not players.is_empty() else null
	health.max_value = actor.max_health if actor != null else 100
	energy.max_value = actor.max_energy if actor != null else 200
	status.text = "%s Lv.%d\nHP %s / %s" % [actor.definition.display_name if actor != null else str(p.character),Campaign.player_level(),Campaign.Growth.number(p.health),Campaign.Growth.number(health.max_value)]
	health.value = p.health
	energy.value = p.energy
	ultimate_button.disabled = actor == null or actor.is_dead or get_tree().paused or actor.ultimate == null or actor.casting_remaining > 0 or actor.ultimate_cooldown > 0 or actor.in_safe_circle() or world.get("allow_ultimates")==false or Campaign.ultimate_charges(str(p.character)) <= 0
	if actor != null and actor.ultimate != null:
		ultimate_button.text = "%s %s\n%d/%d 次%s" % [actor.ultimate.display_name,OS.get_keycode_string(actor.ultimate.key),Campaign.ultimate_charges(str(p.character)),actor.ultimate.max_charges," · %.1fs" % actor.ultimate_cooldown if actor.ultimate_cooldown>0 else ""]
		if p.character=="q_penguin": ultimate_button.text="贯穿弹头 F / V\n"+("冷却 %.1fs"%actor.ultimate_cooldown if actor.ultimate_cooldown>0 else "已就绪")
	var weapon_id: String=Campaign.effective_weapon()
	var weapon: Dictionary = preload("res://Combat/items.gd").item(weapon_id)
	var weapon_label: String=weapon.name
	if Campaign.weapon_upgrade(weapon_id)>0: weapon_label+=" +%d"%Campaign.weapon_upgrade(weapon_id)
	if actor!=null and actor.normal_weapon.special_attack!=0:
		weapon_label+=" · V "+actor.normal_weapon.special_name
	weapon_special_button.visible=actor!=null and actor.normal_weapon.special_attack!=0 and p.character!="q_penguin"
	if weapon_special_button.visible:
		var spec: Resource=actor.normal_weapon
		var cooldown: float=actor.weapon_special_cooldowns.get(spec.weapon_id,0)
		weapon_special_button.text=spec.special_name+"  V"+(" / 右键" if spec.weapon_id=="pili_blade" else "")+"\n%d能量 · "%spec.special_energy_cost+("冷却 %.1fs"%cooldown if cooldown>0 else "点击释放")
		weapon_special_button.disabled=actor.is_dead or get_tree().paused or actor.is_action_locked() or actor.in_safe_circle() or world.get("allow_ultimates")==false or cooldown>0 or p.energy<spec.special_energy_cost
	flying_kick_button.visible=actor!=null and p.character=="gugu" and p.gugu_unlocked
	if flying_kick_button.visible:
		var kick_cooldown: float=actor.weapon_special_cooldowns.get("flying_kick",0)
		flying_kick_button.text="飞踢 H · 敌我不分\n30能量 · "+("冷却 %.1fs"%kick_cooldown if kick_cooldown>0 else "点击释放")
		flying_kick_button.disabled=actor.is_dead or get_tree().paused or actor.is_action_locked() or actor.in_safe_circle() or world.get("allow_ultimates")==false or kick_cooldown>0 or p.energy<30
	var title := "潮汐遗迹 · 海币 %d" % int(p.coins) if Campaign.hub_chapter==2 else "遗迹海岸  ·  已解封 1-%d" % mini(7,Campaign.unlocked_level())
	if is_level:
		title = "%s  %s   门 %d / %d" % [preload("res://Scence/Levels/catalog.gd").label(world.level_index),world.config.name,Campaign.level_state(world.level_index).doors.size(),world.doors.size()]
		if world.get("adventure")!=null:
			title += " · 剩余敌人 %d" % world.adventure.remaining_enemies()
	if world.has_method("objective_text"): title=world.objective_text()
	elif Campaign.hub_chapter==3: title="冰封王庭 · 第三章波次挑战"
	objective.text = "%s · XP %d/%d\n%s · 能量 %d/%d · 药剂 Q:%d R:%d T:%d" % [title,p.experience,Campaign.Growth.xp_required(Campaign.player_level()),weapon_label,p.energy,energy.max_value,p.health_potions,p.energy_potions,p.ultimate_potions]
	if actor != null and actor.home_buff:
		title += " · 环境加持"
		objective.text = objective.text.replace("\n"," · 环境加持\n")
	hint.text = str(world.get("interaction_hint")) if world.get("interaction_hint") != null else ""
	if not Campaign.save_error.is_empty():
		hint.text = Campaign.save_error

func show_message(text: String) -> void:
	toast.text = text
	message_time = 5.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_L:
			if menus_available(): Story.open_journal()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			if inventory_panel.visible:
				toggle_inventory()
			elif map_panel.visible:
				toggle_map()
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_B,KEY_I]:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_M:
			toggle_map()
			get_viewport().set_input_as_handled()

func menus_available() -> bool:
	if Dialogue.active or Campaign.transitioning or float(Campaign.profile.health)<=0 or (reset_dialog != null and reset_dialog.visible):
		return false
	return not get_tree().paused or map_panel.visible or pause_panel.visible or inventory_panel.visible

func toggle_inventory() -> void:
	if not menus_available(): return
	if inventory_panel.visible:
		inventory_panel.hide()
		get_tree().paused = false
		return
	pause_panel.hide()
	map_panel.hide()
	get_tree().paused = true
	inventory_panel.open()
	Story.note_action("inventory")

func toggle_map() -> void:
	if not menus_available() or pause_panel.visible or inventory_panel.visible:
		return
	map_panel.visible = not map_panel.visible
	get_tree().paused = map_panel.visible
	map_panel.queue_redraw()

func toggle_pause() -> void:
	if not menus_available():
		return
	if inventory_panel.visible:
		toggle_inventory()
		return
	if map_panel.visible:
		toggle_map()
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible
	if not pause_panel.visible:
		return
	for child in pause_panel.get_children():
		pause_panel.remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480,420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	box.add_child(make_label("游戏已暂停",24))
	var bag := Button.new()
	bag.text = "打开分类背包  B / I"
	bag.pressed.connect(toggle_inventory)
	box.add_child(bag)
	if is_level:
		var retry:=Button.new()
		retry.name="RetryLevel"
		retry.text="重新挑战本关（保留等级、装备）"
		retry.pressed.connect(func(): Campaign.retry_current_level.call_deferred())
		box.add_child(retry)
		var back:=Button.new()
		back.name="ReturnToHub"
		back.text="返回本章主场景（保存本关进度）"
		back.pressed.connect(func(): Campaign.return_to_hub.call_deferred())
		box.add_child(back)
	if Campaign.travel_scroll_unlocked():
		var travel:=Button.new()
		travel.name="TravelScroll"
		travel.text="传送卷轴 · 前往其它主场景 · 无限使用"
		travel.pressed.connect(func():
			var picker:=preload("res://UI/travel_scroll.gd").new()
			add_child(picker)
			picker.popup_centered(Vector2i(460,340)))
		box.add_child(travel)
	box.add_child(make_label("独立音量 · 拉到最左侧静音",16))
	for bus in ["Music","Voice","EnemyVoice","Effects"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var caption := make_label({"Music":"背景音乐","Voice":"玩家 / NPC","EnemyVoice":"敌人 / BOSS","Effects":"音效"}[bus],15)
		caption.custom_minimum_size.x = 90
		row.add_child(caption)
		var slider := HSlider.new()
		slider.name=bus+"Volume"
		slider.min_value = -50
		slider.max_value = 6
		slider.step = 1
		slider.value = Global.audio_levels[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		slider.value_changed.connect(func(value: float): Global.set_audio_level(bus,value))
	var resume := Button.new()
	resume.text = "继续探索"
	resume.pressed.connect(toggle_pause)
	box.add_child(resume)
	var restart := Button.new()
	restart.text = "重置存档 / 重新开始"
	restart.pressed.connect(func(): reset_dialog.popup_centered(Vector2i(520,200)))
	box.add_child(restart)
	var quit := Button.new()
	quit.text = "保存并退出游戏"
	quit.pressed.connect(func():
		if is_level:
			if world.get("adventure")!=null:
				world.adventure.snapshot()
			if world.has_method("snapshot"): world.snapshot()
			Campaign.checkpoint(world.level_index,world.player.position)
		else:
			Campaign.save_progress()
		get_tree().quit())
	box.add_child(quit)

func _exit_tree() -> void:
	get_tree().paused = false
