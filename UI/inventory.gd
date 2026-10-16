extends Control
## A separate modal inventory; Campaign remains the only persisted item store.
signal close_requested
const Items = preload("res://Combat/items.gd")
const Weapons = preload("res://Weapons/weapon_registry.gd")
const CATEGORIES = ["道具", "药品", "武器", "角色"]
var category := 0
var selected := ""
var entries: Array[Dictionary] = []
var tabs: Array[Button] = []
var grid: GridContainer
var detail: VBoxContainer
var subtitle: Label
var feedback: Label
var title_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(.015,.025,.045,.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 55
	panel.offset_right = -55
	panel.offset_top = 112
	panel.offset_bottom = -55
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152434")
	style.border_color = Color("b49b65")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label = label("探险背包",26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close := Button.new()
	close.text = "关闭  B / I / Esc"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	subtitle = label("",16)
	box.add_child(subtitle)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation",10)
	box.add_child(nav)
	for i in CATEGORIES.size():
		var tab := Button.new()
		tab.text = CATEGORIES[i]
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(125,40)
		tab.add_theme_stylebox_override("pressed",selection_style())
		tab.pressed.connect(func(): select_category(i))
		nav.add_child(tab)
		tabs.append(tab)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24)
	box.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size.x = 300
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(details_scroll)
	detail = VBoxContainer.new()
	detail.custom_minimum_size.x = 290
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",12)
	details_scroll.add_child(detail)
	feedback = label("浏览背包时已暂停战斗。",15)
	box.add_child(feedback)
	Campaign.profile_changed.connect(_on_profile_changed)
	Campaign.message.connect(func(message: String):
		if visible: feedback.text = message)
	hide()

func label(text: String, size: int = 17) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("f2e7ce"))
	return node

func selection_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("28465a")
	style.border_color = Color("d7b879")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func portrait(spec: Resource) -> Texture2D:
	var animation: StringName = &"idle" if spec.animations.has_animation(&"idle") else &"down"
	var tex: Texture2D = spec.animations.get_frame_texture(animation,0)
	var cropped := AtlasTexture.new()
	cropped.atlas = tex
	cropped.region = tex.get_image().get_used_rect()
	return cropped

func open() -> void:
	show()
	feedback.text = "浏览背包时已暂停战斗。"
	refresh()
	tabs[category].grab_focus()

func select_category(index: int) -> void:
	category = clampi(index,0,3)
	selected = ""
	refresh()
	tabs[category].grab_focus()

func _on_profile_changed() -> void:
	if visible: refresh()

