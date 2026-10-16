extends Node
## Door-triggered encounters. Rolls and enemy state are persistent, never rerolled on reload.
var level: Node2D
var state: Dictionary
var rules: Dictionary
var live: Dictionary = {}

func _ready() -> void:
	level = get_parent()
	rules = level.config.adventure
	state = Campaign.level_state(level.level_index)
	if not state.get("encounters") is Dictionary:
		state.encounters = {}
	if not state.get("puzzles") is Dictionary:
		state.puzzles = {}
	if not state.has("seed"):
		state.seed = randi()
	if level.level_index not in Campaign.completed:
		if int(state.get("adventure_version",0))<3 and not state.doors.is_empty():
			state.encounters["patrol"]={"kind":"patrol","cleared":true,"actors":[],"reward":"health"}
		state.adventure_version = 3
	Campaign.door_opened.connect(_door_opened)
	_upgrade_density()
	if state.encounters.has("patrol"):
		_restore_patrol.call_deferred()
	for id in state.doors:
		ensure_room.call_deferred(str(id),false)
	if not bool(state.get("visited",false)):
		level.player.combat_voice.enter_area("level_%d" % level.level_index)
		state.visited = true
	Campaign.message.emit(str(rules.intro))

func _door_opened(index: int, id: String) -> void:
	if index==level.level_index:
		ensure_room.call_deferred(id,true)

func _upgrade_density() -> void:
	if int(state.get("density_revision",0))>=1: return
	if level.level_index not in Campaign.completed:
		var rng:=RandomNumberGenerator.new()
		rng.seed=int(state.seed)+49021
		var reachable: Array=level.geometry.reachable_cells(level.player.position)
		for id in state.encounters:
			var room: Dictionary=state.encounters[id]
			if room.cleared or room.kind not in ["patrol","battle","boss"]: continue
			var total: int=int(rules.patrol_count) if room.kind=="patrol" else int(rules.get("boss_pack",4) if room.kind=="boss" else rules.get("min_pack",4))
			var reserved: Array[Vector2]=[]
			for record in room.actors:
				if not record.dead: reserved.append(Vector2(record.position[0],record.position[1]))
			for i in range(room.actors.size(),total):
				var point:=Vector2.INF
				if room.kind=="patrol":
					var offset:=rng.randi_range(0,reachable.size()-1)
					for step in reachable.size():
						var cell: Vector2i=reachable[(step+offset)%reachable.size()]
						var candidate: Vector2=level.geometry.nav.get_point_position(cell)
						if level.is_spawn_safe(candidate) or candidate.distance_to(level.player.position)<90: continue
						if reserved.any(func(p: Vector2): return p.distance_to(candidate)<40): continue
						point=candidate
						break
				else:
					point=_spawn_point(level.get_node("Doors/"+str(id)).position,i,reserved)
				if not point.is_finite(): break
				reserved.append(point)
				var species: String=rules.enemies[rng.randi_range(0,rules.enemies.size()-1)]
				var spec: Resource=load("res://Characters/Definitions/%s.tres"%species)
				var hp:=roundi(spec.max_health*float(rules.enemy_health))
				room.actors.append({"id":str(id)+"_reinforcement_"+str(i),"species":species,"health":hp,"max_health":hp,"position":[point.x,point.y],"dead":false})
	state.density_revision=1
	Campaign.save_progress()

