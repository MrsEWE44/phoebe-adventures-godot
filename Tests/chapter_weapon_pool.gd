extends SceneTree
const Weapons=preload("res://Weapons/weapon_registry.gd")
const Items=preload("res://Combat/items.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var rng:=RandomNumberGenerator.new()
	rng.seed=92076
	for index in range(1,28):
		var expected: Array=["bronze_blade","iron_pistol"] if index<8 else (["coral_trident","harpoon"] if index<18 else [])
		check(Weapons.drops_for_level(index)==expected,"exact chapter weapon pool %d"%index)
		var valid:=true
		var seen: Dictionary={}
		for i in 2000:
			var drop:=Items.enemy_drop(index,i%2==0,rng)
			if Weapons.all().has(drop):
				valid=valid and drop in expected
				seen[drop]=true
		check(valid and seen.size()==expected.size(),"monster and boss rolls never leak other weapons %d"%index)
		for id in Weapons.all():
			var normalized:=Weapons.level_reward(index,id)
			check(normalized in expected or normalized=="energy","saved weapon reward obeys local pool")
		check(Weapons.level_reward(index,"health_large")=="health_large","consumables unchanged")
	for index in [1,8,18]:
		campaign.profile.weapons=[]
		check(campaign.claim_chest(index,"legacy_extra", "plasma_cannon"),"legacy chest can still be opened")
		check("plasma_cannon" not in campaign.profile.weapons,"legacy chest cannot grant removed weapon")
		campaign.level_state(index).encounters={"legacy_npc":{"kind":"npc","gift_kind":"weapon","gift_id":"pili_blade"}}
		campaign.claim_encounter_gift(index,"legacy_npc")
		check("pili_blade" not in campaign.profile.weapons,"NPC cannot grant shop-only weapon")
		var inventory: Array=campaign.profile.weapons.duplicate()
		campaign.claim_encounter_gift(index,"legacy_npc")
		check(campaign.profile.weapons==inventory,"normalization does not duplicate gifts")
	campaign.reset_state()
	campaign.profile.coins=10000
	check(campaign.purchase("pili_blade") and campaign.purchase("torpedo"),"shop-exclusive and removed ocean-drop weapons remain purchasable")
	campaign.profile.weapons.append("moon_blade") # Removed legacy equipment migrates.
	campaign.save_path="res://.godot/chapter-pool-save.json"
	campaign.saving_enabled=true
	check(campaign.save_progress() and campaign.load_progress(),"isolated save round trip")
	campaign.saving_enabled=false
	check("pili_blade" in campaign.profile.weapons and "torpedo" in campaign.profile.weapons and "bronze_blade" in campaign.profile.weapons and "moon_blade" not in campaign.profile.weapons,"save preserves purchases and migrates removed weapon")
	for index in [10,13,16]:
		var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		level.spawn_enemies=false
		root.add_child(level)
		check(level.get_node("Chests").get_children().all(func(chest): return not Weapons.all().has(chest.reward) or chest.reward in Weapons.drops_for_level(index)),"authored ocean chests use reduced pool")
		level.queue_free()
		await process_frame
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(campaign.save_path+suffix)
	print("Chapter weapon pools: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
