extends SceneTree
const Growth=preload("res://Characters/progression.gd")
var checks:=0
var failures:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.reset_state()
	campaign.saving_enabled=false
	check(campaign.player_level()==30,"test start level")
	for level in range(2,101):
		var previous:=Growth.stats(level-1)
		var current:=Growth.stats(level)
		for field in ["health","attack","defense"]:
			var expected: float=previous[field]+{"health":5.0,"attack":1.0,"defense":.5}[field]
			check(is_equal_approx(current[field],expected) and is_finite(current[field]),"growth %d %s"%[level,field])
	check(Growth.stats(101)==Growth.stats(100),"stat level cap")
	check(Growth.xp_required(1)==100 and Growth.xp_required(10)==100 and Growth.xp_required(19)==100,"first two XP bands")
	check(Growth.xp_required(20)==140 and Growth.xp_required(30)==196 and Growth.xp_required(40)==275,"compound XP bands rounded upward")
	check(Growth.xp_required(100)==0,"max level has no next XP bar")
	for chapter in range(3,13): check(Growth.chapter_requirement(chapter)==mini(100,chapter*10),"chapter requirement %d"%chapter)
	campaign.profile.player_level=29
	check(not campaign.is_unlocked(18) and not campaign.travel_to_hub(3),"underlevel chapter rejected")
	campaign.profile.player_level=30
	check(campaign.is_unlocked(18),"chapter3 opens at 30")
	campaign.profile.coins=100000
	check(campaign.purchase("pili_blade"),"advanced merchant purchase")
	var last_cost:=0
	for rank in 10:
		var cost: int=campaign.upgrade_cost("pili_blade")
		check(cost>last_cost and campaign.upgrade_weapon("pili_blade"),"paid weapon upgrade %d"%(rank+1))
		last_cost=cost
	check(campaign.weapon_upgrade("pili_blade")==10 and not campaign.upgrade_weapon("pili_blade"),"weapon cap 10")
	check(is_equal_approx(campaign.weapon_multiplier("pili_blade"),2.0),"weapon damage reaches double at +10")
	check(campaign.destroy_weapon("pili_blade") and "pili_blade" not in campaign.profile.weapons and campaign.weapon_upgrade("pili_blade")==0 and campaign.profile.equipped=="fists","destroy removes ownership and reinforcement")
	check(campaign.purchase("pili_blade") and campaign.weapon_upgrade("pili_blade")==0,"new copy does not inherit destroyed upgrades")
	campaign.grant_drop("health_large")
	campaign.profile.health=campaign.player_stats().health*.1
	check(campaign.consume_item("health_large") and is_equal_approx(campaign.profile.health,campaign.player_stats().health*.9),"large medicine heals 80 percent")
	campaign.grant_drop("elixir")
	campaign.profile.energy=0
	check(campaign.consume_item("elixir") and campaign.profile.energy==200 and is_equal_approx(campaign.profile.health,campaign.player_stats().health),"elixir restores both bars")
	campaign.grant_drop("swift_boots")
	campaign.grant_drop("frost_boots")
	check(campaign.equipment_bonus("speed_bonus")==.22,"first boots auto-equipped")
	campaign.equip_item("frost_boots")
	check(is_equal_approx(campaign.equipment_bonus("speed_bonus"),.12),"boots slot replaces rather than stacking")
	campaign.profile.party_health.nuonuo=0
	campaign.profile.experience=Growth.xp_required(30)-1
	campaign.award_experience(30)
	check(campaign.player_level()==31 and campaign.profile.party_health.nuonuo==0,"level up retains dead allies")
	campaign.profile.player_level=99
	campaign.profile.experience=Growth.xp_required(99)-1
	campaign.award_experience(99,true)
	check(campaign.player_level()==100 and campaign.profile.experience==0,"XP cannot exceed level 100")
	# Exercise real high-level combat using bounded values.
	campaign.profile.health=campaign.player_stats().health
	var arena=load("res://Scence/Levels/level_18.tscn").instantiate()
	arena.spawn_enemies=false
	root.add_child(arena)
	arena.player.set_physics_process(false)
	arena.player.position=arena.geometry.nearest(arena.get_node("ArenaCenter").position)
	var boss=arena.spawn_kind("naiwa_mini",true,arena.player.position+Vector2(50,0))
	boss.set_physics_process(false)
	await frames()
	var damage: float=arena.player.attack_damage(700)
	check(damage<10000 and boss.max_health<5000 and arena.player.max_health==595,"Lv100 combat remains in readable ranges")
	boss.take_damage(damage,"magic")
	check(boss.is_dead,"unupgraded thunder crescent one-shots same-level Naiwa mini")
	# Disk persistence is isolated from the real save.
	campaign.save_path="res://.godot/progression-save.json"
	campaign.saving_enabled=true
	campaign.save_progress()
	campaign.saving_enabled=false
	arena.queue_free()
	await frames()
	check(campaign.load_progress() and campaign.player_level()==100 and campaign.profile.health==595,"bounded HP and level survive JSON save")
	check(campaign.profile.equipment_slots.feet=="frost_boots","equipment slots survive JSON save")
	# Legacy 50/100 HP upgrades to 50 percent of the new Lv30 maximum.
	campaign.reset_state()
	var legacy: Dictionary=campaign.profile.duplicate(true)
	for key in ["player_level","experience","progression_version","bag","equipment_owned","equipment_slots"]: legacy.erase(key)
	legacy.party_health={"phoebe":50,"nuonuo":0}
	legacy.health=50
	var file:=FileAccess.open(campaign.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"active_level":0,"hub_chapter":1,"states":{},"profile":legacy}))
	file.close()
	check(campaign.load_progress() and campaign.player_level()==30 and is_equal_approx(campaign.profile.health,campaign.player_stats().health*.5),"legacy migration preserves health ratio")
	check(campaign.profile.party_health.nuonuo==0,"legacy migration preserves death")
	# Switch after death inside a live enemy collider, then actually walk.
	campaign.reset_state()
	campaign.profile.nuonuo_unlocked=true
	arena=load("res://Scence/Levels/level_18.tscn").instantiate()
	arena.spawn_enemies=false
	root.add_child(arena)
	var player=arena.player
	player.position=arena.geometry.nearest(arena.get_node("ArenaCenter").position)
	player.set_physics_process(false)
	var obstacle=arena.spawn_kind("naiwa_mini",false,player.position)
	obstacle.set_physics_process(false)
	await frames()
	player.take_damage(player.max_health*100,"true")
	player._physics_process(4)
	await frames(5)
	check(not player.is_dead and player.current_character=="nuonuo" and player.is_physics_processing(),"survivor resumes movement processing")
	check(not player.is_action_locked() and player.hurtbox.collision_layer==16,"survivor restores action and damage collision")
	check(player.position.distance_to(obstacle.position)>15,"revival relocates away from overlapping enemy")
	var before: Vector2=player.position
	Input.action_press("right")
	await create_timer(.25).timeout
	Input.action_release("right")
	check(player.position.distance_to(before)>5,"revived player physically moves")
	arena.queue_free()
	await frames()
	print("Progression checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
