extends Node
## Persistent campaign state. Leaving a challenge preserves its unfinished checkpoint.

signal progress_changed
signal profile_changed
signal message(text: String)
signal switch_activated(level_index: int, switch_id: String)
signal door_opened(level_index: int, door_id: String)
signal level_completed(level_index: int)
signal enemy_defeated

const Catalog = preload("res://Scence/Levels/catalog.gd")
const Items = preload("res://Combat/items.gd")
const Growth = preload("res://Characters/progression.gd")
const Shop = preload("res://Combat/shop_catalog.gd")
const SAVE_VERSION := 1
const MERCENARY_FEE:=120
const CHARACTER_IDS = ["phoebe","nuonuo","ikun","q_penguin","doro","gugu","mutsumi","soyo","anon","miku","reimu"]
const MUSIC_UNLOCKS = {28:"mutsumi",29:"soyo",30:"anon"}

var save_path := ""
var saving_enabled := true
var active_level: int = 0
var hub_chapter := 1
var completed: Array[int] = []
var states: Dictionary = {}
var profile: Dictionary = {}
var return_portal: StringName = &""
var transitioning := false
var save_error: String = ""
var _save_pending:=false
var _save_delay:=0.0
var save_write_count:=0
var _character_definitions: Dictionary={}

func player_level() -> int:
	return clampi(int(profile.get("player_level",Growth.TEST_START_LEVEL)),1,100)

func can_enter_chapter(chapter: int) -> bool:
	return player_level()>=Growth.chapter_requirement(chapter)

func encounter_level(index: int) -> int:
	var state:=level_state(index)
	if not state.has("combat_level"): state.combat_level=maxi(player_level(),Growth.enemy_level(index))
	return clampi(int(state.combat_level),1,100)

func migrate_enemy_record(record: Dictionary, index: int, hp_key: String, max_key: String) -> void:
	var version:=int(record.get("growth_version",0))
	if version>=Growth.BALANCE_VERSION: return
	var level:=encounter_level(index)
	var old_scale:=Growth.legacy_health(level)/100.0 if version==1 else 1.0
	var scale:=Growth.enemy_health_scale(level,str(record.get("species","")))/old_scale
	var previous_max:=float(record.get(max_key,record[hp_key]))
	record[max_key]=previous_max*scale
	record[hp_key]=clampf(float(record[hp_key])*scale,0,record[max_key])
	record.growth_version=Growth.BALANCE_VERSION

func player_stats(id: String="") -> Dictionary:
	var spec:=character_definition(str(profile.character) if id.is_empty() else id)
	var result: Dictionary=Growth.stats(player_level(),spec.max_health)
	var selected_id: String=str(profile.character) if id.is_empty() else id
	if selected_id in ["mutsumi","soyo","anon"] and 38 in completed:
		result.health*=1.4
		result.attack*=1.35
		result.defense*=1.3
	if selected_id in ["phoebe","nuonuo","doro","gugu"] and friendship_active():
		result.health*=1.5
		result.attack*=1.6
		result.defense*=1.5
	return result

func equipment_bonus(field: String) -> float:
	var value:=0.0
	for id in profile.get("equipment_slots",{}).values():
		if not str(id).is_empty(): value+=float(Items.item(id).get(field,0))
	return value

func player_defense(type: String) -> float:
	if type=="true": return 0.0
	var field:="physical_defense" if type=="physical" else "magic_defense"
	var bonus:=equipment_bonus(field)
	for id in ["armor","amulet","diving_armor"]:
		if profile.get(id,false) and (id!="diving_armor" or hub_chapter==2): bonus+=float(Items.item(id).get(field,0))
	return player_stats().defense+bonus*Growth.defense_scale(player_level())

func award_experience(enemy_level: int, boss:=false) -> void:
	if player_level()>=100: return
	var gap:=maxi(0,player_level()-enemy_level)
	var gain:=maxi(1,roundi((65.0 if boss else 12.0)/(1.0+gap*.35)))
	add_experience(gain)

func add_experience(amount: int) -> bool:
	if amount<=0 or player_level()>=Growth.MAX_LEVEL: return false
	profile.experience=int(profile.get("experience",0))+amount
	var before:=player_level()
	var ratios: Dictionary={}
	if profile.experience>=Growth.xp_required(before):
		for id in CHARACTER_IDS: ratios[id]=float(profile.party_health.get(id,0))/float(player_stats(id).health)
		ratios[profile.character]=float(profile.health)/float(player_stats().health)
	while player_level()<100 and profile.experience>=Growth.xp_required(player_level()):
		profile.experience-=Growth.xp_required(player_level())
		profile.player_level=player_level()+1
	if player_level()==100: profile.experience=0
	if player_level()!=before:
		for id in CHARACTER_IDS: profile.party_health[id]=player_stats(id).health*clampf(float(ratios[id]),0,1)
		profile.health=profile.party_health[profile.character]
		message.emit("升级！Lv.%d → Lv.%d，生命、攻击、防御已提升。"%[before,player_level()])
		progress_changed.emit()
	profile_changed.emit()
	request_save()
	return true

func upgrade_cost(id: String) -> int:
	return roundi(80*pow(1.55,weapon_upgrade(id)))

func upgrade_weapon(id: String) -> bool:
	if id not in profile.weapons and id!=character_definition(str(profile.character)).default_weapon: return false
	if weapon_upgrade(id)>=10 or int(profile.coins)<upgrade_cost(id): return false
	profile.coins-=upgrade_cost(id)
	profile.weapon_upgrades[id]=weapon_upgrade(id)+1
	profile_changed.emit()
	save_progress()
	return true

func destroy_weapon(id: String) -> bool:
	if id=="penguin_rock": return false
	if id not in profile.weapons: return false
	profile.weapons.erase(id)
	profile.weapon_upgrades.erase(id)
	if profile.equipped==id: profile.equipped="fists"
	profile_changed.emit()
	save_progress()
	return true

func equip_item(id: String) -> bool:
	if id not in profile.equipment_owned: return false
	var slot: String=Items.item(id).get("slot","")
	if slot.is_empty(): return false
	profile.equipment_slots[slot]="" if profile.equipment_slots.get(slot)==id else id
	profile_changed.emit()
	save_progress()
	return true

