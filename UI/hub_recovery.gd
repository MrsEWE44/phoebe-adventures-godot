extends CanvasLayer
## Main-scene recovery desk remains usable when every playable character is down.
var box: VBoxContainer
func _ready() -> void:
	name="HubRecovery"
	layer=45
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().paused=true
	var shade:=ColorRect.new()
	shade.color=Color(.025,.04,.07,.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(660,530)
	center.add_child(scroll)
	box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",14)
	scroll.add_child(box)
	refresh()

func label(text: String,size:=18) -> void:
	var item:=Label.new()
	item.text=text
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	box.add_child(item)

func button(text: String,action: Callable,disabled:=false,icon: Texture2D=null) -> void:
	var item:=Button.new()
	item.text=text
	item.custom_minimum_size.y=45
	item.disabled=disabled
	item.icon=icon
	item.expand_icon=true
	item.add_theme_constant_override("icon_max_width",28)
	item.pressed.connect(action)
	box.add_child(item)

func refresh() -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	label("主场景 · 队伍休整",30)
	label("角色仍处于倒下状态。使用复苏晶石恢复一名角色，再继续探索。\nLv.%d · 金币 %d · 复苏晶石 ×%d"%[Campaign.player_level(),Campaign.profile.coins,Campaign.item_count("revival_stone")])
	var icon: Texture2D=Campaign.Items.item("revival_stone").texture
	for id in Campaign.fallen_characters():
		button("复活 %s · 消耗 1 枚晶石"%Campaign.character_definition(id).display_name,revive.bind(id),not Campaign.can_consume_item("revival_stone"),icon)
	var offer: Dictionary=Campaign.Shop.STOCK.revival_stone
	button("购买复苏晶石 · %d 金币 · Lv.%d 解锁"%[offer.price,offer.level],buy,Campaign.player_level()<offer.level or Campaign.profile.coins<offer.price,icon)
	if Campaign.hub_chapter==3 and Campaign.profile.q_penguin_unlocked and not Campaign.character_allowed("q_penguin"):
		button("支付 Q币企鹅下一场费用 · 120 金币",hire,not Campaign.can_hire_mercenary())
	for id in Campaign.party_ids():
		if float(Campaign.profile.party_health.get(id,0))>0: button("出战 "+Campaign.character_definition(id).display_name,select.bind(id))
	var previous:=int(Campaign.profile.last_defeat_level)
	if previous>0: button("重新挑战上次关卡 · 恢复队伍并重置该次挑战",retry.bind(previous))
	else:
		label("尚未留下挑战记录，可重置存档重新开始。",16)
		button("重置存档",reset_save)
	if Campaign.player_level()<offer.level: label("复苏晶石在40级解锁。也可选择重新挑战，恢复队伍后重头挑战本关。",16)

func revive(id: String) -> void:
	Campaign.revive_character(id)
	finish_or_refresh()
func buy() -> void:
	Campaign.purchase("revival_stone")
	refresh()
func hire() -> void:
	Campaign.hire_mercenary()
	refresh()
func select(id: String) -> void:
	Campaign.select_character(id)
	finish_or_refresh()
func finish_or_refresh() -> void:
	if float(Campaign.profile.health)>0:
		get_tree().paused=false
		queue_free()
	else: refresh()
func retry(index: int) -> void:
	get_tree().paused=false
	Campaign.recover_from_defeat.call_deferred(index,true)
	queue_free()
func reset_save() -> void:
	var dialog:=preload("res://UI/reset_save_dialog.gd").new()
	add_child(dialog)
	dialog.popup_centered(Vector2i(520,200))