func ensure_room(id: String, announce := true) -> void:
	if live.has(id):
		return
	var door := level.get_node("Doors/"+id) as Node2D
	var center: Vector2 = level.geometry.nearest(door.position+Vector2(0,24))
	if not state.encounters.has(id):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(state.seed)+id.hash()
		var roll := rng.randi_range(0,99)
		var kind := "battle" if roll<40 else ("boss" if roll<53 and level.level_index>=2 else ("treasure" if roll<75 else "npc"))
		if state.doors.size()==level.doors.size() and id==str(state.doors[-1]):
			kind = "boss"
		if level.level_index==1:
			# Predictable, small encounters for the introductory lesson.
			kind=["treasure","npc","battle"][posmod(state.doors.size()-1,3)]
			if state.doors.size()==level.doors.size(): kind="battle"
		var room := {"kind":kind,"cleared":kind in ["treasure","npc"],"actors":[],"reward":["health","energy","ultimate"][rng.randi_range(0,2)]}
		room.gift_kind = ["item","weapon","upgrade","chatter"][rng.randi_range(0,3)]
		var weapons: Array = preload("res://Weapons/weapon_registry.gd").drops_for_level(level.level_index)
		room.gift_id = weapons[rng.randi_range(0,weapons.size()-1)] if room.gift_kind=="weapon" and not weapons.is_empty() else room.reward
		room.gift_claimed = false
		if kind in ["battle","boss"]:
			var count: int = int(rules.get("boss_pack",4)) if kind=="boss" else rng.randi_range(int(rules.get("min_pack",4)),int(rules.max_pack))
			var reserved: Array[Vector2] = []
			for i in count:
				var species: String = str(rules.boss) if kind=="boss" and i==0 else str(rules.enemies[rng.randi_range(0,rules.enemies.size()-1)])
				var point := _spawn_point(center,i,reserved)
				if not point.is_finite(): continue
				reserved.append(point)
				var spec: Resource = load("res://Characters/Definitions/%s.tres" % species)
				room.actors.append({"id":id+"_"+str(i),"species":species,"health":roundi(spec.max_health*float(rules.get("enemy_health",1))),"max_health":roundi(spec.max_health*float(rules.get("enemy_health",1))),"position":[point.x,point.y],"dead":false})
		state.encounters[id] = room
		Campaign.save_progress()
	var room: Dictionary = state.encounters[id]
	if room.get("gift_kind")=="weapon" and not room.get("gift_claimed",false):
		var local_weapons:=preload("res://Weapons/weapon_registry.gd").drops_for_level(level.level_index)
		if room.get("gift_id","") not in local_weapons:
			room.gift_id=local_weapons[posmod(str(id).hash(),local_weapons.size())] if not local_weapons.is_empty() else "energy"
	live[id] = []
	for record: Dictionary in room.actors:
		if record.dead:
			continue
		var enemy = load("res://Characters/Actors/%s.tscn" % record.species).instantiate()
		enemy.level = level
		enemy.persistent_id = record.id
		enemy.encounter_id = id
		enemy.position = level.geometry.nearest(Vector2(record.position[0],record.position[1]))
		enemy.emerge_remaining = .85
		level.add_child(enemy)
		Campaign.migrate_enemy_record(record,level.level_index,"health","max_health")
		enemy.max_health=float(record.get("max_health",enemy.max_health))
		enemy.health=clampf(float(record.health),1,enemy.max_health)
		live[id].append(enemy)
	if room.kind=="npc":
		var npc = preload("res://Characters/encounter_npc.gd").new()
		npc.level = level
		npc.room_id = id
		npc.display_name = "漂流旅人" if level.biome=="ocean" else "遗迹游商"
		npc.position = level.geometry.nearest(center)
		level.add_child(npc)
	if room.cleared and room.kind!="npc":
		spawn_reward(id,center)
	if announce:
		Campaign.message.emit("封印解除：%s" % {"battle":"守卫苏醒，清除敌人后领取宝箱。","boss":"强敌出现！注意红色预警。","treasure":"发现补给宝箱。","npc":"遇见旅人，E 对话可能获得礼物或武器强化。"}[room.kind])
		level.player.combat_voice.enter_area(id,room.kind=="boss")
	Campaign.check_completion(level.level_index)

func _spawn_point(center: Vector2, index: int, reserved: Array[Vector2]) -> Vector2:
	var candidate := center+Vector2.from_angle(index*2.4)*float(20+index*18)
	var best := Vector2.INF
	var score := INF
	for cell in level.geometry.reachable_cells(level.player.position):
		var p: Vector2 = level.geometry.nav.get_point_position(cell)
		if level.geometry.nav.is_point_solid(cell) or p.distance_to(center)>155 or p.distance_to(level.player.position)<32 or level.is_spawn_safe(p):
			continue
		var occupied := false
		for point in reserved:
			if point.distance_to(p)<25: occupied=true
		for actor in get_tree().get_nodes_in_group("characters"):
			if actor.position.distance_to(p)<25:
				occupied = true
		if not occupied and p.distance_squared_to(candidate)<score and not level.geometry.path(center,p).is_empty():
			score = p.distance_squared_to(candidate)
			best = p
	return best

func actor_died(enemy: Node2D) -> void:
	if not state.encounters.has(enemy.encounter_id):
		return
	var room: Dictionary = state.encounters[enemy.encounter_id]
	var cleared := true
	for record: Dictionary in room.actors:
		if record.id==enemy.persistent_id:
			record.dead = true
			record.health = 0
		cleared = cleared and bool(record.dead)
	if cleared and not room.cleared:
		room.cleared = true
		room.reward_position = [enemy.position.x,enemy.position.y]
		spawn_reward.call_deferred(enemy.encounter_id,enemy.position)
		Campaign.message.emit("守卫已清除，奖励宝箱出现。")
	Campaign.check_completion(level.level_index)
	Campaign.request_save()