func item_count(id: String) -> int:
	if id=="time_capsule": return 1 if profile.get("hell",{}).get("capsule",false) else 0
	if id=="battle_overdrive": return 1 if 32 in completed else 0
	if id=="travel_scroll": return 1 if travel_scroll_unlocked() else 0
	var key: String={"health":"health_potions","energy":"energy_potions","ultimate":"ultimate_potions"}.get(id,"")
	if not key.is_empty(): return int(profile.get(key,0))
	if id in ["health_large","energy_large","elixir","revival_stone","experience_crystal"]: return int(profile.bag.get(id,0))
	return 1 if id in profile.weapons or id in profile.equipment_owned or bool(profile.get(id,false)) else 0

func can_consume_item(id: String) -> bool:
	if id=="battle_overdrive": return 32 in completed and active_level>0 and float(profile.health)>0 and not bool(level_state(active_level).get("overdrive_used",false)) and not bool(level_state(active_level).get("arena",{}).get("finished",false)) and not bool(level_state(active_level).get("arena",{}).get("failed",false))
	if id=="revival_stone": return active_level==0 and item_count(id)>0 and not fallen_characters().is_empty()
	if float(profile.health)<=0 or item_count(id)<=0: return false
	if id=="experience_crystal": return player_level()<Growth.MAX_LEVEL
	if id in ["health","health_large"]: return profile.health<player_stats().health
	if id in ["energy","energy_large"]: return profile.energy<character_definition(str(profile.character)).max_energy
	if id=="elixir": return profile.health<player_stats().health or profile.energy<character_definition(str(profile.character)).max_energy
	if id=="ultimate": return profile.character!="q_penguin" and ultimate_charges(str(profile.character))<character_definition(str(profile.character)).ultimate.max_charges
	return false

func consume_item(id: String) -> bool:
	if not can_consume_item(id): return false
	if id=="battle_overdrive":
		level_state(active_level).overdrive_used=true
		level_state(active_level).overdrive_remaining=30.0
		message.emit("破甲战歌生效：30秒内对敌人的攻击造成999真伤；本次挑战已使用。")
		Global.play_sfx("potion")
		profile_changed.emit()
		save_progress()
		return true
	if id=="experience_crystal":
		profile.bag[id]-=1
		add_experience(int(Items.item(id).experience))
		message.emit("经验结晶：获得 %d 经验。"%int(Items.item(id).experience))
		Global.play_sfx("potion")
		save_progress()
		return true
	if id=="revival_stone": return revive_character(fallen_characters()[0])
	if id=="ultimate": return consume_ultimate_potion()
	if id in ["health","energy"]: return consume_potion(id=="health")
	if float(profile.health)<=0 or int(profile.bag.get(id,0))<=0: return false
	var item:=Items.item(id)
	var health_gain: float=float(player_stats().health)*float(item.get("health_ratio",0))
	var energy_gain: int=int(item.get("energy_restore",0))
	if (health_gain==0 or profile.health>=player_stats().health) and (energy_gain==0 or profile.energy>=200): return false
	profile.bag[id]-=1
	profile.health=minf(player_stats().health,float(profile.health)+health_gain)
	profile.energy=mini(200,int(profile.energy)+energy_gain)
	Story.note_action("potion")
	profile_changed.emit()
	Global.play_sfx("potion")
	save_progress()
	return true

func overdrive_remaining() -> float:
	if active_level<=0: return 0.0
	return maxf(0.0,float(level_state(active_level).get("overdrive_remaining",0.0)))

func end_overdrive() -> void:
	if active_level>0: level_state(active_level).overdrive_remaining=0.0


func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	save_path=Storage.save_file()
	# Test scripts use isolated files and never touch the real player's save.
	if OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s"):
		saving_enabled = false
	reset_state(1)
	if saving_enabled:
		load_progress()


func reset_state(start_level: int = Growth.TEST_START_LEVEL) -> void:
	active_level = 0
	hub_chapter = 1
	completed.clear()
	states.clear()
	profile = {"health": 100, "energy": 200, "character": "phoebe", "nuonuo_unlocked": false,
		"weapons": [], "equipped": "fists", "armor": false, "amulet": false,
		"health_potions": 0, "energy_potions": 0, "ultimate_potions": 0, "kills": 0,
		"coins": 0, "ikun_unlocked": false, "diving_armor": false, "weapon_upgrades": {},
		"ultimate_charges": {"phoebe":3,"nuonuo":3,"ikun":3}}
	profile.party_health = {"phoebe":100,"nuonuo":100,"ikun":100,"q_penguin":100,"doro":400,"gugu":150}
	for id in ["q_penguin","doro","gugu"]: profile[id+"_unlocked"]=false
	profile.player_level=clampi(start_level,1,Growth.MAX_LEVEL)
	profile.experience=0
	profile.progression_version=Growth.BALANCE_VERSION
	profile.mercenary_prepaid=false
	profile.resonance_unlocked=false
	profile.q_skill_cooldown=0.0
	profile.last_defeat_level=0
	profile.travel_scroll_unlocked=false
	profile.bag={}
	profile.story={}
	profile.hell={"omo_choice":"","capsule":false,"music_departed":false,"friendship":false}
	profile.miku_unlocked=false
	profile.reimu_unlocked=false
	profile.music_forms={"glasses":false,"dragon":false,"soyo_full":false,"tensura_rescued":false}
	profile.equipment_owned=[]
	profile.equipment_slots={"body":"","feet":"","charm":""}
	for id in CHARACTER_IDS: profile.party_health[id]=player_stats(id).health
	profile.health=profile.party_health.phoebe
	transitioning = false
	save_error = ""
	return_portal = &""
	_save_pending=false
	_save_delay=0.0

