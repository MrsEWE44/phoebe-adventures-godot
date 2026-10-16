extends ConfirmationDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	transient = true
	exclusive = true
	title = "重置存档"
	dialog_text = "将清除全部关卡进度、角色解锁、武器强化、装备、道具和海币。\n等级恢复为 1 级，经验清零，生命、攻击、防御等恢复初始值。\n从第一章出生点重新开始，音量设置保留。\n此操作无法撤销。"
	get_ok_button().text = "清除存档并重新开始"
	get_cancel_button().text = "取消"
	confirmed.connect(_reset)

func _reset() -> void:
	if not Campaign.restart_campaign():
		get_tree().paused = true
		dialog_text = Campaign.save_error if not Campaign.save_error.is_empty() else "无法重新开始，请稍后重试。"
		popup_centered.call_deferred(Vector2i(520,200))