func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func build_entries() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var p: Dictionary=Campaign.profile
	var growth=Campaign.Growth
	match category:
		0:
			if Campaign.item_count("time_capsule")>0:
				var capsule: Dictionary=Items.item("time_capsule")
				result.append({"id":"time_capsule","name":capsule.name,"icon":capsule.texture,"tag":"剧情钥匙","description":"在5-9选择留下的时空胶囊。奥摩的时代坐标已保存；未来时空篇章开放后才能使用。不可消耗或销毁。","action":"等待未来时空篇章","enabled":false})
			if Campaign.travel_scroll_unlocked():
				var scroll: Dictionary=Items.item("travel_scroll")
				result.append({"id":"travel_scroll","name":scroll.name,"icon":scroll.texture,"tag":"∞ 无限使用","description":"进入第四章永久解锁。\n可前往已满足等级条件的第一至第五章主场景，无次数限制、不消耗金币。\n未通关也能离开，保留该关进度。","action":"选择传送目的地","enabled":float(p.health)>0})
			if Campaign.item_count("battle_overdrive")>0:
				var war_song: Dictionary=Items.item("battle_overdrive")
				var remaining: float=Campaign.overdrive_remaining()
				var status: String="剩余 %d 秒"%ceili(remaining) if remaining>0 else ("本关已用" if Campaign.active_level>0 and bool(Campaign.level_state(Campaign.active_level).get("overdrive_used",false)) else "每次挑战 1 次")
				result.append({"id":"battle_overdrive","name":war_song.name,"icon":war_song.texture,"tag":status,"description":"4-5通关永久解锁。快捷键5。\n30秒内，玩家攻击命中敌人造成999真伤，无视防御。\n每次挑战限用一次；重新挑战或新关卡恢复次数。离开关卡效果结束，返回不会恢复次数。\n暂停时倒计时停止；不强化友军伤害，不跳过首领阶段。","action":"使用 · 30秒999真伤","enabled":Campaign.can_consume_item("battle_overdrive")})
			var crystal: Dictionary=Items.item("experience_crystal")
			var count: int=Campaign.item_count("experience_crystal")
			result.append({"id":"experience_crystal","name":crystal.name,"icon":crystal.texture,"tag":"× %d"%count,"description":"使用获得 %d 经验，可升级并提升基础属性。\n满级 100 级时不消耗；倒下时不能使用。\n通过怪物掉落或 1 级商店购买（80 金币）获得。"%crystal.experience,"action":"使用 · +%d 经验"%crystal.experience if Campaign.can_consume_item("experience_crystal") else ("已满级" if Campaign.player_level()>=100 else "暂不可使用"),"enabled":Campaign.can_consume_item("experience_crystal")})
			for id in ["armor","amulet","diving_armor"]+p.equipment_owned:
				if id not in p.equipment_owned and not p.get(id,false): continue
				var data: Dictionary=Items.item(id)
				var slot: String=data.get("slot","")
				var equipped: bool=slot.is_empty() or p.equipment_slots.get(slot)==id
				var scale: float=growth.defense_scale(Campaign.player_level())
				result.append({"id":id,"name":data.name,"icon":data.get("texture"),"tag":"已装备" if equipped else "未装备","description":"物理防御 +%s\n法术防御 +%s\n移动速度 %+d%%\n同类装备槽只生效一件。"%[growth.number(float(data.get("physical_defense",0))*scale),growth.number(float(data.get("magic_defense",0))*scale),roundi(float(data.get("speed_bonus",0))*100)],"action":"自动生效" if slot.is_empty() else ("卸下装备" if equipped else "装备"),"enabled":not slot.is_empty()})
		1:
			for id in ["health","energy","ultimate","health_large","energy_large","elixir","revival_stone"]:
				var count: int=Campaign.item_count(id)
				var descriptions={"revival_stone":"仅在主场景使用，复活一名已倒下的角色并恢复全部生命。40级商店购买；角色页可选择复活目标。全队倒下请先返回主场景。","health":"恢复最大生命的 40%。快捷键 Q。","energy":"恢复 70 点能量。快捷键 R。","ultimate":"补充一次大招。快捷键 T。Q 币企鹅不能使用。","health_large":"恢复最大生命的 80%。快捷键 2。","energy_large":"恢复 200 点能量。快捷键 3。","elixir":"完全恢复当前角色的生命与能量。快捷键 4。"}
				var useful: bool=Campaign.can_consume_item(id)
				result.append({"id":id,"name":Items.item(id).name,"icon":Items.item(id).get("texture"),"tag":"× %d"%count,"description":descriptions[id],"action":"立即使用" if count>0 and useful else ("数量不足" if count==0 else "当前无需使用"),"enabled":count>0 and useful and (float(p.health)>0 or id=="revival_stone")})
		2:
			var default_id: String=Campaign.character_definition(str(p.character)).default_weapon
			var weapon_ids: Array=p.weapons.duplicate()
			if default_id not in weapon_ids: weapon_ids.push_front("fists")
			for id: String in weapon_ids:
				var effective: String=Campaign.character_definition(str(p.character)).default_weapon if id=="fists" else id
				var weapon: Resource=Weapons.get_weapon(effective)
				var damage: float=weapon.damage*Campaign.weapon_multiplier(effective)*float(Campaign.player_stats().attack)/20.0
				var effect: String={"silence":"3-9通关奖励。真伤：奶娃/凑企鹅幼体秒杀、小BOSS至少60%最大生命、完全体至少18%。30%暴击×1.8，连锁5名敌人；命中奶娃沉默2.5秒。","shock":"电弧连锁最多两名邻近敌人，短暂麻痹。","burn":"命中后持续灼烧四秒。","frost":"冻结并减速；BOSS 冻结时间缩短。"}.get(weapon.hit_effect,"")
				var extra: String="F / V / 右键：沿鼠标方向贯穿一行敌人，冷却 15 秒。" if effective=="q_ak" else ("V / 右键：一刀999 · 大范围横扫\n固定真伤999（不受等级、强化加成） · 40能量 · 冷却6秒" if effective=="pili_blade" else ("左键投石 · 右键碎石雨 · V陨石 · H飞踢\n凑企鹅战利品，仅咕嘎企鹅可使用。" if effective=="penguin_rock" else ("V："+weapon.special_name if weapon.special_attack else effect)))
				if not weapon.handling_note.is_empty(): extra=weapon.handling_note+"\n"+extra
				result.append({"id":id,"name":weapon.weapon_name+" +%d"%Campaign.weapon_upgrade(effective),"tag":"已装备" if Campaign.effective_weapon()==effective else ("角色默认" if id=="fists" else "已拥有"),"icon":weapon.texture,"description":"%s · %s攻击\n基础结算伤害 %s（环境加成另计）\n能量 %d · 间隔 %.2fs · 距离 %d\n强化上限 +10，每级 +10%% 武器伤害。\n%s"%["近战" if weapon.kind=="melee" else "远程",{"true":"真实","magic":"法术","physical":"物理"}.get(weapon.damage_type,"物理"),growth.number(damage),weapon.energy_cost,weapon.cooldown,weapon.attack_range,extra],"action":"角色不可装备" if not Campaign.can_equip_weapon(id) else ("已装备" if Campaign.effective_weapon()==effective else "装备武器"),"enabled":Campaign.can_equip_weapon(id) and Campaign.effective_weapon()!=effective})
		3:
			for id in Campaign.CHARACTER_IDS:
				var spec:=Campaign.character_definition(id)
				var stats:=Campaign.player_stats(id)
				var unlocked: bool=id=="phoebe" or bool(p.get(id+"_unlocked",false))
				if id=="q_penguin" and Campaign.active_level==24: unlocked=true
				var allowed: bool=Campaign.character_allowed(id)
				var hp: float=float(p.health) if p.character==id else float(p.party_health.get(id,stats.health))
				result.append({"id":id,"name":spec.display_name,"icon":portrait(spec),"tag":"出战中" if p.character==id else (Campaign.character_restriction(id) if unlocked and not allowed else ("Lv.%d"%Campaign.player_level() if unlocked else "未解锁")),"description":"共享冒险等级 Lv.%d\n生命 %s / %s\n攻击 %s · 基础防御 %s\n默认武器：%s\n大招：%s\n%s"%[Campaign.player_level(),growth.number(hp),growth.number(stats.health),growth.number(stats.attack),growth.number(stats.defense),Weapons.get_weapon(spec.default_weapon).weapon_name,spec.ultimate.display_name,Campaign.character_unlock_hint(id)],"action":Campaign.character_restriction(id) if not allowed and unlocked else ("出战中" if p.character==id else ("切换角色" if unlocked and hp>0 else ("已倒下" if unlocked else "尚未解锁"))),"enabled":unlocked and allowed and hp>0 and p.character!=id})
	if category==3:
		for entry in result:
			if entry.id=="q_penguin":
				entry.description+="\nWASD移动、鼠标瞄准、左键射击；F/V/右键贯穿弹头，15秒冷却。3-7可免费试用，其它第三章挑战每场120金币。"
				if not Campaign.character_allowed("q_penguin") and p.q_penguin_unlocked and Campaign.hub_chapter==3:
					entry.tag="需支付本场费用"
					entry.action="支付下一场费用 · 120 金币"
					entry.enabled=Campaign.can_hire_mercenary()
			if entry.id in Campaign.fallen_characters():
				entry.action="使用复苏晶石 · ×%d"%Campaign.item_count("revival_stone") if Campaign.active_level==0 else "返回主场景后复活"
				entry.enabled=Campaign.can_consume_item("revival_stone")
	for entry in result:
		if category in [0,2] and entry.id!="experience_crystal": entry.tag+=" · ×1"
		if category==2 and entry.icon==null: entry.icon=load("res://UI/Icons/fists.svg")
	return result