func restart_campaign() -> bool:
	if transitioning: return false
	var previous := {"profile":profile.duplicate(true),"states":states.duplicate(true),"completed":completed.duplicate(),"active":active_level,"chapter":hub_chapter,"portal":return_portal}
	# A confirmed new campaign starts from base stats, independent of test defaults.
	reset_state(1)
	if not save_progress():
		profile = previous.profile
		states = previous.states
		completed.assign(previous.completed)
		active_level = previous.active
		hub_chapter = previous.chapter
		return_portal = previous.portal
		return false
	# The recovery save must also be fresh, so corrupting the main file cannot
	# resurrect progress that the player explicitly reset.
	if saving_enabled and FileAccess.file_exists(save_path):
		var error := DirAccess.copy_absolute(save_path,save_path+".bak")
		if error != OK and FileAccess.file_exists(save_path+".bak"):
			error = DirAccess.remove_absolute(save_path+".bak")
		if error != OK:
			save_error = "新存档已保存，但旧备份无法清理："+error_string(error)
			message.emit(save_error)
			return false
	get_tree().paused = false
	return _change_scene(Catalog.hub_path(1))


func unlocked_level() -> int:
	var next := 1
	while next in completed and next < Catalog.TOTAL_LEVELS:
		next += 1
	return next


func is_unlocked(index: int) -> bool:
	if index<1 or index>Catalog.TOTAL_LEVELS or not can_enter_chapter(Catalog.chapter(index)): return false
	# The ocean hub can be explored immediately; its ten stages form a separate chain.
	if index >= 8 and index <= Catalog.TOTAL_LEVELS:
		return index in [8,18,28,38] or index - 1 in completed
	return index >= 1 and index <= mini(7,unlocked_level())


func level_state(index: int) -> Dictionary:
	var key := str(index)
	if not states.has(key):
		states[key] = {"switches": [], "doors": [], "position": [], "rescued": false}
	for field in ["opened_chests","bosses_defeated"]:
		if not states[key].get(field) is Array:
			states[key][field] = []
	return states[key]


func enter_level(index: int) -> bool:
	if float(profile.health)<=0:
		message.emit("请先在主场景复活角色，或选择重新挑战。")
		return false
	if transitioning or not is_unlocked(index):
		message.emit("先开启上一关的全部门，才能解除这里的封印。")
		return false
	if index==37:
		for id in ["ikun","soyo"]:
			var hp: float=float(profile.health) if profile.character==id else float(profile.party_health.get(id,0))
			if not profile.get(id+"_unlocked",false) or hp<=0:
				message.emit("最终合奏需要坤坤与soyo狸存活。请先返回主场景，使用复苏晶石整备队伍。")
				return false
	if index>=18 and index in completed:
		states.erase(str(index))
		level_state(index).cleared_before=true
	active_level = index
	hub_chapter = Catalog.chapter(index)
	ensure_character_allowed()
	return_portal = Catalog.PORTAL_ORDER[index - 1]
	save_progress()
	return _change_scene(Catalog.scene_path(index))


func unfinished_attempt() -> bool:
	if active_level<=0: return false
	if active_level>=18: return not bool(level_state(active_level).get("arena",{}).get("finished",false))
	return not exploration_cleared(active_level)

func resume_level() -> bool:
	if unfinished_attempt():
		return _change_scene(Catalog.scene_path(active_level))
	return false


func return_to_hub() -> bool:
	if transitioning: return false
	remember_travel_unlock()
	snapshot_active_attempt()
	end_overdrive()
	if active_level > 0:
		return_portal = Catalog.PORTAL_ORDER[active_level - 1]
	active_level = 0
	ensure_character_allowed()
	get_tree().paused=false
	save_progress()
	return _change_scene(Catalog.hub_path(hub_chapter))

func travel_scroll_unlocked() -> bool:
	return bool(profile.get("travel_scroll_unlocked",false)) or hub_chapter==4 or active_level>=28 or completed.any(func(index):return index>=28)

func remember_travel_unlock() -> void:
	if travel_scroll_unlocked(): profile.travel_scroll_unlocked=true

func snapshot_active_attempt() -> void:
	if active_level<=0: return
	for actor in get_tree().get_nodes_in_group("players"):
		var world:=actor.get_parent()
		if world.get("level_index")!=active_level: continue
		if world.get("adventure")!=null: world.adventure.snapshot()
		if world.has_method("snapshot"): world.snapshot()
		level_state(active_level).position=[actor.position.x,actor.position.y]
		break

func use_travel_scroll(chapter: int) -> bool:
	if transitioning or not travel_scroll_unlocked() or chapter<1 or chapter>5 or not can_enter_chapter(chapter) or float(profile.health)<=0: return false
	remember_travel_unlock()
	snapshot_active_attempt()
	end_overdrive()
	active_level=0
	hub_chapter=chapter
	return_portal=&""
	ensure_character_allowed()
	get_tree().paused=false
	save_progress()
	return _change_scene(Catalog.hub_path(chapter))

func retry_current_level() -> bool:
	if transitioning or active_level<=0: return false
	remember_travel_unlock()
	get_tree().paused=false
	return recover_from_defeat(active_level,true)

func travel_to_hub(chapter_id: int) -> bool:
	if not can_enter_chapter(chapter_id):
		message.emit("进入第 %d 章需要 Lv.%d。"%[chapter_id,Growth.chapter_requirement(chapter_id)])
		return false
	if transitioning or unfinished_attempt():
		return false
	hub_chapter = clampi(chapter_id,1,5)
	ensure_character_allowed()
	active_level = 0
	return_portal = &""
	save_progress()
	return _change_scene(Catalog.hub_path(hub_chapter))


func _change_scene(path: String) -> bool:
	transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		transitioning = false
		message.emit("关卡加载失败：%s" % error_string(error))
		return false
	return true


func scene_ready() -> void:
	transitioning = false
	remember_travel_unlock()


func activate_switch(index: int, id: String) -> void:
	var state := level_state(index)
	if id not in state.switches:
		state.switches.append(id)
		switch_activated.emit(index,id)
		save_progress()
		progress_changed.emit()


func open_door(index: int, id: String) -> void:
	if id not in Catalog.all_door_ids(index):
		return
	var state := level_state(index)
	if id not in state.doors:
		state.doors.append(id)
		door_opened.emit(index,id)
		save_progress()
		progress_changed.emit()
	check_completion(index)


func exploration_cleared(index: int) -> bool:
	if index<1 or index>=18: return false
	var ids := Catalog.all_door_ids(index)
	if ids.is_empty():
		return false
	var state := level_state(index)
	for id in ids:
		if id not in state.doors:
			return false
	if not encounters_cleared(index):
		return false
	if index in [6,16] and not bool(state.get("rescued",false)):
		return false
	return true

