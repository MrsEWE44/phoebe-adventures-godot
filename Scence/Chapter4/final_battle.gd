extends RefCounted
## Five authored rounds. The conductor persists across rounds three to five.
const WAVE_COUNT:=5
const PULSE_INTERVAL:=8.0
static func boss(world: Node2D) -> Node2D:
	for enemy in world.living():
		if enemy.record.get("final_conductor",false): return enemy
	return null
static func tick(world: Node2D,delta: float) -> void:
	var state: Dictionary=world.state
	if not state.ensemble_active: return
	state.ensemble_elapsed=float(state.ensemble_elapsed)+delta
	if int(state.wave)==0:
		start_wave(world,1)
		return
	world.ensemble_clock-=delta
	if world.ensemble_clock<=0:
		pulse(world)
		world.ensemble_clock=PULSE_INTERVAL
	var conductor:=boss(world)
	if int(state.wave)>=3 and conductor==null:
		if int(state.wave)==5: world.begin_final_ending()
		return
	var guards: Array=world.living().filter(func(e):return not e.record.get("final_conductor",false))
	if not guards.is_empty(): return
	if conductor!=null:
		var threshold: float=.70 if int(state.wave)==3 else .38
		if int(state.wave)==5 or conductor.health>conductor.max_health*threshold: return
	start_wave(world,int(state.wave)+1)
static func start_wave(world: Node2D,number: int) -> void:
	if number>WAVE_COUNT: return
	world.state.wave=number
	world.state.final_summons=0
	var kinds: Array=["naiwa_minion","weiro_minion","naiwa_mini"]
	if number>=2: kinds=["naiwa_mini","weiro_mini","penguin_mini"]
	if number>=4: kinds.append("naiwa_full");kinds.append("weiro_full")
	if number==3:
		var conductor: Node2D=world.spawn_kind("penguin_full",true)
		conductor.record.final_conductor=true
		world.state.boss_started=true
	for i in 8+number*3:
		if world.living().size()>=world.ENEMY_CAP-2: break
		var actor: Node2D=world.spawn_kind(kinds[i%kinds.size()])
		if actor==null: continue
		var hp_factor:=1.0+(number-1)*.16
		actor.max_health*=hp_factor
		actor.health=actor.max_health
		actor.damage_scale*=1.0+(number-1)*.10
		actor.record.hp=actor.health
		actor.record.max_hp=actor.max_health
		actor.record.damage_boost=1.0+(number-1)*.10
		actor.record.generation=1 # Keep subsidiary summoning finite within a wave.
	var conductor:=boss(world)
	if conductor!=null:
		conductor.record.summoned=false
		world.summon_final_reinforcements(conductor)
	world.next_delay=2.0
	world.get_node("/root/Campaign").message.emit("终幕第 %d / 5 波 · 保护固定席位的三位成员，等待合击音波！"%number)
	world.snapshot()
	world.get_node("/root/Campaign").save_progress()
static func pulse(world: Node2D) -> void:
	var performers: Array=world.music_allies.filter(func(a):return is_instance_valid(a) and a.protected and not a.is_dead)
	if performers.size()!=3: return
	var targets: Array=world.living()
	if targets.is_empty(): return
	var origin:=Vector2.ZERO
	for actor in performers: origin+=actor.combat_center()/3.0
	var target:=boss(world)
	if target==null: target=targets[0]
	var destination: Vector2=target.combat_center()
	var aim:=origin.direction_to(destination)
	for actor in performers:
		var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
		wave.position=actor.combat_center()
		wave.line=true
		wave.radius=wave.position.distance_to(destination)+220
		wave.direction=wave.position.direction_to(destination)
		wave.tint=Color("fff3b5")
		world.add_child(wave)
		actor.health=minf(actor.max_health,actor.health+30)
		actor.record.hp=actor.health
		actor.voice.play_event("ultimate")
	var impact=preload("res://Scence/Chapter4/sound_wave.gd").new()
	impact.position=destination
	impact.radius=260
	impact.tint=Color("aefcff")
	world.add_child(impact)
	world.state.combo_strike=true
	world.set_meta("ensemble_striking",true)
	for enemy in targets:
		var offset: Vector2=enemy.combat_center()-origin
		var affected: bool=(offset.dot(aim)>=0 and offset.dot(aim)<=origin.distance_to(destination)+220 and absf(offset.cross(aim))<=110) or enemy.combat_center().distance_to(destination)<=260
		if not affected: continue
		var species: String=enemy.definition.character_id
		if species.begins_with("naiwa"):
			world.assimilate(enemy,true)
			continue
		var fraction:=.28 if species.ends_with("full") else (.68 if species.ends_with("mini") else 1.1)
		if enemy.record.get("final_conductor",false): fraction=.10
		enemy.take_damage(enemy.max_health*fraction,"true")
	world.set_meta("ensemble_striking",false)