func refresh() -> void:
	entries = build_entries()
	var p: Dictionary = Campaign.profile
	subtitle.text = "Lv.%d · 经验 %d/%d · 币 %d · HP %s/%s · 能量 %d/200"%[Campaign.player_level(),p.experience,Campaign.Growth.xp_required(Campaign.player_level()),p.coins,Campaign.Growth.number(p.health),Campaign.Growth.number(Campaign.player_stats().health),p.energy]
	for i in tabs.size(): tabs[i].set_pressed_no_signal(i==category)
	clear(grid)
	if entries.is_empty():
		selected = ""
		var empty := label("暂无防御道具\n探索宝箱、击败怪物或向商人购买。",16)
		grid.add_child(empty)
	else:
		if not entries.any(func(entry: Dictionary): return entry.id==selected): selected = str(entries[0].id)
		for entry in entries:
			var button := Button.new()
			button.custom_minimum_size = Vector2(205,80)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.text = "%s\n%s" % [entry.name,entry.tag]
			button.toggle_mode = true
			button.add_theme_stylebox_override("pressed",selection_style())
			button.button_pressed = selected==entry.id
			button.icon = entry.get("icon",null)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width",45)
			button.pressed.connect(func():
				selected = str(entry.id)
				refresh())
			grid.add_child(button)
	show_detail()