func check_completion(index: int) -> bool:
	if index>=18: return complete_arena(index)
	if not exploration_cleared(index): return false
	if index not in completed:
		completed.append(index)
		completed.sort()
		profile.coins = int(profile.coins) + (60 if index >= 8 else 30)
		if index == 16:
			profile.ikun_unlocked = true
			profile_changed.emit()
		save_progress()
		progress_changed.emit()
		level_completed.emit(index)
		message.emit("%s 通关！%s" % [Catalog.label(index), "篮球手坤坤已加入队伍，Tab 切换！" if index==16 else ("糯糯已加入队伍。" if index == 6 else "下一关的封印已解除，获得通关海币。")])
	return true

func second_chapter_complete() -> bool:
	for index in range(8,18):
		if index not in completed:
			return false
	return true

func complete_arena(index: int) -> bool:
	if not bool(level_state(index).get("arena",{}).get("finished",false)): return false
	level_state(index).overdrive_remaining=0.0
	if index not in completed:
		completed.append(index)
		completed.sort()
		profile.coins+=100
		var id: String={24:"q_penguin",26:"doro",27:"gugu"}.get(index,"")
		if not id.is_empty():
			profile[id+"_unlocked"]=true
			profile.party_health[id]=player_stats(id).health
		if index==27 and "penguin_rock" not in profile.weapons: profile.weapons.append("penguin_rock")
		if index==26 and not profile.resonance_unlocked:
			profile.resonance_unlocked=true
			if "resonance_disruptor" not in profile.weapons: profile.weapons.append("resonance_disruptor")
		apply_music_rewards(index)
		if index>=38: apply_hell_rewards(index)
		profile_changed.emit()
		progress_changed.emit()
		level_completed.emit(index)
		save_progress()
	return true

func character_allowed(id: String) -> bool:
	if active_level==37 and bool(level_state(37).get("arena",{}).get("ensemble_active",false)) and not bool(level_state(37).get("arena",{}).get("finished",false)): return id=="ikun"
	if id in ["mutsumi","soyo","anon"] and 41 in completed and hub_chapter!=4: return false
	if id in ["phoebe","nuonuo","doro","gugu"] and 28 in completed:
		return int({"doro":43,"gugu":44,"nuonuo":45,"phoebe":47}[id]) in completed
	if id=="q_penguin":
		if hub_chapter!=3: return false
		return active_level==24 or bool(profile.get("mercenary_prepaid",false)) or (active_level>=18 and bool(level_state(active_level).get("arena",{}).get("q_contract",false)))
	var allowed: Array=character_definition(id).allowed_chapters
	return allowed.is_empty() or hub_chapter in allowed

func apply_music_rewards(index: int) -> void:
	if MUSIC_UNLOCKS.has(index):
		var id: String=MUSIC_UNLOCKS[index]
		profile[id+"_unlocked"]=true
		profile.party_health[id]=player_stats(id).health
	if index==31: profile.music_forms.glasses=true
	if index==32:
		profile.music_forms.dragon=true
		message.emit("解锁破甲战歌！按5或在背包使用：30秒999真伤，每次挑战一次。")
	if index==33 and "music_drums" not in profile.weapons: profile.weapons.append("music_drums")
	if index==35 and "conductor" not in profile.weapons: profile.weapons.append("conductor")
	if index==36:
		profile.music_forms.tensura_rescued=true
		profile.music_forms.soyo_full=true
		profile.party_health.soyo=player_stats("soyo").health
		if profile.character=="soyo": profile.health=profile.party_health.soyo
	ensure_character_allowed()

func character_restriction(id: String) -> String:
	if id in ["mutsumi","soyo","anon"] and 41 in completed: return "巡演离队 · 仅第四章重玩"
	if id=="q_penguin": return "仅第三章雇佣"
	if id in ["phoebe","nuonuo","doro","gugu"]: return "暂时离队"
	return "合奏期间不可切换"

func character_unlock_hint(id: String) -> String:
	return {"miku":"5-2救援：大葱音波禁锢与持续伤害","reimu":"5-3救援：赤月镰刀环击，F三倍领域","phoebe":"初始角色；5-10回归","nuonuo":"1-6 救援解锁","ikun":"2-9 救援解锁","q_penguin":"第三章临时雇佣兵，3-7 开放资格；按场付费","doro":"3-9 救援解锁，固定橘子","gugu":"3-10 救援解锁，固定石头","mutsumi":"4-1 救援：粉色大提琴范围声波","soyo":"4-2 救援：直线共振；4-9 完全体固定指挥棒","anon":"4-3 救援；4-4 眼镜强化；4-5 奶龙同化奶娃"}.get(id,"")

func ensure_character_allowed() -> void:
	remember_travel_unlock()
	# Keep the current character through 4-1; ensure Ikun is available after departure.
	if hub_chapter>=4: profile.ikun_unlocked=true
	if character_allowed(str(profile.character)): return
	profile.party_health[profile.character]=float(profile.health)
	var replacement:="ikun" if hub_chapter==4 or 28 in completed else "phoebe"
	for id in party_ids():
		if float(profile.party_health.get(id,0))>0:
			replacement=id
			break
	profile.character=replacement
	profile.health=maxf(0,float(profile.party_health.get(replacement,100)))
	profile_changed.emit()

func party_ids() -> Array[String]:
	var ids: Array[String] = []
	if character_allowed("phoebe"): ids.append("phoebe")
	if profile.nuonuo_unlocked and character_allowed("nuonuo"):
		ids.append("nuonuo")
	if profile.ikun_unlocked and character_allowed("ikun"):
		ids.append("ikun")
	for id in ["doro","gugu"]:
		if profile.get(id+"_unlocked",false) and character_allowed(id): ids.append(id)
	for id in MUSIC_UNLOCKS.values()+["miku","reimu"]:
		if profile.get(id+"_unlocked",false) and character_allowed(id): ids.append(id)
	if (profile.get("q_penguin_unlocked",false) or active_level==24) and character_allowed("q_penguin"): ids.append("q_penguin")
	return ids

