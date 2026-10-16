extends "res://Characters/fixed_npc.gd"
func _ready() -> void:
	level=get_parent().get_parent()
	display_name="冰原补给官"
	super._ready()
	animated_sprite.modulate=Color(.75,.9,1)
func interact() -> void:
	if Dialogue.active or level.player.is_dead: return
	level.player.note_activity()
	Dialogue.open(display_name,["这里的门由战斗试炼封锁。准备好补给，再从红色的 3-1 开始。海币：%d。"%Campaign.profile.coins],[{"id":"journal","text":"旅程手册与朋友线索"},{"id":"hire","text":"雇佣Q币企鹅下一场 · 120金币"},{"id":"store","text":"打开装备与武器商店"},{"id":"rules","text":"波次与限时救援"},{"id":"boss","text":"两种 BOSS 有什么弱点？"},{"id":"team","text":"角色救援与雇佣"},{"id":"health","text":"购买生命药剂 · 12 海币"},{"id":"energy","text":"购买能量药剂 · 10 海币"},{"id":"ultimate","text":"购买绝杀药剂 · 45 海币"}],self,_choose_ice)
func _choose_ice(id: String) -> void:
	match id:
		"journal":
			Dialogue.close()
			Story.open_journal()
		"hire": Dialogue.reply("下一场已预付，可以从角色页切换操控，进入下一场消耗合同。" if Campaign.hire_mercenary() else "需先通关3-7、持有120金币，且不能重复预付。")
		"store":
			Dialogue.close()
			preload("res://UI/shop_menu.gd").open(self,"weapons")
		"rules": Dialogue.reply("3-7 可切换操控Q币企鹅，坚持180秒并击败首领；通关后付费获得其它第三章关卡的操控资格。3-9 坚持240秒并清场后解锁Doro与静音共振枪；Doro在牢笼中不受伤害。共振枪对两种首领造成真伤、暴击和连锁伤害。3-10 没有时间限制，击败奶娃小BOSS、完全体及凑企鹅小BOSS、最终完全体才能解救咕嘎。")
		"boss": Dialogue.reply("奶娃小BOSS近战并禁锢；完全体会用狂笑音波减速、持续伤害。凑企鹅完全体会召唤四只奶娃，并使用陨石与飞踢。3-10必须击败全部标记首领；最终首领先倒下也不会跳过其余必需首领。")
		"team": Dialogue.reply("Q币企鹅是临时雇佣兵，不是永久同伴；仅第三章可雇佣并由玩家操控，120金币/次完整挑战。支付后按Tab或从背包切换；WASD移动、鼠标瞄准、左键AK47、F/V/右键贯穿弹，冷却15秒。Doro与咕嘎都是菲比的好朋友。3-9四分钟生存并清场解锁Doro和共振枪；3-10击败必需首领后打开咕嘎牢笼。")
		_:
			var bought:=Campaign.purchase(id)
			Dialogue.reply(("购买成功，按 B 查看背包。" if bought else "海币不足。")+"当前海币：%d。"%Campaign.profile.coins)
