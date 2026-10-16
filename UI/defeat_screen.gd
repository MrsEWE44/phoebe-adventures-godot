extends CanvasLayer
var active := false
var level_index := 0
var reason:="队伍已倒下"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	active = true
	get_tree().paused = true
	var root := ColorRect.new()
	root.color = Color(.02,.025,.04,.86)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250,-110)
	panel.size = Vector2(500,220)
	panel.add_theme_constant_override("separation",20)
	root.add_child(panel)
	var title := Label.new()
	title.text = reason
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",32)
	panel.add_child(title)
	var caption := Label.new()
	caption.text = "装备会保留。复苏晶石只能返回主场景后使用。\n重新挑战会恢复队伍，并重置未通关的本关探索。"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(caption)
	var reset_dialog := preload("res://UI/reset_save_dialog.gd").new()
	add_child(reset_dialog)
	var restart := Button.new()
	restart.text = "重置存档 / 重新开始"
	restart.pressed.connect(func(): reset_dialog.popup_centered(Vector2i(520,200)))
	panel.add_child(restart)
	for item in [["重新挑战当前关卡",true],["返回主地图",false]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size.y = 46
		panel.add_child(button)
		button.pressed.connect(choose.bind(item[1]))
	panel.get_child(3).grab_focus()

func choose(retry: bool) -> void:
	if not active:
		return
	active = false
	get_tree().paused = false
	Campaign.recover_from_defeat.call_deferred(level_index,retry)
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode not in [KEY_UP,KEY_DOWN,KEY_TAB,KEY_ENTER,KEY_SPACE]:
		get_viewport().set_input_as_handled()