func fallen_characters() -> Array[String]:
	var ids: Array[String]=[]
	var candidates:=party_ids()
	if active_level==0 and hub_chapter==3 and profile.q_penguin_unlocked and "q_penguin" not in candidates: candidates.append("q_penguin")
	for id in candidates:
		var hp: float=profile.health if id==profile.character else profile.party_health.get(id,0)
		if hp<=0: ids.append(id)
	return ids

func revive_character(id: String) -> bool:
	if active_level!=0 or item_count("revival_stone")<=0 or id not in fallen_characters(): return false
	# A dead escort is a failed objective, not a fallen playable party member.
	if active_level>=18 and level_state(active_level).get("arena",{}).get("failed",false): return false
	profile.bag.revival_stone-=1
	profile.party_health[id]=player_stats(id).health
	if float(profile.health)<=0 and character_allowed(id): profile.character=id
	if id==profile.character:
		profile.health=profile.party_health[id]
		profile.energy=character_definition(id).max_energy
	profile_changed.emit()
	if id==profile.character:
		for actor in get_tree().get_nodes_in_group("players"):
			if actor.has_method("revive_from_item"): actor.revive_from_item()
	Global.play_sfx("potion")
	message.emit("%s 已复活，生命完全恢复。"%character_definition(id).display_name)
	save_progress()
	return true

func can_hire_mercenary() -> bool:
	if hub_chapter!=3 or not profile.get("q_penguin_unlocked",false) or profile.get("mercenary_prepaid",false) or profile.coins<MERCENARY_FEE: return false
	if active_level>=18 and unfinished_attempt(): return false
	return true

func hire_mercenary() -> bool:
	if not can_hire_mercenary(): return false
	profile.coins-=MERCENARY_FEE
	profile.mercenary_prepaid=true
	profile_changed.emit()
	save_progress()
	message.emit("已支付 %d 金币：可在背包或 Tab 切换操控 Q 币企鹅，合同覆盖下一次第三章挑战。"%MERCENARY_FEE)
	return true

func purchase(id: String) -> bool:
	if not Shop.STOCK.has(id) or not Items.has_item(id): return false
	var offer: Dictionary=Shop.STOCK[id]
	if player_level()<int(offer.level):
		message.emit("需要 Lv.%d 才能购买此物品。"%offer.level)
		return false
	if id in profile.weapons or id in profile.equipment_owned or (Items.item(id).kind in ["armor","amulet","equipment"] and profile.get(id,false)):
		message.emit("已经拥有这件装备。")
		return false
	if int(profile.coins)<int(offer.price):
		message.emit("游戏币不足。")
		return false
	profile.coins-=int(offer.price)
	grant_drop(id)
	return true


func rescue_nuonuo() -> bool:
	return rescue_companion("nuonuo")

func rescue_companion(id: String) -> bool:
	var index := 6 if id=="nuonuo" else 16
	if id not in ["nuonuo","ikun"] or active_level!=index: return false
	var state := level_state(index)
	if not encounters_cleared(index): return false
	for door in Catalog.all_door_ids(index):
		if door not in state.doors: return false
	state.rescued = true
	profile[id+"_unlocked"] = true
	profile_changed.emit()
	return check_completion(index)

func weapon_upgrade(id: String) -> int:
	return clampi(int(profile.get("weapon_upgrades",{}).get(id,0)),0,10)

func weapon_multiplier(id: String) -> float:
	return 1.0+.10*weapon_upgrade(id)

func claim_encounter_gift(index: int, room_id: String) -> String:
	var room: Dictionary = level_state(index).get("encounters",{}).get(room_id,{})
	if room.is_empty() or room.get("kind")!="npc": return "这里没有可以领取的礼物。"
	if room.get("gift_claimed",false): return str(room.get("gift_text","我们已经聊过了，祝你一路顺风。"))
	room.gift_claimed = true
	var text := "我研究了一整天：门之所以能打开，是因为它没有关着。好了，祝你好运！"
	match str(room.get("gift_kind","chatter")):
		"item", "weapon":
			var item_id := str(room.get("gift_id","health"))
			item_id=preload("res://Weapons/weapon_registry.gd").level_reward(index,item_id)
			grant_drop(item_id)
			text = "这件%s送给你。它已放进背包，继续探索吧。" % Items.item(item_id).name
		"upgrade":
			var id: String = effective_weapon()
			var rank := weapon_upgrade(id)
			if rank<10:
				profile.weapon_upgrades[id] = rank+1
				text = "%s已强化至 +%d，累计增加 %d%% 伤害。" % [Items.item(id).name,rank+1,(rank+1)*20]
			else: text = "你的武器已经强化到 +10，我的手艺暂时帮不上忙。"
	room.gift_text = text
	profile_changed.emit()
	save_progress()
	return text


func checkpoint(index: int, position: Vector2) -> void:
	level_state(index).position = [position.x, position.y]
	save_progress()


func grant_drop(id: String, immediate_save:=true) -> void:
	if not Items.has_item(id):
		return
	match str(Items.item(id).kind):
		"melee", "ranged":
			if id not in profile.weapons:
				profile.weapons.append(id)
			if profile.equipped=="fists" and can_equip_weapon(id): profile.equipped = id
		"gear":
			if id not in profile.equipment_owned: profile.equipment_owned.append(id)
			var slot: String=Items.item(id).slot
			if profile.equipment_slots.get(slot,"").is_empty(): profile.equipment_slots[slot]=id
		"armor", "amulet", "equipment":
			profile[id] = true
		"consumable":
			if id not in ["health","energy","ultimate"]:
				profile.bag[id]=int(profile.bag.get(id,0))+1
				message.emit("获得：" + str(Items.item(id).name)+" · B 背包中使用")
				profile_changed.emit()
				if immediate_save: save_progress()
				else: request_save()
				return
			var key: String = {"health":"health_potions","energy":"energy_potions","ultimate":"ultimate_potions"}.get(id,"energy_potions")
			profile[key] = int(profile[key]) + 1
	message.emit("获得：" + str(Items.item(id).name))
	profile_changed.emit()
	if immediate_save: save_progress()
	else: request_save()


