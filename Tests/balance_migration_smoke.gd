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
func legacy_hp(level: int, base: float) -> float:
	for next in range(2,level+1): base=base+10 if next<10 else base*(2 if next>=90 else 1.7)
	return base
func write_source(source: Dictionary) -> void:
	var file:=FileAccess.open(campaign.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.save_path="res://.godot/balance-migration-save.json"
	for level in [1,9,10,30,89,90,100]:
		campaign.reset_state()
		var profile: Dictionary=campaign.profile.duplicate(true)
		profile.player_level=level
		profile.progression_version=1
		profile.coins=456
		profile.weapons=["pili_blade"]
		profile.weapon_upgrades={"pili_blade":8}
		for id in campaign.CHARACTER_IDS:
			var old:=legacy_hp(level,campaign.character_definition(id).max_health)
			check(is_equal_approx(Growth.legacy_health(level,campaign.character_definition(id).max_health),old),"legacy closed form matches old loop %s Lv%d"%[id,level])
			profile.party_health[id]=old*.35
		profile.party_health.nuonuo=0
		profile.health=profile.party_health.phoebe
		var scale:=legacy_hp(level,100)/100.0
		var record={"id":"migration_enemy","species":"naiwa_mini","hp":1300*scale*.4,"max_hp":1300*scale,"growth_version":1,"dead":false,"position":[350,350]}
		var state={"switches":[],"doors":[],"position":[],"combat_level":level,"arena":{"finished":false,"records":[record]}}
		write_source({"version":1,"profile":profile,"states":{"20":state},"hub_chapter":3,"active_level":0})
		check(campaign.load_progress(),"load exponential save Lv%d"%level)
		for id in campaign.CHARACTER_IDS:
			var expected: float=0 if id=="nuonuo" else campaign.player_stats(id).health*.35
			check(is_equal_approx(campaign.profile.party_health[id],expected),"migrate player HP ratio %s Lv%d"%[id,level])
		check(campaign.profile.player_level==level and campaign.profile.coins==456 and campaign.weapon_upgrade("pili_blade")==8,"migration retains level, coins, upgrades")
		var loaded: Dictionary=campaign.states["20"].arena.records[0]
		campaign.migrate_enemy_record(loaded,20,"hp","max_hp")
		check(is_equal_approx(loaded.max_hp,700*Growth.health_scale(level)) and is_equal_approx(loaded.hp/loaded.max_hp,.4),"migrate enemy HP and damage ratio")
		var copy: Dictionary=loaded.duplicate(true)
		campaign.migrate_enemy_record(loaded,20,"hp","max_hp")
		check(copy==loaded,"enemy migration is idempotent")
		campaign.saving_enabled=true
		campaign.save_progress()
		campaign.saving_enabled=false
		check(campaign.load_progress() and is_equal_approx(campaign.profile.health,campaign.player_stats().health*.35),"reloading migrated player does not shrink again")
	for level in [1,30,60,100]:
		var stats:=Growth.stats(level)
		check(stats.health<=595 and stats.attack<=119 and stats.defense<=59.5,"player stats bounded")
		check(Growth.mitigate(100,100000,level)==25,"defense reduction capped at 75 percent")
		var ordinary_hp:=80*Growth.enemy_health_scale(level,"orc")
		var pistol_hit:=Growth.mitigate(18*stats.attack/20,6*Growth.defense_scale(level),level)
		var hits:=ceili(ordinary_hp/pistol_hit)
		check(hits>=3 and hits<=5,"starter pistol kills ordinary orc in 3-5 hits Lv%d"%level)
		check(18000*Growth.enemy_health_scale(level,"penguin_full")<18000,"final boss HP remains below 18k even at cap")
	campaign.reset_state()
	var arena=load("res://Scence/Levels/level_20.tscn").instantiate()
	arena.spawn_enemies=false
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	var ultimate: Resource=arena.player.ultimate
	for i in 60: campaign.profile_changed.emit()
	check(arena.player.ultimate==ultimate,"unchanged stats do not allocate ultimate resources on every shot/kill")
	var victims: Array=[]
	for i in 30:
		var enemy=arena.spawn_kind("orc",false,arena.get_node("ArenaCenter").position)
		enemy.set_physics_process(false)
		victims.append(enemy)
	await frames()
	campaign.saving_enabled=true
	campaign.save_progress()
	var writes: int=campaign.save_write_count
	var started:=Time.get_ticks_usec()
	for enemy in victims: enemy.take_damage(enemy.max_health*2,"true")
	var kill_ms:=(Time.get_ticks_usec()-started)/1000.0
	check(campaign.save_write_count==writes,"30 same-frame kills cause zero synchronous disk writes")
	check(campaign._save_pending,"kills schedule checkpoint")
	campaign._process(.3)
	check(campaign.save_write_count==writes+1,"all kill save requests merge into one write")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(campaign.save_path))
	check(saved.profile.kills==30 and saved.states["20"].arena.records.all(func(r): return r.dead),"one checkpoint contains every reward and dead enemy")
	for i in 10: campaign.grant_drop("health_large",false)
	check(campaign.save_write_count==writes+1,"automatic loot pickup also batches writes")
	campaign._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(campaign.save_write_count==writes+2 and not campaign._save_pending,"window close flushes pending loot")
	campaign.request_save()
	campaign.save_progress()
	writes=campaign.save_write_count
	campaign._process(1)
	check(campaign.save_write_count==writes,"manual save consumes pending save without duplicate write")
	campaign.saving_enabled=false
	arena.queue_free()
	await frames()
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer: child.stop()
	await create_timer(.3).timeout
	print("Balance migration/performance: %d checks, %d failures; 30-kill batch %.2f ms, 1 disk write"%[checks,failures,kill_ms])
	quit(1 if failures else 0)