func show_detail() -> void:
	clear(detail)
	if selected.is_empty():
		detail.add_child(label("选择物品查看详情",20))
		return
	for entry in entries:
		if entry.id!=selected: continue
		if entry.get("icon") != null:
			var icon := TextureRect.new()
			icon.texture = entry.icon
			icon.custom_minimum_size = Vector2(120,64 if category==2 else 95)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail.add_child(icon)
		detail.add_child(label(str(entry.name),23))
		if category==1: detail.add_child(label("持有数量：%d"%Campaign.item_count(selected),16))
		var text := label(str(entry.description),16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if category!=2 and selected not in ["q_penguin","battle_overdrive"]: detail.add_child(text)
		var action := Button.new()
		action.text = str(entry.action)
		action.custom_minimum_size.y = 42
		action.disabled = not entry.enabled
		action.pressed.connect(activate_selected)
		detail.add_child(action)
		if selected in ["q_penguin","battle_overdrive"]: detail.add_child(text)
		if category==2:
			var effective: String=Campaign.character_definition(str(Campaign.profile.character)).default_weapon if selected=="fists" else selected
			var upgrade:=Button.new()
			upgrade.text="已达强化上限 +10" if Campaign.weapon_upgrade(effective)>=10 else "强化至 +%d · %d 币"%[Campaign.weapon_upgrade(effective)+1,Campaign.upgrade_cost(effective)]
			upgrade.disabled=Campaign.weapon_upgrade(effective)>=10 or Campaign.profile.coins<Campaign.upgrade_cost(effective)
			upgrade.pressed.connect(func():
				feedback.text="强化成功。" if Campaign.upgrade_weapon(effective) else "无法强化。"
				refresh())
			detail.add_child(upgrade)
			if selected=="penguin_rock":
				detail.add_child(label("咕嘎专属 · 固定装备，不可丢弃或销毁。",13))
			elif selected!="fists":
				var destroy:=Button.new()
				destroy.text="销毁此武器"
				destroy.pressed.connect(confirm_destroy.bind(selected))
				detail.add_child(destroy)
				detail.add_child(label("G 丢弃可拾回；销毁不退还强化费用。",13))
			detail.add_child(text)

func activate_selected() -> void:
	if selected=="travel_scroll":
		var scroll:=preload("res://UI/travel_scroll.gd").new()
		add_child(scroll)
		scroll.popup_centered(Vector2i(460,340))
		return
	var ok := false
	match category:
		0: ok = Campaign.consume_item(selected) if selected in ["experience_crystal","battle_overdrive"] else Campaign.equip_item(selected)
		1: ok = Campaign.consume_item(selected)
		2: ok = Campaign.equip_weapon(selected)
		3:
			if selected in Campaign.fallen_characters(): ok=Campaign.revive_character(selected)
			elif selected=="q_penguin" and not Campaign.character_allowed(selected): ok=Campaign.hire_mercenary()
			else: ok=Campaign.select_character(selected)
	if ok:
		feedback.text = "已使用药剂。" if category==1 else ("武器已装备。" if category==2 else "出战角色已切换。")
		if category==0: feedback.text="装备状态已更新。"
		if selected=="experience_crystal": feedback.text="已使用经验结晶，获得 %d 经验。"%Items.item(selected).experience
		if selected=="battle_overdrive": feedback.text="破甲战歌已激活，关闭背包开始30秒倒计时。"
		if category==3: feedback.text="角色状态已更新，可选择切换出战。"
	else:
		feedback.text = "当前无法操作，请检查数量、生命状态或等待大招结束。"
	refresh()

func confirm_destroy(id: String) -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="销毁武器"
	dialog.dialog_text="确定销毁「%s」？\n这把武器及其强化会永久移除，费用不返还。"%Weapons.get_weapon(id).weapon_name
	dialog.ok_button_text="确认销毁"
	dialog.cancel_button_text="保留"
	add_child(dialog)
	dialog.confirmed.connect(func():
		Campaign.destroy_weapon(id)
		selected=""
		refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500,180))