func consume_potion(health_potion: bool) -> bool:
	if float(profile.health)<=0: return false
	var key := "health_potions" if health_potion else "energy_potions"
	var stat := "health" if health_potion else "energy"
	var spec := character_definition(str(profile.character))
	var limit: float = player_stats().health if health_potion else spec.max_energy
	if int(profile[key]) <= 0 or float(profile[stat]) >= limit:
		message.emit("没有可用药剂，或状态已满。")
		return false
	profile[key] = int(profile[key]) - 1
	if float(profile.health)<=0: return false
	profile[stat] = minf(limit, float(profile[stat]) + (limit*.4 if health_potion else 70))
	Story.note_action("potion")
	Global.play_sfx("potion")
	profile_changed.emit()
	save_progress()
	return true


func switch_character() -> bool:
	return select_character(next_survivor())

func select_character(id: String) -> bool:
	for actor in get_tree().get_nodes_in_group("players"):
		if (actor.is_dead and active_level!=0) or (actor.has_method("is_action_locked") and actor.is_action_locked()):
			return false
	if id.is_empty() or id not in party_ids() or id == str(profile.character) or float(profile.party_health.get(id,100)) <= 0:
		message.emit("该角色尚未解锁、已倒下或不适用于当前章节。Q 币企鹅需先支付本场费用。")
		return false
	var was_dead:=float(profile.health)<=0
	profile.party_health[profile.character] = float(profile.health)
	profile.character = id
	if id=="gugu" and "penguin_rock" in profile.weapons: profile.equipped="penguin_rock"
	var spec := character_definition(str(profile.character))
	profile.health = minf(float(profile.party_health.get(profile.character,player_stats().health)),player_stats().health)
	profile.energy = mini(int(profile.energy),spec.max_energy)
	profile_changed.emit()
	if was_dead:
		for actor in get_tree().get_nodes_in_group("players"):
			if actor.has_method("revive_from_item"): actor.revive_from_item()
	save_progress()
	return true

func equip_weapon(id: String) -> bool:
	if not can_equip_weapon(id):
		message.emit("当前角色只能使用自己的专属武器；其它武器保留在共享背包。")
		return false
	if id != "fists" and id not in profile.weapons:
		return false
	for actor in get_tree().get_nodes_in_group("players"):
		if actor.is_dead or (actor.has_method("is_action_locked") and actor.is_action_locked()):
			return false
	profile.equipped = id
	profile_changed.emit()
	save_progress()
	return true


func cycle_weapon() -> void:
	if not character_definition(str(profile.character)).allowed_weapons.is_empty():
		message.emit("当前角色使用专属武器："+Items.item(effective_weapon()).name)
		return
	if profile.weapons.is_empty():
		message.emit("击败怪物，拾取掉落的武器。")
		return
	var choices: Array = (["fists"]+profile.weapons).filter(func(id): return can_equip_weapon(id))
	var index: int = choices.find(profile.equipped)
	profile.equipped = choices[(index + 1) % choices.size()]
	profile_changed.emit()
	save_progress()

func can_equip_weapon(id: String, character_id := "") -> bool:
	var spec:=character_definition(str(profile.character) if character_id.is_empty() else character_id)
	if spec.character_id=="soyo_full": return id in ["conductor","fists"]
	var resolved: String=spec.default_weapon if id=="fists" else id
	if resolved=="q_ak": return spec.character_id=="q_penguin"
	if resolved=="penguin_rock": return spec.character_id=="gugu" and profile.gugu_unlocked
	return spec.allowed_weapons.is_empty() or resolved in spec.allowed_weapons

func effective_weapon(character_id := "") -> String:
	var selected: String=str(profile.character) if character_id.is_empty() else character_id
	var spec:=character_definition(selected)
	if selected=="soyo" and bool(profile.get("music_forms",{}).get("soyo_full",false)): return "conductor"
	return str(profile.equipped) if profile.equipped!="fists" and can_equip_weapon(str(profile.equipped),selected) else str(spec.default_weapon)

func character_definition(character_id: String) -> Resource:
	if character_id=="soyo" and bool(profile.get("music_forms",{}).get("soyo_full",false)): character_id="soyo_full"
	if character_id=="anon":
		var forms: Dictionary=profile.get("music_forms",{})
		if forms.get("dragon",false): character_id="anon_dragon"
		elif forms.get("glasses",false): character_id="anon_glasses"
	if _character_definitions.has(character_id): return _character_definitions[character_id]
	var path := "res://Characters/Definitions/%s.tres" % character_id
	var resource: Resource=load(path) if ResourceLoader.exists(path) else preload("res://Characters/Definitions/phoebe.tres")
	_character_definitions[character_id]=resource
	return resource

func ultimate_charges(character_id: String) -> int:
	if character_id=="q_penguin": return 1 # Cooldown-only skill, never consumes charges.
	var spec: Resource = character_definition(character_id).ultimate
	return clampi(int(profile.ultimate_charges.get(character_id,spec.initial_charges)),0,spec.max_charges) if spec != null else 0

func consume_ultimate_potion() -> bool:
	if profile.character=="q_penguin":
		message.emit("Q币企鹅的贯穿弹头按15秒冷却恢复，无需绝杀药剂。")
		return false
	var id := str(profile.character)
	var spec: Resource = character_definition(id).ultimate
	if spec == null or int(profile.ultimate_potions)<=0 or ultimate_charges(id)>=spec.max_charges:
		message.emit("没有绝杀药剂，或大招次数已达到上限。")
		return false
	profile.ultimate_potions = int(profile.ultimate_potions)-1
	profile.ultimate_charges[id] = mini(spec.max_charges,ultimate_charges(id)+1)
	Global.play_sfx("potion")
	profile_changed.emit()
	save_progress()
	return true

func claim_chest(index: int, id: String, item_id: String) -> bool:
	var state := level_state(index)
	item_id=preload("res://Weapons/weapon_registry.gd").level_reward(index,item_id)
	if id in state.opened_chests or not Items.has_item(item_id):
		return false
	state.opened_chests.append(id)
	Story.note_action("chest")
	# Reward and opened flag enter the same save, avoiding lost or duplicated loot.
	grant_drop(item_id)
	return true


func request_save() -> void:
	profile.party_health[profile.character]=float(profile.health)
	if not saving_enabled: return
	if not _save_pending: _save_delay=.25
	_save_pending=true