func spawn_reward(id: String, center: Vector2) -> void:
	var chest_id := "room_"+id
	if chest_id in state.opened_chests or level.get_node("Chests").has_node(chest_id):
		return
	var chest := preload("res://Combat/chest.tscn").instantiate()
	chest.name = chest_id
	chest.chest_id = chest_id
	chest.reward = state.encounters[id].reward
	var saved: Array=state.encounters[id].get("reward_position",[center.x,center.y])
	chest.position = level.geometry.nearest(Vector2(saved[0],saved[1]))
	level.get_node("Chests").add_child(chest)

func snapshot() -> void:
	for id in live:
		for enemy in live[id]:
			if not is_instance_valid(enemy) or enemy.is_dead:
				continue
			for record: Dictionary in state.encounters[id].actors:
				if record.id==enemy.persistent_id:
					record.health = enemy.health
					record.position = [enemy.position.x,enemy.position.y]

func hint_text() -> String:
	for mechanism in level.switches:
		if not mechanism.activated:
			return "%s\n下一条线索：%s。%s" % [rules.hint,mechanism.config.label,mechanism.puzzle.get("clue","观察机关旁的提示。")]
	if not can_open_next_door(): return "先清除地图上剩余的守卫；M 可查看敌人与封印门的位置。"
	if state.doors.size()<level.doors.size(): return "机关已经供能。靠近尚未开启的封印门，按 E 开门；门口可能出现敌人、宝箱或旅人。"
	return "封印与守卫都已解决，请与待救角色对话后返回。" if level.level_index in [6,16] and not state.get("rescued",false) else "封印与守卫都已解决，可以返回入口。"

func cleared_count() -> int:
	var count := 0
	for id in state.encounters:
		if id!="patrol" and state.encounters[id].cleared:
			count += 1
	return count

func can_open_next_door() -> bool:
	if not bool(state.encounters.get("patrol",{}).get("cleared",false)): return false
	for room in state.encounters.values():
		if not bool(room.cleared): return false
	return true

func _process(_delta: float) -> void:
	if not is_instance_valid(level.player) or level.player.is_dead: return
	if not state.encounters.has("patrol") and not level.is_spawn_safe(level.player.position):
		start_patrol()

func start_patrol() -> void:
	if state.encounters.has("patrol"): return
	var rng := RandomNumberGenerator.new()
	rng.seed=int(state.seed)+7123
	var room := {"kind":"patrol","cleared":false,"actors":[],"reward":"health"}
	var candidates: Array[Vector2] = []
	for cell in level.geometry.reachable_cells(level.player.position):
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.geometry.nav.is_point_solid(cell) and point.distance_to(level.get_node("Spawn").position)>level.spawn_safe_radius+55 and point.distance_to(level.player.position)>90:
			candidates.append(point)
	var count := int(rules.get("patrol_count",4))
	for i in count:
		if candidates.is_empty(): break
		var point: Vector2 = candidates[rng.randi_range(0,candidates.size()-1)]
		var species: String = rules.enemies[i%rules.enemies.size()]
		var spec: Resource = load("res://Characters/Definitions/%s.tres"%species)
		var hp := roundi(spec.max_health*float(rules.get("enemy_health",1)))
		room.actors.append({"id":"patrol_"+str(i),"species":species,"health":hp,"max_health":hp,"position":[point.x,point.y],"dead":false})
		candidates=candidates.filter(func(p: Vector2): return p.distance_to(point)>40)
	room.cleared=room.actors.is_empty()
	state.encounters.patrol=room
	_restore_patrol()
	Campaign.save_progress()
	Campaign.message.emit("已离开复活圈：巡游敌人出现。清场并解谜后，靠近封印门按 E 开门。")

func _restore_patrol() -> void:
	if live.has("patrol"): return
	live.patrol=[]
	if bool(state.encounters.patrol.cleared):
		spawn_reward("patrol",level.get_node("Spawn").position+Vector2(25,-36))
	for record in state.encounters.patrol.actors:
		if record.dead: continue
		var enemy=load("res://Characters/Actors/%s.tscn"%record.species).instantiate()
		enemy.level=level
		enemy.persistent_id=record.id
		enemy.encounter_id="patrol"
		enemy.position=level.geometry.nearest(Vector2(record.position[0],record.position[1]))
		enemy.emerge_remaining=.85
		level.add_child(enemy)
		Campaign.migrate_enemy_record(record,level.level_index,"health","max_health")
		enemy.max_health=float(record.get("max_health",enemy.max_health))
		enemy.health=clampf(float(record.health),1,enemy.max_health)
		live.patrol.append(enemy)

func remaining_enemies() -> int:
	var count := 0
	for room in state.encounters.values():
		for actor in room.actors:
			if not actor.dead: count+=1
	return count
