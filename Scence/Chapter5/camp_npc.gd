extends "res://Scence/Chapter4/camp_npc.gd"
func service_name() -> String:
	return "渡火人" if service_role=="guide" else "余烬补给官"
func interact() -> void:
	var options: Array=[{"id":"story","text":"救援路线与当前进度"},{"id":"journal","text":"旅程手册"}] if service_role=="guide" else [{"id":"items","text":"补给、药品与复活道具"},{"id":"weapons","text":"查看商店武器"}]
	Dialogue.open(display_name,["这里是地狱的十座牢狱。左门不能返回，右门在清场后开启；Esc与传送卷轴随时可用。"],options,self,func(id):
		if id=="story": Dialogue.reply("5-1救凑企鹅；5-2初音、5-3灵梦加入；5-4音乐团告别。5-6、5-7、5-8分别找回Doro、咕嘎、糯糯，5-9与奥摩交易，5-10找回菲比。红色善攻、绿色厚甲、紫色禁锢。")
		else:
			Dialogue.close()
			if id=="journal": Story.open_journal()
			else: preload("res://UI/shop_menu.gd").open(self,id))
