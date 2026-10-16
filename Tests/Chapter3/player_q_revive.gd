extends SceneTree
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
func scene(index: int) -> Node:
	var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
	root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	level.video_started=true
	return level
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var level=scene(24)
	check(level.mercenary==null,"no autonomous Q NPC spawned")
	check(campaign.select_character("q_penguin"),"3-7 trial is selectable before unlock")
	var player: Node=level.player
	check(player.current_character=="q_penguin" and player.player_controlled and player.character_type==0,"Q is the actual controllable player")
	check(player.normal_weapon.weapon_id=="q_ak" and not campaign.can_equip_weapon("pili_blade"),"Q exclusively uses AK47")
	player.position=level.geometry.nearest(level.get_node("ArenaCenter").position)
	await frames()
	var start: Vector2=player.position
	Input.action_press("right")
	player._physics_process(.1)
	Input.action_release("right")
	check(player.position.distance_to(start)>0,"Q responds to player movement input")
	player.facing=Vector2.RIGHT
	check(player.attack(false,false),"manual AK47 normal attack")
	check(player.trigger_ultimate(Vector2.RIGHT),"manual explosive skill")
	check(campaign.profile.q_skill_cooldown==15 and player.voice.last_event=="ultimate","15 second skill cooldown and voice")
	check(not player.trigger_weapon_special(Vector2.RIGHT),"F and V cannot double cast")
	player.tick_character(1)
	campaign.select_character("phoebe")
	campaign.select_character("q_penguin")
	check(not player.trigger_ultimate(Vector2.RIGHT),"switching does not reset explosive cooldown")
	player._physics_process(15)
	check(player.attack(true,false),"right click shares the same replenishing skill")
	level.queue_free()
	await frames()
	campaign.active_level=0
	campaign.profile.q_penguin_unlocked=true
	campaign.profile.coins=1000
	check(campaign.hire_mercenary() and campaign.profile.coins==880,"existing per-challenge fee preserved")
	check(campaign.select_character("q_penguin") or campaign.profile.character=="q_penguin","paid player available in hub")
	level=scene(25)
	check(level.state.q_contract and not campaign.profile.mercenary_prepaid and level.mercenary==null,"contract transfers to playable Q without an NPC")
	check(level.player.current_character=="q_penguin","paid selection survives scene entry")
	level.queue_free()
	await frames()
	# Older paid companion saves carry forward access, not an autonomous body.
	campaign.states.erase("25")
	campaign.level_state(25).arena={"wave":0,"elapsed":0,"records":[],"serial":0,"finished":false,"boss_started":false,"mercenary":{"paid":true,"cooldown":12}}
	level=scene(25)
	check(level.state.q_contract and campaign.character_allowed("q_penguin") and level.mercenary==null,"legacy paid contract migrates")
	for index in range(1,25):
		if index not in campaign.completed: campaign.completed.append(index)
		var saved: Dictionary=campaign.level_state(index)
		saved.doors=campaign.Catalog.all_door_ids(index)
		saved.rescued=true
		if index>=18: saved.arena={"finished":true}
	campaign.profile.q_skill_cooldown=17
	campaign.profile.bag.revival_stone=2
	campaign.save_path="res://.godot/q-player-revive-save.json"
	campaign.saving_enabled=true
	campaign.save_progress()
	level.queue_free()
	await frames()
	campaign.load_progress()
	campaign.saving_enabled=false
	check(campaign.profile.character=="q_penguin" and campaign.active_level==25 and campaign.profile.q_skill_cooldown==15,"controllable Q and cooldown persist in save")
	check(campaign.item_count("revival_stone")==2,"revival item quantity persists")
	campaign.profile.bag.revival_stone=0
	campaign.active_level=0
	campaign.hub_chapter=2
	campaign.ensure_character_allowed()
	check(campaign.profile.character!="q_penguin" and not campaign.select_character("q_penguin"),"third chapter restriction retained")
	campaign.profile.player_level=39
	var coins: int=campaign.profile.coins
	check(not campaign.purchase("revival_stone") and campaign.profile.coins==coins,"revival shop item is locked below 40")
	campaign.profile.player_level=40
	check(campaign.purchase("revival_stone") and campaign.item_count("revival_stone")==1 and campaign.profile.coins==coins-180,"level 40 buys one revival stone")
	check(campaign.Items.item("revival_stone").texture!=null,"revival item icon exists")
	check(not campaign.consume_item("revival_stone") and campaign.item_count("revival_stone")==1,"cannot waste revival item on healthy party")
	campaign.hub_chapter=3
	campaign.states.erase("18")
	level=scene(18)
	player=level.player
	player.position=level.geometry.nearest(level.get_node("ArenaCenter").position)
	campaign.profile.character="phoebe"
	campaign.profile_changed.emit()
	campaign.profile.nuonuo_unlocked=true
	player.invulnerable=0
	player.take_damage(100000,"true")
	player._resolve_defeat()
	await frames()
	player.set_physics_process(false)
	check(campaign.profile.character=="nuonuo" and "phoebe" in campaign.fallen_characters(),"death still switches to living teammate")
	check(not campaign.revive_character("phoebe") and campaign.item_count("revival_stone")==1,"battle cannot consume crystal for reserve character")
	var hud: Node
	for child in level.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	hud.toggle_inventory()
	hud.inventory_panel.select_category(3)
	hud.inventory_panel.selected="phoebe"
	hud.inventory_panel.refresh()
	for entry in hud.inventory_panel.entries:
		if entry.id=="phoebe": check(not entry.enabled and entry.action.contains("主场景"),"backpack directs fallen party to main scene")
	hud.toggle_inventory()
	campaign.profile.ikun_unlocked=false
	campaign.profile.doro_unlocked=false
	campaign.profile.gugu_unlocked=false
	player.invulnerable=0
	player.take_damage(100000,"true")
	player._resolve_defeat()
	await frames()
	var screen: Node
	for child in level.get_children():
		if child.get_script()==load("res://UI/defeat_screen.gd"): screen=child
	check(screen!=null and paused,"party wipe opens defeat modal")
	check(not screen.has_method("revive_current") and not campaign.consume_item("revival_stone"),"party wipe has no in-place revival")
	current_scene=level
	screen.choose(false)
	await scene_changed
	await frames(5)
	var hub=current_scene
	check(campaign.active_level==0 and paused and campaign.profile.health==0,"return to main scene preserves death and opens recovery")
	check(hub.has_node("HubRecovery") and campaign.profile.party_health.phoebe==0 and campaign.profile.party_health.nuonuo==0,"hub offers recovery without auto-resurrecting anyone")
	for id in campaign.CHARACTER_IDS: campaign.profile.party_health[id]=0
	campaign.saving_enabled=true
	campaign.save_progress()
	campaign.load_progress()
	campaign.saving_enabled=false
	check(campaign.profile.health==0 and campaign.profile.last_defeat_level==18 and campaign.item_count("revival_stone")==1,"hub death and revival inventory persist on reload")
	campaign._change_scene(campaign.Catalog.hub_path(3))
	await scene_changed
	await frames(5)
	hub=current_scene
	check(hub.has_node("HubRecovery") and paused,"reloading fallen party reopens hub recovery")
	coins=campaign.profile.coins
	hub.get_node("HubRecovery").buy()
	check(campaign.item_count("revival_stone")==2 and campaign.profile.coins==coins-180,"fallen party can buy crystals in hub")
	hub.get_node("HubRecovery").revive("phoebe")
	await frames(6)
	player=hub.player
	check(not paused and campaign.profile.character=="phoebe" and not player.is_dead and player.health==player.max_health,"hub crystal revives selected character")
	check(player.collision_layer==65 and player.hurtbox.collision_layer==16 and player.is_physics_processing(),"hub revival restores movement and collisions")
	check(campaign.item_count("revival_stone")==1 and campaign.profile.party_health.nuonuo==0,"one crystal revives exactly one fallen character")
	for child in hub.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	hud.toggle_inventory()
	hud.inventory_panel.select_category(3)
	hud.inventory_panel.selected="nuonuo"
	hud.inventory_panel.refresh()
	hud.inventory_panel.activate_selected()
	check(campaign.profile.character=="phoebe" and campaign.profile.party_health.nuonuo==campaign.player_stats("nuonuo").health and campaign.item_count("revival_stone")==0,"hub backpack restores reserve without switching character")
	hud.toggle_inventory()
	hub.queue_free()
	await frames()
	print("Playable Q / revival: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
