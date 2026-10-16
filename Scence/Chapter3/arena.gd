extends Node2D
const Catalog=preload("res://Scence/Levels/catalog.gd")
const FINAL_BOSSES=["naiwa_mini","naiwa_full","penguin_mini","penguin_full"]
@export var level_index:=18
@export var biome:="snow"
@export var allow_home_bonuses:=true
@export var allow_ultimates:=true
@export var spawn_enemies:=true
var spawn_safe_radius:=0.0
var config: Dictionary
var state: Dictionary
var doors: Array=[]
var switches: Array=[]
var interaction_hint:=""
var adventure: Node=null
var checkpoint:=0.0
var next_delay:=3.0
var refill_timer:=0.0
var video_started:=false
var mercenary: Node2D
var captive: Node2D
var failure_shown:=false
@onready var player: CharacterBody2D=$Player
@onready var geometry: Node2D=$Navigation
func _ready() -> void:
	Campaign.scene_ready()
	Campaign.active_level=level_index
	Campaign.hub_chapter=Catalog.chapter(level_index)
	config=Catalog.load_level(level_index)
	geometry.build($Terrain,$Spawn.position,$Background.texture.get_size())
	var saved: Dictionary=Campaign.level_state(level_index)
	if not saved.get("arena") is Dictionary:
		saved.arena={"wave":0,"elapsed":0.0,"records":[],"serial":0,"finished":false,"boss_started":false}
	state=saved.arena
	if level_index==26:
		# Migrate the old escort failure without losing elapsed combat progress.
		state.erase("failed")
	# Convert paid companion contracts to controllable-character access.
	if not state.has("q_contract"):
		state.q_contract=bool(state.get("mercenary",{}).get("paid",false))
		if state.q_contract: Campaign.profile.q_skill_cooldown=maxf(Campaign.profile.q_skill_cooldown,clampf(float(state.get("mercenary",{}).get("cooldown",0)),0,15))
		if level_index!=24 and Campaign.profile.get("mercenary_prepaid",false) and not state.finished:
			state.q_contract=true
			Campaign.profile.mercenary_prepaid=false
	Campaign.ensure_character_allowed()
	if saved.position.size()==2: player.position=geometry.nearest(Vector2(saved.position[0],saved.position[1]))
	else: player.position=geometry.nearest($Spawn.position)
	player.refresh_environment()
	setup_allies()
	update_music()
	var camera: Camera2D=player.get_node("Camera2D")
	camera.zoom=Vector2(2,2)
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=int($Background.texture.get_width())
	camera.limit_bottom=int($Background.texture.get_height())
	if spawn_enemies and not bool(state.finished):
		for record in state.records:
			if not record.dead: restore_actor(record)
	if bool(state.finished): next_delay=0
	$Portals/Exit.refresh()
	var hud=preload("res://UI/game_hud.gd").new()
	hud.world=self
	add_child(hud)
	Story.enter_world.call_deferred(self)
	preload("res://Story/npc_roster.gd").setup(self)
	Campaign.profile_changed.emit()
	Campaign.save_progress()
	if level_index==26: Campaign.message.emit("坚持240秒并清除全部敌人！Doro在牢笼中安全等待；通关解锁Doro与真伤连锁共振枪。")
func setup_allies() -> void:
	if level_index in [26,27]:
		if not state.get("captive") is Dictionary: state.captive={}
		captive=preload("res://Scence/Chapter3/ally.tscn").instantiate()
		captive.role="doro" if level_index==26 else "gugu"
		captive.record=state.captive
		captive.position=geometry.nearest($RescuePosition.position)
		add_child(captive)
func fail_rescue() -> void:
	if level_index==26: return # Legacy calls cannot fail the new survival objective.
	if state.finished or failure_shown: return
	state.failed=true
	failure_shown=true
	snapshot()
	Campaign.save_progress()
	var screen=preload("res://UI/defeat_screen.gd").new()
	screen.level_index=level_index
	screen.reason="保护失败：Doro 已倒下"
	add_child(screen)