func _process(delta: float) -> void:
	if active_level>0 and overdrive_remaining()>0 and not get_tree().paused:
		var left:=maxf(0.0,overdrive_remaining()-delta) if float(profile.health)>0 else 0.0
		level_state(active_level).overdrive_remaining=left
		if left<=0:
			profile_changed.emit()
			request_save()
	if not _save_pending: return
	_save_delay-=delta
	if _save_delay<=0: save_progress()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_APPLICATION_PAUSED:
		if _save_pending: save_progress()

func _exit_tree() -> void:
	if _save_pending: save_progress()

func save_progress() -> bool:
	_save_pending=false
	profile.party_health[profile.character] = float(profile.health)
	if not saving_enabled:
		return true
	var data := {"version": SAVE_VERSION, "active_level": active_level, "hub_chapter":hub_chapter, "completed": completed, "states": states, "profile": profile}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "无法写入存档：" + error_string(FileAccess.get_open_error())
		message.emit(save_error)
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var error := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK:
		save_error = "存档替换失败：" + error_string(error)
		message.emit(save_error)
		return false
	save_error = ""
	save_write_count+=1
	return true


func load_progress() -> bool:
	var data: Variant = null
	for path in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION:
				data = parsed
				break
	if not data is Dictionary:
		return false
	reset_state()
	hub_chapter=clampi(int(data.get("hub_chapter",1)),1,5)
	if data.get("states") is Dictionary:
		states = data.states
	# Rebuild completion in order from the actual saved door flags.
	for index in range(1, Catalog.TOTAL_LEVELS+1):
		var state: Variant = states.get(str(index), {})
		if not state is Dictionary or not state.get("doors") is Array or not state.get("switches") is Array:
			states.erase(str(index))
			continue
		state["rescued"] = bool(state.get("rescued", false))
		# Upgrade older completed penultimate levels without removing earned progress.
		var previously_completed := false
		for value in data.get("completed",[]) if data.get("completed") is Array else []:
			if int(value)==index: previously_completed=true
		if index in [6,16] and int(state.get("adventure_version",0))<3 and previously_completed:
			state.rescued = true
		if not state.get("position") is Array or state.position.size() != 2:
			state["position"] = []
		var ids := Catalog.all_door_ids(index)
		var done: bool = not ids.is_empty() and (index not in [6,16] or state.rescued)
		for id in ids:
			done = done and id in state.doors
		if index>=18: done=bool(state.get("arena",{}).get("finished",false)) or bool(state.get("cleared_before",false))
		else: done = (done and encounters_cleared(index)) or bool(state.get("cleared_before",false))
		if done and (index in [1,8,18,28,38] or index - 1 in completed):
			completed.append(index)
	if data.get("profile") is Dictionary:
		var source: Dictionary = data.profile
		preload("res://Weapons/weapon_registry.gd").migrate_inventory(source)
		if source.get("hell") is Dictionary: profile.hell.merge(source.hell,true)
		if source.get("story") is Dictionary: profile.story=source.story.duplicate(true)
		profile.last_defeat_level=clampi(int(source.get("last_defeat_level",0)),0,Catalog.TOTAL_LEVELS)
		profile.travel_scroll_unlocked=bool(source.get("travel_scroll_unlocked",false))
		profile.mercenary_prepaid=bool(source.get("mercenary_prepaid",false))
		profile.resonance_unlocked=bool(source.get("resonance_unlocked",false))
		profile.q_skill_cooldown=clampf(float(source.get("q_skill_cooldown",0)),0,15)
		profile.player_level=clampi(int(source.get("player_level",Growth.TEST_START_LEVEL)),1,100)
		profile.experience=clampi(int(source.get("experience",0)),0,maxi(0,Growth.xp_required(player_level())-1))
		if source.get("bag") is Dictionary:
			for id in ["health_large","energy_large","elixir","revival_stone","experience_crystal"]:
				profile.bag[id]=maxi(0,int(source.bag.get(id,0)))
		if source.get("equipment_slots") is Dictionary:
			for slot in profile.equipment_slots:
				profile.equipment_slots[slot]=str(source.equipment_slots.get(slot,""))
		if source.get("equipment_owned") is Array:
			for id in source.equipment_owned:
				if Items.has_item(id) and Items.item(id).kind=="gear" and id not in profile.equipment_owned: profile.equipment_owned.append(id)
		for slot in profile.equipment_slots:
			var equipped: String=profile.equipment_slots[slot]
			if equipped not in profile.equipment_owned or Items.item(equipped).get("slot","")!=slot: profile.equipment_slots[slot]=""
		profile.health = clampf(float(source.get("health",player_stats().health)),0,player_stats().health)
		profile.energy = clampi(int(source.get("energy", 200)), 0, 200)
		for key in ["health_potions", "energy_potions", "ultimate_potions", "kills", "coins"]:
			profile[key] = maxi(0, int(source.get(key, 0)))
		for key in ["armor", "amulet", "diving_armor"]:
			profile[key] = bool(source.get(key, false))
		for id: Variant in source.get("weapons", []) if source.get("weapons") is Array else []:
			if id in Items.weapon_ids() and id not in profile.weapons:
				profile.weapons.append(id)
		if source.get("weapon_upgrades") is Dictionary:
			for weapon_id in source.weapon_upgrades:
				if Items.has_item(weapon_id): profile.weapon_upgrades[weapon_id] = clampi(int(source.weapon_upgrades[weapon_id]),0,10)
		profile.equipped = str(source.get("equipped", "fists")) if source.get("equipped") in profile.weapons else "fists"
		profile.nuonuo_unlocked = 6 in completed
		profile.ikun_unlocked = 16 in completed
		profile.q_penguin_unlocked = 24 in completed
		profile.doro_unlocked = 26 in completed
		profile.gugu_unlocked = 27 in completed
		if profile.gugu_unlocked and "penguin_rock" not in profile.weapons:
			profile.weapons.append("penguin_rock")
		if 26 in completed and not profile.resonance_unlocked:
			profile.resonance_unlocked=true
			if "resonance_disruptor" not in profile.weapons: profile.weapons.append("resonance_disruptor")
		for reward_index in completed:
			if reward_index>=28: apply_music_rewards(reward_index)
			if reward_index>=38: apply_hell_rewards(reward_index)
		var saved_index:=int(data.get("active_level",0))
		active_level=saved_index if is_unlocked(saved_index) else 0
		hub_chapter=Catalog.chapter(active_level) if active_level>0 else clampi(int(data.get("hub_chapter",1)),1,5)
		if active_level>=18:
			var arena_state: Dictionary=level_state(active_level).get("arena",{})
			if not arena_state.has("q_contract"):
				arena_state.q_contract=bool(arena_state.get("mercenary",{}).get("paid",false))
				if arena_state.q_contract: profile.q_skill_cooldown=maxf(profile.q_skill_cooldown,clampf(float(arena_state.get("mercenary",{}).get("cooldown",0)),0,15))
		profile.character = str(source.get("character")) if str(source.get("character")) in party_ids() else "phoebe"
		var spec := character_definition(str(profile.character))
		profile.health = clampf(float(source.get("health",player_stats().health)),0,player_stats().health)
		profile.energy = clampi(int(source.get("energy",spec.max_energy)),0,spec.max_energy)
		for id in CHARACTER_IDS:
			var version:=int(source.get("progression_version",0))
			var old_max: float=player_stats(id).health
			if version==0: old_max=character_definition(id).max_health
			elif version==1: old_max=Growth.legacy_health(player_level(),character_definition(id).max_health)
			var raw: float=float(source.get("party_health",{}).get(id,old_max))
			if id==str(source.get("character","phoebe")): raw=float(source.get("health",raw))
			if version<Growth.BALANCE_VERSION: raw=raw/old_max*float(player_stats(id).health)
			profile.party_health[id]=clampf(raw,0,player_stats(id).health)
		profile.health=float(profile.party_health[profile.character])
		if source.get("character")=="q_penguin" and profile.character!="q_penguin" and profile.health<=0 and profile.last_defeat_level==0:
			profile.party_health.phoebe=player_stats("phoebe").health
			profile.character="phoebe"
			profile.health=profile.party_health.phoebe
		if source.get("ultimate_charges") is Dictionary:
			for id in CHARACTER_IDS:
				profile.ultimate_charges[id] = clampi(int(source.ultimate_charges.get(id,3)),0,5)
	var requested: int = int(data.get("active_level", 0))
	active_level = requested if is_unlocked(requested) else 0
	hub_chapter = Catalog.chapter(active_level) if active_level > 0 else clampi(int(data.get("hub_chapter",1)),1,5)
	remember_travel_unlock()
	ensure_character_allowed()
	return true

