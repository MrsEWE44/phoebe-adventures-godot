extends SceneTree
const Catalog=preload("res://Scence/Levels/catalog.gd")
var failures:=0
var checks:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func frames(n:=2) -> void:
	for i in n:
		await process_frame
		await physics_frame
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var level=load("res://Scence/Levels/level_01.tscn").instantiate()
	level.spawn_enemies=false
	root.add_child(level)
	level.player.set_physics_process(false)
	var player=level.player
	for cell in level.geometry.base_free:
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.is_spawn_safe(point):
			player.position=point
			break
	for id in ["phoebe","nuonuo","ikun"]:
		campaign.profile.character=id
		campaign.profile_changed.emit()
		var original: Resource=campaign.character_definition(id).ultimate
		var base_damage: int=original.damage
		var base_radius: float=original.radius
		for biome in ["land","ocean","sky"]:
			level.biome=biome
			player.refresh_environment()
			var native: bool=biome==player.definition.home_biome
			check(player.home_buff==native,"native biome matching "+id+"/"+biome)
			check(player.attack_damage(100)==(120 if native else 100),"normal damage biome multiplier")
			check(player.attack_damage(100,true)==(130 if native else 100),"skill damage biome multiplier")
			check(is_equal_approx(player.speed,player.definition.movement_speed*(1.12 if native else 1.0)),"movement biome multiplier")
			check(player.ultimate.damage==(roundi(base_damage*1.35) if native else base_damage),"ultimate damage biome multiplier")
			check(is_equal_approx(player.ultimate.radius,base_radius*(1.35 if native else 1.0)),"ultimate range biome multiplier")
			check(original.damage==base_damage and original.radius==base_radius and not original.empowered,"shared definition stays immutable")
			if id=="phoebe": check(player.ultimate.pulse_count==(3 if native else 0),"Phoebe native pulse field")
			if id=="nuonuo": check(player.ultimate.impact_radius==(32 if native else 0),"Nuonuo native burst radius")
			campaign.profile.health=100
			campaign.profile_changed.emit()
			player.invulnerable=0
			player.take_damage(10,"magic")
			check(player.health==(92 if native else 90),"native defense applies to received damage")
		level.biome=player.definition.home_biome
		level.allow_home_bonuses=false
		player.refresh_environment()
		check(not player.home_buff and player.ultimate.damage==base_damage,"map may disable native bonuses")
		level.allow_home_bonuses=true
		level.allow_ultimates=false
		var charges: int=campaign.ultimate_charges(id)
		check(not player.trigger_ultimate() and campaign.ultimate_charges(id)==charges,"map forbids ultimates without spending charges")
		level.allow_ultimates=true
	# All four NPC outcomes: once only, persist exact result, upgrades stack and cap.
	campaign.profile.character="phoebe"
	campaign.profile_changed.emit()
	var state: Dictionary=campaign.level_state(1)
	state.encounters={}
	for kind in ["item","weapon","upgrade","chatter"]:
		state.encounters[kind]={"kind":"npc","gift_kind":kind,"gift_id":"health" if kind=="item" else "iron_pistol","gift_claimed":false,"cleared":true,"actors":[]}
		var before: Dictionary=campaign.profile.duplicate(true)
		var reply: String=campaign.claim_encounter_gift(1,kind)
		check(not reply.is_empty() and state.encounters[kind].gift_claimed,"NPC outcome claimed "+kind)
		if kind=="item": check(campaign.profile.health_potions==before.health_potions+1,"NPC grants potion")
		if kind=="weapon": check("iron_pistol" in campaign.profile.weapons,"NPC grants weapon")
		if kind=="upgrade": check(campaign.weapon_upgrade("iron_pistol")==1,"NPC upgrades equipped weapon")
		if kind=="chatter": check(campaign.profile==before,"chatter gives no reward")
		var claimed: Dictionary=campaign.profile.duplicate(true)
		check(campaign.claim_encounter_gift(1,kind)==reply and campaign.profile==claimed,"cannot claim NPC gift twice")
	for i in 8:
		var key: String="smith_"+str(i)
		state.encounters[key]={"kind":"npc","gift_kind":"upgrade","gift_claimed":false,"cleared":true,"actors":[]}
		campaign.claim_encounter_gift(1,key)
	check(campaign.weapon_upgrade("iron_pistol")==5 and is_equal_approx(campaign.weapon_multiplier("iron_pistol"),1.6),"upgrade cap +5 / +60 percent")
	level.biome="land"
	player.refresh_environment()
	check(player.attack_damage(100)==192,"native bonus and weapon upgrade multiply")
	var circuit: Node2D
	for mechanism in level.switches:
		if mechanism.puzzle.mode=="circuit":
			circuit=mechanism
			break
	circuit.choose("0")
	var partial: Array=circuit.circuit.duplicate()
	var circuit_id: String=circuit.config.id
	campaign.save_path="res://.godot/expedition_rules_save.json"
	campaign.saving_enabled=true
	check(campaign.save_progress(),"save new rules to isolated disk file")
	level.queue_free()
	await frames()
	check(campaign.load_progress(),"reload isolated save")
	var restored: Dictionary=campaign.profile.duplicate(true)
	campaign.claim_encounter_gift(1,"item")
	campaign.claim_encounter_gift(1,"upgrade")
	check(campaign.profile==restored,"reload cannot reroll NPC reward or reapply upgrade")
	check(campaign.weapon_upgrade("iron_pistol")==5,"upgrade survives disk reload")
	level=load("res://Scence/Levels/level_01.tscn").instantiate()
	level.spawn_enemies=false
	root.add_child(level)
	level.player.set_physics_process(false)
	circuit=level.get_node("Switches/"+circuit_id)
	check(circuit.circuit_matches(circuit.circuit,partial),"partially solved circuit survives JSON number conversion")
	preload("res://Tests/puzzle_helper.gd").solve(circuit)
	check(circuit.activated,"restored partial circuit remains solvable")
	level.queue_free()
	await frames()
	# Migrate legacy completed chapters, including penultimate levels without rescues.
	campaign.reset_state()
	for index in range(1,18):
		var old: Dictionary=campaign.level_state(index)
		old.doors=Catalog.all_door_ids(index)
		old.adventure_version=0
		campaign.completed.append(index)
	check(campaign.save_progress() and campaign.load_progress(),"legacy save migration")
	check(campaign.completed.size()==17 and campaign.profile.nuonuo_unlocked and campaign.profile.ikun_unlocked,"migration retains both chapters and characters")
	campaign.saving_enabled=false
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(campaign.save_path+suffix)
	print("Expedition rule checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