func is_spawn_safe(_point: Vector2) -> bool:
	return false
func living() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_parent()==self and not e.is_dead)
func _process(delta: float) -> void:
	if not spawn_enemies or player.is_dead or state.finished or state.get("failed",false): return
	checkpoint+=delta
	if checkpoint>=4:
		checkpoint=0
		snapshot()
		Campaign.request_save()
	update_music()
	if next_delay>0:
		next_delay-=delta
		if next_delay>0: return
	var number:=level_index-17
	if int(config.survival_seconds)>0:
		if int(state.wave)==0:
			state.wave=1
			spawn_pack(18 if number==9 else 8)
			spawn_kind("penguin_mini",true)
			if number==9:
				spawn_kind("naiwa_full",true)
				spawn_kind("naiwa_mini",true)
				refill_timer=7
		if number==9:
			ensure_rescue_bosses()
			reinforce_rescue()
		var duration:=float(config.survival_seconds)
		state.elapsed=minf(duration,float(state.elapsed)+delta)
		refill_timer-=delta
		var cap:=26 if number==9 else 12
		if float(state.elapsed)<duration and (living().is_empty() or (refill_timer<=0 and living().size()<cap)):
			spawn_pack(mini(8 if number==9 else 6,cap-living().size()))
			refill_timer=7.0
		if float(state.elapsed)>=duration and required_bosses_dead() and (number!=9 or living().is_empty()): finish()
		return
	if number==10 and bool(state.boss_started):
		refill_timer-=delta
		ensure_final_bosses()
		if final_bosses_dead(): finish();return
		if refill_timer<=0 and living().size()<26:
			spawn_pack(mini(8,26-living().size()))
			refill_timer=6
		return
	if not living().is_empty(): return
	if int(state.wave)>=int(config.waves):
		if number==10:
			state.boss_started=true
			ensure_final_bosses()
			spawn_pack(12)
			Campaign.message.emit("最终战：击败凑企鹅完全体！躲开红色落点，陨坑会伤害所有阵营。")
		else: finish()
		return
	state.wave=int(state.wave)+1
	spawn_pack(6+number+int(state.wave)*2)
	if number==10 and int(state.wave)==3: spawn_kind("naiwa_full",true)
	if int(state.wave)==int(config.waves):
		if number==3: spawn_kind("naiwa_mini",true)
		if number in [5,8]: spawn_kind("naiwa_full",true)
		if number in [8,10]: spawn_kind("penguin_mini",true)
		if number==10: spawn_kind("naiwa_mini",true)
	Campaign.message.emit("第 %d / %d 波：清除全部敌人后开始下一波。"%[state.wave,config.waves])
	snapshot()
	Campaign.save_progress()
func ensure_final_bosses() -> void:
	for species in FINAL_BOSSES:
		if not state.records.any(func(record): return record.species==species and record.required): spawn_kind(species,true)
func reinforce_rescue() -> void:
	# Saved thresholds cannot fire twice on reload; spawning ends at the time limit.
	if not state.get("rescue_reinforcements") is Array: state.rescue_reinforcements=[]
	if state.elapsed>=float(config.survival_seconds): return
	for threshold in [45,90,135,180,210]:
		if state.elapsed<threshold or threshold in state.rescue_reinforcements: continue
		if living().filter(func(e): return e.character_type==e.CharacterType.BOSS).size()>=4: return
		spawn_kind("penguin_mini" if threshold in [90,180] else "naiwa_mini",true)
		state.rescue_reinforcements.append(threshold)
		snapshot()
		Campaign.request_save()
func ensure_rescue_bosses() -> void:
	# Bring unfinished saves from the earlier rescue rule up to date once.
	for species in ["naiwa_mini","penguin_mini","naiwa_full"]:
		if not state.records.any(func(record): return record.species==species and record.required): spawn_kind(species,true)
func final_bosses_dead() -> bool:
	for species in FINAL_BOSSES:
		if not state.records.any(func(record): return record.species==species and record.required and record.dead): return false
	return required_bosses_dead()
