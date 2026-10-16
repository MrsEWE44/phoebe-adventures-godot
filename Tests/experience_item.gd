extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	check(campaign.player_level()==1,"fresh runtime starts at level 1 before test setup")
	campaign.reset_state(1)
	check(not campaign.consume_item("experience_crystal"),"cannot use missing crystal")
	campaign.profile.coins=80
	check(campaign.purchase("experience_crystal") and campaign.item_count("experience_crystal")==1 and campaign.profile.coins==0,"level 1 shop sells crystal for 80")
	var inventory=load("res://UI/inventory.gd").new()
	root.add_child(inventory)
	inventory.select_category(0)
	inventory.selected="experience_crystal"
	inventory.open()
	var entries: Array=inventory.build_entries()
	var item: Dictionary=entries.filter(func(e): return e.id=="experience_crystal")[0]
	check(item.enabled and item.icon!=null and item.tag.contains("1") and item.action.contains("100"),"inventory shows usable XP item with icon and count")
	inventory.activate_selected()
	check(campaign.player_level()==2 and campaign.profile.experience==0 and campaign.item_count("experience_crystal")==0,"inventory action consumes one item and grants exactly 100 XP")
	check(campaign.player_stats()=={"health":105.0,"attack":21.0,"defense":10.5} and campaign.profile.health==105,"level-up refreshes base stats and preserves HP ratio")
	campaign.reset_state(30)
	campaign.profile.health=campaign.player_stats().health*.5
	campaign.profile.party_health.nuonuo=0
	campaign.profile.experience=150
	campaign.grant_drop("experience_crystal")
	check(campaign.consume_item("experience_crystal") and campaign.player_level()==31 and campaign.profile.experience==54,"item bypasses enemy level-gap penalty and carries XP across level")
	check(campaign.profile.party_health.nuonuo==0 and campaign.profile.health==campaign.player_stats().health*.5,"XP cannot revive dead teammates or fully heal")
	campaign.grant_drop("experience_crystal")
	campaign.profile.health=0
	check(not campaign.consume_item("experience_crystal") and campaign.item_count("experience_crystal")==1,"dead player cannot consume crystal")
	campaign.profile.health=campaign.player_stats().health
	campaign.profile.player_level=99
	campaign.profile.experience=campaign.Growth.xp_required(99)-1
	check(campaign.consume_item("experience_crystal") and campaign.player_level()==100 and campaign.profile.experience==0,"crystal respects level 100 cap")
	campaign.grant_drop("experience_crystal")
	check(not campaign.consume_item("experience_crystal") and campaign.item_count("experience_crystal")==1,"max level does not waste item")
	check(not campaign.add_experience(-100) and campaign.player_level()==100,"invalid XP award cannot lower level")
	campaign.reset_state(1)
	campaign.add_experience(350)
	check(campaign.player_level()==4 and campaign.profile.experience==50,"shared XP service handles multiple level-ups")
	campaign.grant_drop("experience_crystal")
	campaign.profile.weapons=["moon_blade","dusk_sniper","iron_pistol","pili_blade"]
	campaign.profile.weapon_upgrades={"moon_blade":4,"dusk_sniper":8,"iron_pistol":3,"pili_blade":2}
	campaign.profile.equipped="dusk_sniper"
	campaign.save_path="res://.godot/experience-item-save.json"
	campaign.saving_enabled=true
	check(campaign.save_progress() and campaign.load_progress(),"XP item save and reload")
	campaign.saving_enabled=false
	check(campaign.item_count("experience_crystal")==1 and campaign.player_level()==4 and campaign.profile.experience==50,"XP and item quantity persist")
	check(campaign.profile.weapons==["bronze_blade","iron_pistol","pili_blade"] and campaign.profile.equipped=="iron_pistol","retired weapons migrate to valid equipment without duplicates")
	check(campaign.weapon_upgrade("iron_pistol")==8 and campaign.weapon_upgrade("bronze_blade")==4 and campaign.weapon_upgrade("pili_blade")==2,"migration retains highest applicable upgrade and shop item")
	check(campaign.claim_chest(1,"retired_chest","moon_blade"),"old chest containing deleted weapon can still open")
	var rng:=RandomNumberGenerator.new()
	rng.seed=41931
	var found:=false
	for i in 5000:
		if campaign.Items.enemy_drop(1,false,rng)=="experience_crystal": found=true;break
	check(found,"crystal occurs in monster drop pool")
	inventory.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(campaign.save_path+suffix)
	print("XP item and retired equipment: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
