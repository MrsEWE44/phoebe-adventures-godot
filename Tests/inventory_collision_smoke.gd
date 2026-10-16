extends SceneTree
var checks := 0
var failures := 0
class ChestWorld extends Node2D:
	var level_index := 1

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",title)
func frames(n := 2) -> void:
	for i in n:
		await physics_frame
		await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	var level = load("res://Scence/Levels/level_08.tscn").instantiate()
	level.spawn_enemies = false
	root.add_child(level)
	current_scene = level
	await frames()
	var hud: Node
	for child in level.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	var bag = hud.inventory_panel
	key(KEY_B)
	await frames()
	check(bag.visible and paused and not hud.pause_panel.visible,"B directly opens inventory and pauses combat")
	check(bag.tabs.size()==4,"four independent categories")
	check(bag.entries.size()==1 and bag.entries[0].id=="experience_crystal","only empty experience crystal shown before equipment or travel unlock")
	campaign.grant_drop("armor")
	check(bag.entries.size()==2 and bag.entries.any(func(e):return e.id=="armor"),"owned equipment appears alongside experience crystal")
	bag.select_category(1)
	check(bag.entries.size()==7 and bag.entries.all(func(e):return not e.enabled),"seven empty medicine slots including revival stone disable use")
	var maximum: float=campaign.player_stats().health
	campaign.profile.health = maximum*.4
	campaign.profile.energy = 20
	campaign.profile_changed.emit()
	campaign.grant_drop("health")
	bag.selected = "health"
	bag.activate_selected()
	check(is_equal_approx(campaign.profile.health,maximum*.8) and campaign.profile.health_potions==0 and is_equal_approx(level.player.health,maximum*.8),"medicine consumes once and refreshes live player")
	bag.activate_selected()
	check(is_equal_approx(campaign.profile.health,maximum*.8) and campaign.profile.health_potions==0,"empty medicine cannot be consumed twice")
	campaign.grant_drop("energy")
	bag.selected="energy"
	bag.activate_selected()
	check(campaign.profile.energy==90 and level.player.energy==90,"energy medicine applies while bag stays open")
	campaign.grant_drop("ultimate")
	bag.selected="ultimate"
	bag.activate_selected()
	check(campaign.ultimate_charges("phoebe")==4 and campaign.profile.ultimate_potions==0,"ultimate medicine updates charges")
	campaign.grant_drop("harpoon")
	bag.select_category(2)
	check(bag.entries.size()==2,"weapon category contains default plus acquired weapons")
	bag.selected="fists"
	bag.activate_selected()
	check(campaign.profile.equipped=="fists" and level.player.normal_weapon.weapon_id=="fists","equip default from bag")
	check(not campaign.equip_weapon("torpedo"),"cannot equip an unowned weapon")
	bag.confirm_destroy("harpoon")
	var confirmation: ConfirmationDialog
	for child in bag.get_children():
		if child is ConfirmationDialog: confirmation=child
	check(confirmation!=null and "harpoon" in campaign.profile.weapons,"destroy asks for confirmation and retains weapon until confirmed")
	confirmation.canceled.emit()
	await frames()
	check("harpoon" in campaign.profile.weapons,"cancel destroy preserves weapon")
	bag.confirm_destroy("harpoon")
	for child in bag.get_children():
		if child is ConfirmationDialog: child.confirmed.emit()
	await frames()
	check("harpoon" not in campaign.profile.weapons and bag.entries.size()==1,"confirmed destroy updates inventory immediately")
	bag.select_category(3)
	check(bag.entries.size()==campaign.CHARACTER_IDS.size() and not bag.entries[1].enabled,"locked characters display unlock requirements")
	check(not campaign.select_character("ikun"),"cannot select locked character")
	campaign.profile.ikun_unlocked=true
	campaign.profile.nuonuo_unlocked=true
	campaign.profile_changed.emit()
	bag.selected="ikun"
	bag.activate_selected()
	check(campaign.profile.character=="ikun" and level.player.definition.character_id=="ikun","select a specific third character directly")
	check(is_equal_approx(campaign.profile.party_health.phoebe,maximum*.8),"switch preserves previous health")
	campaign.profile.party_health.nuonuo=0
	check(not campaign.select_character("nuonuo"),"cannot revive a fallen character via inventory")
	key(KEY_ESCAPE)
	await frames()
	check(not bag.visible and not paused and not hud.pause_panel.visible,"Escape closes bag without opening pause menu")
	key(KEY_I)
	check(bag.visible and paused,"I is an alternate inventory key")
	key(KEY_B)
	check(not bag.visible and not paused,"B toggles bag closed")
	key(KEY_ESCAPE)
	check(hud.pause_panel.visible and not bag.visible,"Escape independently opens settings")
	key(KEY_B)
	check(bag.visible and not hud.pause_panel.visible and paused,"pause menu transfers ownership to inventory")
	key(KEY_B)
	paused=true
	key(KEY_ESCAPE)
	key(KEY_B)
	check(paused and not bag.visible and not hud.pause_panel.visible,"foreign modal pause cannot be dismissed by HUD")
	paused=false
	level.queue_free()
	await frames()
	current_scene=null
	# Independent world for precise chest range and terrain occlusion probes.
	var world := ChestWorld.new()
	root.add_child(world)
	var container := Node2D.new()
	world.add_child(container)
	var chest = load("res://Combat/chest.tscn").instantiate()
	chest.position=Vector2(200,200)
	container.add_child(chest)
	var actor := Node2D.new()
	world.add_child(actor)
	actor.position=Vector2(232,187)
	await frames()
	check(chest.interaction_distance(actor)<17,"chest range measures from visible side, not unrelated origin")
	actor.position=Vector2(260,187)
	check(is_inf(chest.interaction_distance(actor)),"distant chest cannot be opened")
	actor.position=Vector2(232,187)
	var wall := StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(224,187)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(2,50)
	collision.shape=shape
	wall.add_child(collision)
	world.add_child(wall)
	await frames()
	check(is_inf(chest.interaction_distance(actor)),"wall blocks chest interaction")
	wall.queue_free()
	await frames()
	chest.interact()
	chest.interact()
	check(campaign.profile.health_potions==1 and chest.opened,"chest opens exactly once")
	check(is_inf(chest.interaction_distance(actor)),"opened chest immediately stops receiving interaction")
	await create_timer(.7).timeout
	check(not is_instance_valid(chest),"opened chest removes its interaction area and sprite")
	# Mirrored and animated hurtboxes must stay over the sprite, with small feet.
	for id in ["beetle","snake","jackal","orc","demon","blood_monster","drowned_guard","tide_sorcerer","reef_crab","reef_shark","jellyfish","abyss_king"]:
		var enemy = load("res://Characters/Actors/"+id+".tscn").instantiate()
		enemy.position=Vector2(400,400)
		world.add_child(enemy)
		enemy.set_physics_process(false)
		var spec = enemy.definition
		check(not spec.hurtbox_frames.is_empty(),id+" has calibrated animation bounds")
		for animation in spec.hurtbox_frames:
			enemy.sprite.animation=animation
			for i in spec.hurtbox_frames[animation].size():
				enemy.sprite.frame=i
				enemy.sprite.flip_h=false
				enemy.sync_hurtbox()
				var center: Vector2=enemy.hurtbox.position
				enemy.sprite.flip_h=true
				enemy.sync_hurtbox()
				check(is_equal_approx(enemy.hurtbox.position.x,enemy.sprite.position.x*2-center.x) and is_equal_approx(enemy.hurtbox.position.y,center.y),id+" mirrored body stays aligned")
		var foot: CollisionShape2D=enemy.get_node("FootCollision")
		check(foot.shape.size.y<=8 and foot.shape.size.x<spec.hurtbox_size.x,id+" movement uses feet rather than full body")
		await frames()
		var query := PhysicsPointQueryParameters2D.new()
		query.position=enemy.combat_center()
		query.collision_mask=8
		query.collide_with_areas=true
		query.collide_with_bodies=false
		check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" physical hit query finds aligned body")
		enemy.queue_free()
		await frames()
	world.queue_free()
	await frames()
	print("Inventory/collision checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