func spawn_pack(count: int) -> void:
	for i in count:
		var species: String="naiwa_minion" if level_index>=20 and i%3!=0 else ["orc","sky_sentinel","wind_spirit"][i%3]
		if level_index>=24 and i%4==0: species="penguin_minion"
		spawn_kind(species)
func spawn_kind(species: String, required:=false, preferred:=Vector2.INF) -> Node2D:
	var candidates: Array=geometry.base_free.duplicate()
	candidates.shuffle()
	var point: Vector2=geometry.nearest($ArenaCenter.position)
	for cell in candidates:
		var p: Vector2=geometry.nav.get_point_position(cell)
		if p.distance_to(player.position)<150 or p.distance_to($Portals/LockedEntrance.position)<70: continue
		if p.distance_to($ArenaCenter.position)>390: continue
		if living().any(func(e): return e.position.distance_to(p)<28): continue
		point=p
		break
	# Prefer the editable scene markers when they are safely away from the player.
	var markers: Array=$EnemySpawns.get_children()
	markers.shuffle()
	for marker in markers:
		var candidate: Vector2=geometry.nearest(marker.position)
		if candidate.distance_to(player.position)>150 and not living().any(func(e): return e.position.distance_to(candidate)<36):
			point=candidate
			break
	if preferred.is_finite(): point=geometry.nearest(preferred)
	state.serial=int(state.serial)+1
	var spec: Resource=load("res://Characters/Definitions/%s.tres"%species)
	var hp: int=spec.max_health
	if species not in ["penguin_full","naiwa_full","penguin_mini","naiwa_mini"]: hp=roundi(hp*(1.0+float(level_index-18)*.09))
	var record: Dictionary={"id":"ice_"+str(state.serial),"species":species,"hp":hp,"max_hp":hp,"position":[point.x,point.y],"dead":false,"required":required,"summoned":false}
	state.records.append(record)
	return restore_actor(record)
func restore_actor(record: Dictionary) -> Node2D:
	Campaign.migrate_enemy_record(record,level_index,"hp","max_hp")
	var enemy: Node2D
	if str(record.species).begins_with("naiwa") or str(record.species).begins_with("penguin"):
		enemy=load("res://Characters/Actors/%s.tscn"%record.species).instantiate()
		enemy.record=record
	else:
		enemy=load("res://Characters/Actors/%s.tscn"%record.species).instantiate()
		enemy.set_meta("arena_record",record)
	enemy.level=self
	enemy.persistent_id=record.id
	enemy.position=geometry.nearest(Vector2(record.position[0],record.position[1]))
	add_child(enemy)
	enemy.max_health=float(record.max_hp)
	enemy.health=float(record.hp)
	enemy.emerge_remaining=1.1
	if not enemy.has_signal("arena_death"):
		enemy.died.connect(func(): actor_died(record))
	return enemy
func actor_died(record: Dictionary) -> void:
	record.dead=true
	record.hp=0
	next_delay=3.0 if int(config.survival_seconds)==0 and not state.boss_started else 0.0
	Campaign.profile.energy=mini(player.max_energy,int(Campaign.profile.energy)+4)
	Campaign.profile_changed.emit()
	if level_index==27 and bool(state.boss_started) and final_bosses_dead(): finish.call_deferred()
	Campaign.request_save()
func required_bosses_dead() -> bool:
	var found:=false
	for record in state.records:
		if record.required:
			found=true
			if not record.dead: return false
	return found
func snapshot() -> void:
	if is_instance_valid(mercenary): mercenary.sync_record()
	if is_instance_valid(captive): captive.sync_record()
	for enemy in living():
		for record in state.records:
			if record.id==enemy.persistent_id:
				record.hp=enemy.health
				record.position=[enemy.position.x,enemy.position.y]
	Campaign.level_state(level_index).position=[player.position.x,player.position.y]
