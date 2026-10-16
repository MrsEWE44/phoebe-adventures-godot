extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await process_frame
	await physics_frame
	await process_frame
func run() -> void:
	var c=root.get_node("Campaign")
	var story=root.get_node("Story")
	var d=root.get_node("Dialogue")
	c.saving_enabled=false
	story.automatic_enabled=false
	c.reset_state(1)
	c.active_level=1
	ck(story.grant_field_kit(1) and c.profile.equipped=="bronze_blade","first stage grants and equips free starter sword")
	ck(not story.grant_field_kit(1),"kit cannot repeat")
	c.grant_drop("iron_pistol")
	ck(c.profile.equipped=="bronze_blade","new pickup preserves selected weapon")
	ck(c.equip_weapon("iron_pistol"),"player can deliberately select ranged weapon")
	c.grant_drop("bronze_blade")
	ck(c.profile.equipped=="iron_pistol" and c.profile.weapons.count("bronze_blade")==1,"duplicate drop cannot replace weapon or duplicate ownership")
	c.destroy_weapon("bronze_blade")
	ck(not story.grant_field_kit(1) and "bronze_blade" not in c.profile.weapons,"destroyed kit is not farmed on reentry")
	ck(story.grant_field_kit(8) and "coral_trident" in c.profile.weapons,"second chapter has free energy-independent melee option")
	ck(c.profile.equipped=="iron_pistol","ocean kit does not replace preferred gear")
	c.profile.coins=10000
	var world=load(c.Catalog.scene_path(1)).instantiate()
	world.spawn_enemies=false
	root.add_child(world)
	current_scene=world
	world.player.set_physics_process(false)
	await frames()
	ck(world.get_node("Chests/Chest2").reward=="iron_pistol","first stage authored chest guarantees ranged weapon")
	var merchant=world.get_node("Service_merchant")
	preload("res://UI/shop_menu.gd").open(merchant,"items")
	ck(d.content_label.text.contains("40%") and d.content_label.text.contains("70能量"),"shop exposes actual potion effects before purchase")
	ck(d.choices.filter(func(o):return o.id=="health")[0].icon!=null,"shop retains item icons")
	d.close()
	c.profile.ikun_unlocked=true
	c.select_character("ikun")
	preload("res://UI/shop_menu.gd").open(merchant,"weapons")
	ck(d.content_label.text.contains("当前角色不能装备") and d.content_label.text.contains("一刀999"),"restricted character sees weapon restrictions and special skill")
	d.close()
	c.select_character("phoebe")
	world.open_exit_menu()
	ck(d.active and not d.choices.any(func(o):return o.id=="next_level"),"unfinished stage cannot skip to next")
	d.close()
	c.level_state(1).doors=c.Catalog.all_door_ids(1)
	ck(c.check_completion(1),"finish first expedition")
	var coins: int=c.profile.coins
	world.open_exit_menu()
	ck(d.choices.any(func(o):return o.id=="next_level" and not o.get("disabled",false)),"completed stage offers next-level action")
	for button in d.choices_box.get_children():
		if button.get_meta("choice_id","")=="next_level": button.pressed.emit();break
	await scene_changed
	await frames()
	ck(current_scene.level_index==2 and not paused,"actual exit button changes scene and resumes play")
	# Replaying a cleared early stage must actually reset its puzzles/encounters,
	# keep historical unlocks, and remain resumable after an isolated save/load.
	ck(c.recover_from_defeat(1,true),"restart previously cleared stage")
	await scene_changed
	await frames()
	ck(c.level_state(1).doors.is_empty() and c.level_state(1).cleared_before,"restart refreshes old stage")
	ck(c.is_unlocked(2) and c.unfinished_attempt(),"replay preserves next-level unlock and can resume")
	ck(not story.grant_field_kit(1),"restart cannot duplicate intro kit")
	c.save_path="res://.godot/early-release-save.json"
	c.saving_enabled=true
	ck(c.save_progress(),"save replay separately from player save")
	c.saving_enabled=false
	current_scene.queue_free()
	await frames()
	ck(c.load_progress() and 1 in c.completed and c.is_unlocked(2) and c.unfinished_attempt(),"read replay keeps historical clear and current attempt")
	ck(not story.grant_field_kit(1),"kit claim survives reading save")
	c.level_state(1).doors=c.Catalog.all_door_ids(1)
	c.level_state(1).encounters={"patrol":{"cleared":true}}
	for id in c.Catalog.all_door_ids(1): c.level_state(1).encounters[id]={"cleared":true}
	ck(c.check_completion(1) and c.profile.coins==coins,"repeat clear cannot farm first-clear currency")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(c.save_path+suffix)
	for index in range(1,18):
		var content: Dictionary=story.entry(index)
		ck(not content.briefing.is_empty() and content.intro.choices.size()>=2,"early stage has briefing and attitude choices")
		ck(not content.task.is_empty(),"early stage has actionable task")
	print("EARLY RELEASE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
