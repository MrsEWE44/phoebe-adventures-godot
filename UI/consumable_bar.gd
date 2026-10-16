extends HBoxContainer
const ITEMS=["health","energy","ultimate","health_large","energy_large","elixir","battle_overdrive"]
const KEYS=["Q","R","T","2","3","4","5"]
const NAMES=["生命药","技能药","绝杀药","大生命","大技能","全效药","破甲战歌"]
var buttons: Dictionary={}

func _ready() -> void:
	add_theme_constant_override("separation",6)
	for i in ITEMS.size():
		var id: String=ITEMS[i]
		var button:=Button.new()
		button.custom_minimum_size=Vector2(94,56)
		button.icon=Campaign.Items.item(id).get("texture")
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",25)
		button.add_theme_font_size_override("font_size",13)
		for state in ["normal","hover","pressed","disabled"]:
			var style:=StyleBoxFlat.new()
			style.bg_color=Color("243d50") if state in ["hover","pressed"] else Color("111f2d")
			style.border_color=Color("ddbc74") if state!="disabled" else Color("47525e")
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			style.content_margin_left=5
			style.content_margin_right=5
			button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_color",Color("fff0cd"))
		button.add_theme_color_override("font_disabled_color",Color("87949f"))
		button.focus_mode=Control.FOCUS_NONE
		button.tooltip_text="%s · 点击或按 %s 使用"%[Campaign.Items.item(id).name,KEYS[i]]
		button.pressed.connect(use_item.bind(id))
		add_child(button)
		buttons[id]=button
	Campaign.profile_changed.connect(refresh)
	refresh()

func refresh() -> void:
	visible=not get_tree().paused
	for i in ITEMS.size():
		var id: String=ITEMS[i]
		buttons[id].text="%s [%s]\n× %d"%[NAMES[i],KEYS[i],Campaign.item_count(id)]
		if id=="battle_overdrive":
			buttons[id].visible=Campaign.item_count(id)>0
			var left: float=Campaign.overdrive_remaining()
			buttons[id].text="破甲战歌 [5]\n"+("%d 秒"%ceili(left) if left>0 else ("本关已用" if Campaign.active_level>0 and bool(Campaign.level_state(Campaign.active_level).get("overdrive_used",false)) else "999真伤"))
		buttons[id].disabled=get_tree().paused or Dialogue.active or not Campaign.can_consume_item(id)

func use_item(id: String) -> void:
	if get_tree().paused or Dialogue.active: return
	Campaign.consume_item(id)
	refresh()
