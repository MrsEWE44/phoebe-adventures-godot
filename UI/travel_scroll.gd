extends AcceptDialog
## Permanent key item, with no count deduction or purchase charge.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	title="传送卷轴 · 无限使用"
	get_ok_button().text="取消"
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	add_child(box)
	var note:=Label.new()
	note.text="选择要返回的主场景。\n未完成的关卡进度会保留，可再次进入继续挑战。"
	box.add_child(note)
	for chapter in range(1,6):
		var button:=Button.new()
		button.name="Chapter%d"%chapter
		button.text="第%d章主场景 · %s"%[chapter,["海岸","海底遗迹","冰封王庭","音乐沼泽","地狱余烬"][chapter-1]]
		button.custom_minimum_size.y=42
		button.disabled=not Campaign.can_enter_chapter(chapter) or (Campaign.active_level==0 and Campaign.hub_chapter==chapter)
		if button.disabled: button.text+="（当前位置）" if Campaign.hub_chapter==chapter else "（等级不足）"
		button.pressed.connect(choose.bind(chapter))
		box.add_child(button)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
func choose(chapter: int) -> void:
	if Campaign.use_travel_scroll(chapter): hide()