func encounters_cleared(index: int) -> bool:
	if index>=18: return bool(level_state(index).get("arena",{}).get("finished",false))
	var state := level_state(index)
	if int(state.get("adventure_version",0))<2:
		return true
	var rooms: Dictionary = state.get("encounters",{})
	if int(state.get("adventure_version",0))>=3 and not bool(rooms.get("patrol",{}).get("cleared",false)): return false
	for id in Catalog.all_door_ids(index):
		if not rooms.has(id) or not bool(rooms[id].get("cleared",false)):
			return false
	return true

func mark_character_dead() -> void:
	end_overdrive()
	profile.health = 0
	profile.party_health[profile.character] = 0
	save_progress()

func switch_to_survivor() -> bool:
	var next := next_survivor()
	if next.is_empty():
		return false
	profile.character = next
	if next=="gugu" and "penguin_rock" in profile.weapons: profile.equipped="penguin_rock"
	profile.health = float(profile.party_health[next])
	profile.energy = character_definition(next).max_energy
	profile_changed.emit()
	save_progress()
	message.emit("%s 接替出战！" % character_definition(next).display_name)
	return true

func next_survivor() -> String:
	var ids := party_ids()
	var start := ids.find(str(profile.character))
	for offset in range(1,ids.size()):
		var id := ids[posmod(start+offset,ids.size())]
		if float(profile.party_health.get(id,100)) > 0:
			return id
	return ""

func recover_from_defeat(index: int, retry: bool) -> bool:
	if index > 0:
		hub_chapter = Catalog.chapter(index)
	profile.last_defeat_level=index
	end_overdrive()
	if retry and index>0:
		level_state(index).erase("overdrive_used")
		level_state(index).erase("overdrive_remaining")
	if retry:
		for id in CHARACTER_IDS:
			profile.party_health[id] = player_stats(id).health
		profile.health = profile.party_health[profile.character]
		profile.energy = character_definition(str(profile.character)).max_energy
	if index>0 and (retry or index not in completed or index>=18):
		states.erase(str(index))
		if index in completed: level_state(index).cleared_before=true
	if retry and index>0:
		active_level = index
	else:
		active_level = 0
		ensure_character_allowed()
		if float(profile.health)<=0: switch_to_survivor()
		if index>0:
			return_portal = Catalog.PORTAL_ORDER[index-1]
	profile_changed.emit()
	save_progress()
	return _change_scene(Catalog.scene_path(index) if retry and index>0 else Catalog.hub_path(hub_chapter))

func friendship_active() -> bool:
	if 47 not in completed: return false
	for id in ["phoebe","nuonuo","doro","gugu"]:
		if not character_allowed(id): return false
		var hp: float=float(profile.get("health",0)) if profile.get("character","")==id else float(profile.get("party_health",{}).get(id,0))
		if hp<=0: return false
	return true

func apply_hell_rewards(index: int) -> void:
	var rescued: String={39:"miku",40:"reimu",43:"doro",44:"gugu",45:"nuonuo",47:"phoebe"}.get(index,"")
	if not rescued.is_empty():
		profile[rescued+"_unlocked"]=true
		profile.party_health[rescued]=player_stats(rescued).health
	if index==41: profile.hell.music_departed=true
	if index==47: profile.hell.friendship=true
	ensure_character_allowed()

func choose_omo(give: bool) -> bool:
	if active_level!=46 or not bool(level_state(46).get("arena",{}).get("battle_done",false)): return false
	if not str(profile.hell.omo_choice).is_empty(): return false
	profile.hell.omo_choice="give" if give else "keep"
	profile.hell.capsule=not give
	level_state(46).arena.omo_music_locked=give
	save_progress()
	profile_changed.emit()
	return true
