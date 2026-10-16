extends "res://Characters/fixed_npc.gd"
@export_enum("guide","puzzle","tactics","merchant","medic","smith") var service_role: String="guide"
const TITLES={"puzzle":"刻文师·小篆","tactics":"战术员·岚","merchant":"补给员·小贝","medic":"医护员·青禾","smith":"工匠·阿锻"}
const COLORS={"guide":"9edfe6","puzzle":"d5a9ff","tactics":"eeaa88","merchant":"f0d283","medic":"90e6ae","smith":"c6c4ff"}
const ROLE_LABELS={"guide":"剧情向导","puzzle":"刻文师","tactics":"战术员","merchant":"补给商人","medic":"医护员","smith":"武器工匠"}
var service_label: Label
func _ready() -> void:
	level=get_parent()
	display_name=Story.npc_name(level.level_index) if service_role=="guide" else str(TITLES[service_role])
	super._ready()
	add_to_group("story_guides")
	animated_sprite.modulate=Color(COLORS[service_role])
	for child in get_children():
		if child is Label: service_label=child
	if service_label!=null:
		service_label.add_theme_color_override("font_color",Color(COLORS[service_role]))
		service_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		service_label.position.x=-60
		service_label.size.x=120
		service_label.text=ROLE_LABELS[service_role]

func _process(_delta: float) -> void:
	if service_label==null or not is_instance_valid(level.player): return
	var distance: float=position.distance_to(level.player.position)
	var nearest:=distance<45
	if nearest:
		for actor in get_tree().get_nodes_in_group("fixed_npcs"):
			if actor!=self and actor.get_parent()==level and actor.position.distance_to(level.player.position)<distance:
				nearest=false
				break
	service_label.text=display_name+" · E" if nearest else str(ROLE_LABELS[service_role])

func interact() -> void:
	if Dialogue.active or level.player.is_dead: return
	level.player.note_activity()
	Story.note_action("talk")
	var text:=""
	var options: Array=[]
	match service_role:
		"guide":
			text="我负责记录你们的旅程。机关找紫衣刻文师，补给找金衣小贝。" if level.level_index<18 else "我负责记录救援进展。战术找岚，补给找小贝。"
			options=[{"id":"recap","text":"重听本关剧情"},{"id":"mission","text":"确认当前目标"},{"id":"progress","text":"查看探索进度"},{"id":"journal","text":"打开旅程手册"}]
		"puzzle":
			text="我负责解读刻文。先给你一个思路，需要时再问，我会逐步说清楚。"
			options=[{"id":"mechanisms","text":"当前机关：给我下一条提示"},{"id":"method","text":"教我读懂这一关的机关"}]
		"tactics":
			text=tactical_advice()
			options=[{"id":"threat","text":"当前最该提防什么？"},{"id":"status","text":"查看本场战况"}]
		"merchant":
			text="我负责补给和交易。货物标着价格和等级，先检查背包；特殊通关奖励不在货架上。"
			options=[{"id":"items","text":"购买药品与防具"},{"id":"weapons","text":"购买武器"}]
		"medic":
			text="每个关卡我能免费包扎一次，为当前活着的角色恢复一半最大生命。倒下的同伴需回主场景用复苏晶石。"
			options=[{"id":"heal","text":"接受包扎 · 本关一次 · 免费"}]
		"smith":
			text="我强化你当前装备的武器，最高 +10。价格逐级增长，确认费用后再动工。"
			options=smith_options()
	Dialogue.open(display_name,[text],options,self,_story_choose)
	Global.play_sfx("potion")

func _story_choose(id: String) -> void:
	match id:
		"recap":
			Dialogue.close()
			Story.play_scene(level.level_index,"intro")
		"mission": Dialogue.reply(Story.entry(level.level_index).task)
		"progress": Dialogue.reply(level.objective_text() if level.level_index>=18 else "已打开 %d / %d 扇门。"%[Campaign.level_state(level.level_index).doors.size(),level.doors.size()])
		"mechanisms": Dialogue.reply(Story.hint(level.level_index))
		"method":
			var notes:=PackedStringArray()
			for mechanism in level.switches:
				if not mechanism.activated: notes.append(str(mechanism.config.label)+"："+str(mechanism.puzzle.get("clue","观察附近机关，先解除前置封印。")))
			Dialogue.reply("\n".join(notes) if not notes.is_empty() else "刻文都已解开。清除守卫，再按 E 打开尚未开启的门。")
		"threat": Dialogue.reply(tactical_advice())
		"status": Dialogue.reply(level.objective_text())
		"journal":
			Dialogue.close()
			Story.open_journal()
		"items", "weapons":
			Dialogue.close()
			preload("res://UI/shop_menu.gd").open(self,id)
		"heal":
			var state: Dictionary=Campaign.level_state(level.level_index)
			if state.get("medic_used",false): Dialogue.reply("这关的绷带已经用过了。剩下的路要靠你带的药品。")
			elif Campaign.profile.health<=0: Dialogue.reply("我不能复活倒下的角色，请回主场景使用复苏晶石。")
			elif Campaign.profile.health>=Campaign.player_stats().health: Dialogue.reply("你现在状态很好，绷带先留着，不消耗次数。")
			else:
				state.medic_used=true
				Campaign.profile.health=minf(Campaign.player_stats().health,Campaign.profile.health+Campaign.player_stats().health*.5)
				Campaign.profile.party_health[Campaign.profile.character]=Campaign.profile.health
				Campaign.profile_changed.emit()
				Campaign.save_progress()
				Dialogue.reply("包扎好了，恢复最多一半最大生命。这关的免费包扎已使用。")
		"upgrade":
			var weapon_id: String=Campaign.effective_weapon(str(Campaign.profile.character))
			var success:=Campaign.upgrade_weapon(weapon_id)
			Dialogue.show_page(display_name,"强化完成。" if success else "无法强化：请检查金币、持有状态和强化上限。",smith_options(),Dialogue.portrait.texture)

func smith_options() -> Array:
	var id: String=Campaign.effective_weapon(str(Campaign.profile.character))
	var weapon: Resource=preload("res://Weapons/weapon_registry.gd").get_weapon(id)
	return [{"id":"upgrade","text":"强化 %s +%d · %d 金币"%[weapon.weapon_name,Campaign.weapon_upgrade(id),Campaign.upgrade_cost(id)],"disabled":Campaign.weapon_upgrade(id)>=10 or Campaign.profile.coins<Campaign.upgrade_cost(id)}]

func tactical_advice() -> String:
	var index: int=level.level_index
	if index>=28: return str(Story.entry(index).clue)
	if index==26: return "Doro 在笼内免伤，不用替她挡攻击。四分钟以前持续增援，计时结束后仍要清完剩余敌人和首领。共振枪通关后才获得。"
	if index==27: return "没有时间限制。先清波次，再击败全部标记首领。凑企鹅完全体会召唤四只奶娃完全体；远离陨石落点与残留陨坑，共振枪能克制两类首领。"
	if index==24: return "坚持 180 秒并击败首领。Q 币企鹅由你操控，贯穿弹冷却 15 秒。此关试用不收钱，后续合同要回第三章主图购买。"
	if index>=22: return "奶娃完全体的狂笑音波会减速并持续伤害，先离开红色预警再反击；不要在危险区站着喝药。"
	if index>=20: return "奶娃小 BOSS 用手近攻，还会禁锢、减速。保持距离绕行；完全体还有大范围音波，别仅凭叫声判断强弱。"
	return "清空当前波才会刷新下一波。利用两波之间补药、换装备，避免贴墙被围住。左下入口锁定，通关后从右上出口离开。"
