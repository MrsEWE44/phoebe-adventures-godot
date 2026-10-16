extends SceneTree
const Weapons=preload("res://Weapons/weapon_registry.gd")
var checks:=0
var failures:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func arena(index: int) -> Node:
	var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
	root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	level.player.invulnerable=10000
	level.video_started=true
	return level
func clear(level: Node) -> void:
	for enemy in level.living(): enemy.take_damage(enemy.max_health*10,"true")
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var rng:=RandomNumberGenerator.new()
	rng.seed=4910
	for index in range(18,28):
		var valid:=Weapons.drops_for_level(index).is_empty()
		for i in 1000:
			var id: String=campaign.Items.enemy_drop(index,i%2==0,rng)
			valid=valid and (id.is_empty() or not Weapons.all().has(id))
		check(valid,"no random weapon in third chapter %d"%index)
	check(not Weapons.drops_for_level(1).is_empty() and not Weapons.drops_for_level(8).is_empty(),"earlier chapter weapon pools retained")
	campaign.claim_chest(26,"old_weapon_chest","iron_pistol")
	campaign.level_state(26).encounters={"npc":{"kind":"npc","gift_kind":"weapon","gift_id":"pili_blade"}}
	campaign.claim_encounter_gift(26,"npc")
	check(campaign.profile.weapons.is_empty(),"legacy chest and NPC weapons replaced with supplies")
	var level=arena(26)
	check(level.config.survival_seconds==240 and not campaign.profile.resonance_unlocked and "resonance_disruptor" not in campaign.profile.weapons,"3-9 starts a 240s battle without weapon reward")
	check(level.captive.character_type==2 and level.captive.hurtbox.collision_layer==0 and not level.captive.is_in_group("allies"),"Doro is neutral captive, not a defense target")
	level.captive.take_damage(1000000,"true")
	check(not level.captive.is_dead and not paused,"Doro cannot fail survival objective")
	level.next_delay=0
	level._process(.1)
	check(level.living().size()>=21,"3-9 initial horde and three boss stages")
	clear(level)
	level.state.elapsed=180
	level._process(.1)
	check(not level.state.finished and not level.living().is_empty(),"three minutes still refills enemies")
	level.state.elapsed=239.9
	clear(level)
	level.finish()
	check(not level.state.finished,"clear alone cannot skip four-minute timer")
	var blocker=level.spawn_kind("orc")
	blocker.set_physics_process(false)
	level.state.elapsed=240
	level._process(.1)
	check(not level.state.finished,"four minutes still requires clearing remaining enemies")
	clear(level)
	level._process(.1)
	check(level.state.finished and level.captive.released and campaign.profile.doro_unlocked and campaign.profile.resonance_unlocked,"four minutes and clear unlock Doro and reward")
	check(campaign.profile.weapons.count("resonance_disruptor")==1,"counter weapon granted exactly once")
	level.finish()
	campaign.complete_arena(26)
	check(campaign.profile.weapons.count("resonance_disruptor")==1,"repeat victory cannot duplicate reward")
	for index in range(18,26):
		campaign.level_state(index).arena={"finished":true}
		campaign.complete_arena(index)
	campaign.save_path="res://.godot/counter-survival-save.json"
	campaign.saving_enabled=true
	campaign.save_progress()
	level.queue_free()
	await frames()
	campaign.load_progress()
	campaign.saving_enabled=false
	check(campaign.profile.resonance_unlocked and campaign.profile.doro_unlocked and campaign.profile.weapons.count("resonance_disruptor")==1,"completion rewards persist on disk")
	# Earlier escort failures migrate into the new neutral-captive rule.
	campaign.states.erase("26")
	campaign.level_state(26).arena={"wave":1,"elapsed":155.0,"serial":0,"records":[],"finished":false,"boss_started":false,"failed":true,"captive":{"dead":true,"health":0}}
	level=arena(26)
	check(not level.state.get("failed",false) and not level.captive.is_dead and level.state.elapsed==155,"legacy escort failure migrates without losing elapsed time")
	level.queue_free()
	await frames()
	level=arena(27)
	var spec:=Weapons.get_weapon("resonance_disruptor")
	var center: Vector2=level.get_node("ArenaCenter").position
	level.player.position=center-Vector2(100,0)
	campaign.profile.character="phoebe"
	campaign.profile_changed.emit()
	campaign.equip_weapon("resonance_disruptor")
	level.player.facing=Vector2.RIGHT
	check(level.player.attack(false,false),"normal input fires counter gun")
	var shot: Node=get_nodes_in_group("projectiles")[-1]
	shot.set_physics_process(false)
	check(shot.damage_type=="true" and shot.target_health_ratios==spec.target_health_ratios and shot.critical_chance==.3 and shot.chain_targets==5,"equipped weapon copies true damage, critical and chain properties")
	for family in ["naiwa","penguin"]:
		for stage in ["minion","mini","full"]:
			var enemy=level.spawn_kind(family+"_"+stage,false,center)
			enemy.set_physics_process(false)
			shot.critical_hit=false
			var before: float=enemy.health
			var amount: float=shot._damage_for(enemy)
			enemy.take_damage(amount,shot.damage_type)
			var ratio: float=1.0 if stage=="minion" else (.6 if stage=="mini" else .18)
			check(is_equal_approx(enemy.health,maxf(0,before-amount)) and amount>=before*ratio,"armor bypass and rank damage: "+family+stage)
			shot.critical_hit=true
			check(is_equal_approx(shot._damage_for(enemy),amount*1.8),"critical multiplies true damage: "+family+stage)
			enemy.queue_free()
			await frames(1)
	shot.queue_free()
	await frames()
	var pack: Array=[]
	for i in 7:
		var enemy=level.spawn_kind("naiwa_minion",false,center+Vector2(i*20,0))
		enemy.position=center+Vector2(i*20,0)
		enemy.set_physics_process(false)
		pack.append(enemy)
	level.player.attack_timer=0
	level.player.attack(false,false)
	shot=get_nodes_in_group("projectiles")[-1]
	shot.set_physics_process(false)
	shot.critical_hit=false
	shot._hit(pack[0].hurtbox)
	check(pack.filter(func(e): return e.is_dead).size()==6 and not pack[6].is_dead,"one impact kills direct minion and five linked enemies exactly once")
	for enemy in pack: enemy.queue_free()
	await frames()
	var direct=level.spawn_kind("naiwa_full",false,center)
	var blocked=level.spawn_kind("penguin_full",false,center+Vector2(100,0))
	direct.position=center
	blocked.position=center+Vector2(100,0)
	direct.set_physics_process(false)
	blocked.set_physics_process(false)
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=center+Vector2(50,-40)
	var collider:=CollisionShape2D.new()
	collider.shape=RectangleShape2D.new()
	collider.shape.size=Vector2(10,300)
	wall.add_child(collider)
	level.add_child(wall)
	await frames()
	level.player.attack_timer=0
	level.player.attack(false,false)
	shot=get_nodes_in_group("projectiles")[-1]
	shot.set_physics_process(false)
	shot.critical_hit=true
	var expected: float=shot._damage_for(direct)
	var before: float=direct.health
	shot._hit(direct.hurtbox)
	check(is_equal_approx(direct.health,maxf(0,before-expected)),"actual critical impact applies unmitigated damage")
	check(blocked.health==blocked.max_health,"true-damage chain cannot cross terrain wall")
	for node in [direct,blocked,wall]: node.queue_free()
	await frames()
	# Defeating 3-10 still grants Gugu the stone and all inherited attacks.
	level.state.boss_started=true
	level.ensure_final_bosses()
	clear(level)
	await frames()
	check(level.state.finished and campaign.profile.gugu_unlocked and "penguin_rock" in campaign.profile.weapons,"final fixed stone reward preserved")
	check(campaign.select_character("gugu") and level.player.normal_weapon.weapon_id=="penguin_rock","Gugu equips inherited stone when selected")
	check(not campaign.can_equip_weapon("penguin_rock","phoebe"),"stone belongs to Gugu")
	level.player.attack_timer=0
	campaign.profile.energy=200
	check(level.player.attack(true,false),"Gugu inherits stone rain")
	check(level.player.trigger_weapon_special(Vector2.RIGHT),"Gugu inherits meteor")
	check(level.player.trigger_flying_kick(),"Gugu inherits flying kick")
	level.queue_free()
	await frames()
	print("Counter weapon / 4-minute survival: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
