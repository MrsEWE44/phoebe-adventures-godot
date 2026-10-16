extends "res://Characters/fixed_npc.gd"
## Neutral shopkeepers use the shared character class and the same modal dialogue.
@export_enum("help","items","weapons") var service := "help"

func _ready() -> void:
	if level == null:
		level = get_parent().get_parent()
	super._ready()
	animated_sprite.modulate = {"help":Color(.65,.95,1),"items":Color(.6,1,.7),"weapons":Color(1,.8,.55)}[service]

func interact() -> void:
	if Dialogue.active or level == null or level.player.is_dead:
		return
	level.player.note_activity()
	if service in ["items","weapons"]:
		preload("res://UI/shop_menu.gd").open(self,service)
		return
	var options: Array = []
	var text := "欢迎来到潮汐遗迹。海币：%d。" % int(Campaign.profile.coins)
	match service:
		"items":
			text += "药剂可重复购买；深潜护甲在第二章抵御额外伤害。"
			options = [{"id":"health","text":"生命药剂 +40 HP · 12 海币"},{"id":"energy","text":"技能药剂 +70 · 10 海币"},{"id":"ultimate","text":"绝杀药剂 +1 次 · 45 海币"},{"id":"diving_armor","text":"深潜护甲 · 70 海币"}]
		"weapons":
			text += "潮猎武器对水生怪物造成 1.6 倍伤害；鱼叉贯穿、三叉戟近战、鱼雷范围爆炸。"
			options = [{"id":"harpoon","text":"潮猎鱼叉枪 · 55 海币"},{"id":"coral_trident","text":"珊瑚三叉戟 · 65 海币"},{"id":"torpedo","text":"深海鱼雷炮 · 90 海币"}]
		"help":
			text += str(level.adventure.hint_text()) if level.get("adventure") != null else "沿石桥探索，靠近蓝色洞口进入关卡；封印按 2-1 至 2-10 依次解除。"
			options = [{"id":"seals","text":"如何解封和通关？"},{"id":"combat","text":"水下战斗有什么技巧？"},{"id":"team","text":"如何解锁篮球手？"}]
	Dialogue.open(display_name,[text],options,self,_shop_choice)

func _shop_choice(id: String) -> void:
	match id:
		"seals":
			Dialogue.reply(level.adventure.hint_text() if level.get("adventure") != null else "M 查看地图。金色圆环是机关，E 阅读线索；站稳踏板、旋转镜面或按顺序输入符文。每次解封会出现守卫、BOSS、宝箱或提供线索的 NPC。开启全部门并清场才算通关。最后开启的门必有 BOSS。")
		"combat":
			Dialogue.reply("鱼叉、三叉戟和鱼雷对水生怪物有 60% 伤害加成。红圈是 BOSS 预警，及时离开；气泡喷口周期爆发，启动对应机关可关闭。击败敌人获得海币和掉落，Q/R/T 使用药剂。")
		"team":
			Dialogue.reply("在 2-9 开启全部门并清场，再与坤坤对话救出他；他在海洋地图享有环境强化，适合挑战 2-10。Tab 切换存活队友。坤坤只用篮球：普攻可反弹；右键随机高伤直线传球或运球爆破突进，F 释放强化版篮球绝杀。角色倒下会由存活队友接替。")
		_:
			var bought := Campaign.purchase(id)
			Dialogue.reply(("购买成功！" if bought else ("已拥有该装备。" if id in Campaign.profile.weapons or (id=="diving_armor" and Campaign.profile.diving_armor) else "海币不足。"))+"当前海币：%d。药剂放入背包，武器购买后自动装备。" % int(Campaign.profile.coins))