func finish() -> void:
	if state.finished or state.get("failed",false): return
	if level_index==24 and (state.elapsed<180 or not required_bosses_dead()): return
	if level_index==26 and (state.elapsed<float(config.survival_seconds) or not living().is_empty() or not required_bosses_dead()): return
	if level_index==27 and not final_bosses_dead(): return
	state.finished=true
	for record in state.records:
		record.dead=true
	for enemy in living(): enemy.queue_free()
	for group in ["projectiles","arena_hazards"]:
		for effect in get_tree().get_nodes_in_group(group): effect.queue_free()
	Campaign.complete_arena(level_index)
	update_music()
	if is_instance_valid(mercenary): mercenary.release()
	if is_instance_valid(captive): captive.release()
	$Portals/Exit.refresh()
	var reward: String={24:"Q 币企鹅临时雇佣资格已开放！仅第三章，按场付费后可从背包切换操控。",26:"Doro 与静音共振枪已解锁！共振枪对奶娃、凑企鹅造成真伤、暴击和连锁攻击。",27:"牢笼已打开！咕嘎企鹅继承凑企鹅原石及投石、碎石雨、陨石、飞踢技能！"}.get(level_index,"")
	Campaign.message.emit("挑战成功！"+reward+" 右上出口可继续下一关或返回主场景。")
	if level_index==27 and not video_started:
		video_started=true
		Story.request_finale(self)
func update_music() -> void:
	if 27 in Campaign.completed or (level_index==27 and bool(state.get("finished",false))):
		Global.set_boss_music("victory3")
		return
	Global.set_boss_music("penguin" if level_index>=24 else ("naiwa" if level_index>=20 else ""))
func objective_text() -> String:
	if state.finished: return "3-%d %s · 胜利！右上出口已开启"%[level_index-17,config.name]
	if level_index==26: return "3-9 · 生存 %03d/240 秒 · 待清除敌人 %d · Doro被囚禁"%[int(state.elapsed),living().size()]
	if level_index==27: return "3-10 · 救出咕嘎 · 第 %d/%d 波 · 必须击败全部标记首领 · 敌人 %d"%[state.wave,config.waves,living().size()]
	if int(config.survival_seconds)>0: return "3-%d · 生存 %03d / 180 秒 · 小 BOSS %s · 敌人 %d"%[level_index-17,int(state.elapsed),"已击败" if required_bosses_dead() else "存活",living().size()]
	return "3-%d · 波次 %d / %d · 敌人 %d%s"%[level_index-17,state.wave,config.waves,living().size()," · 最终 BOSS" if state.boss_started else ""]
func show_exit_choices() -> void:
	if not state.finished: return
	var options: Array=[{"id":"hub","text":"返回第三章主场景"}]
	if level_index<27: options.push_front({"id":"next_level","text":"进入 3-%d"%(level_index-16)})
	Dialogue.open("冰门出口",["挑战已经完成，选择接下来的目的地。"],options,self,func(id):
		Dialogue.close()
		if id=="next_level": Campaign.enter_level.call_deferred(level_index+1)
		else: Campaign.return_to_hub.call_deferred())
func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.active or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E:
			var closest: Node2D
			var distance:=70.0
			for guide in get_tree().get_nodes_in_group("story_guides"):
				var d: float=player.position.distance_to(guide.position)
				if guide.get_parent()==self and d<minf(55,distance):
					closest=guide
					distance=d
			for ally in [mercenary,captive]:
				if is_instance_valid(ally) and player.position.distance_to(ally.position)<distance:
					closest=ally
					distance=player.position.distance_to(ally.position)
			if closest!=null:
				closest.interact()
				get_viewport().set_input_as_handled()
				return
		if event.physical_keycode==KEY_E and player.position.distance_to($Portals/Exit.position)<65: show_exit_choices()
		if event.physical_keycode==KEY_F3:
			geometry.debug_overlay=not geometry.debug_overlay
			geometry.queue_redraw()
			get_tree().debug_collisions_hint=geometry.debug_overlay
func _exit_tree() -> void:
	Global.set_boss_music("")
