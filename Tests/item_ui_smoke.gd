extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames() -> void:
	for i in 3:
		await process_frame
		await physics_frame
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
func click(button: Button) -> void:
	var at:=button.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new()
	move.position=at
	root.push_input(move)
	var event:=InputEventMouseButton.new()
	event.position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
func run() -> void:
	root.size=Vector2i(1280,720)
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.profile.coins=10000
	var hub=load("res://Scence/Chapter3.tscn").instantiate()
	root.add_child(hub)
	hub.player.set_physics_process(false)
	var hud: Node
	for child in hub.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	for id in campaign.Shop.STOCK:
		var data: Dictionary=campaign.Items.item(id)
		check(data.get("texture") is Texture2D and data.texture.get_width()>0,"shop item has a usable icon: "+id)
	for id in ["health","energy","ultimate","health_large","energy_large","elixir","armor","amulet","diving_armor"]:
		campaign.grant_drop(id)
		if id in ["health_large","energy_large","elixir"]: campaign.grant_drop(id)
	campaign.profile.health=campaign.player_stats().health*.1
	campaign.profile.energy=0
	campaign.profile_changed.emit()
	await frames()
	check(hud.consumable_bar.buttons.values().filter(func(button):return button.visible).size()==6,"six visible medicine slots before fourth-chapter unlock")
	for id in hud.consumable_bar.buttons:
		var button: Button=hud.consumable_bar.buttons[id]
		if id=="battle_overdrive":
			check(not button.visible and button.icon!=null,"locked war song stays hidden with its icon ready")
			continue
		check(button.icon!=null and button.text.contains("× %d"%campaign.item_count(id)),"quick slot icon and quantity: "+id)
	var shots:=get_nodes_in_group("projectiles").size()
	click(hud.consumable_bar.buttons.health_large)
	await frames()
	check(campaign.item_count("health_large")==1 and is_equal_approx(campaign.profile.health,campaign.player_stats().health*.9),"mouse click consumes one large heal and restores 80 percent")
	check(get_nodes_in_group("projectiles").size()==shots,"clicking potion UI does not fire weapon")
	key(KEY_3)
	check(campaign.item_count("energy_large")==1 and campaign.profile.energy==200,"key 3 uses large energy bottle")
	campaign.profile.health=campaign.player_stats().health*.2
	key(KEY_2)
	check(campaign.item_count("health_large")==0 and is_equal_approx(campaign.profile.health,campaign.player_stats().health),"key 2 uses remaining large heal")
	campaign.profile.energy=0
	key(KEY_4)
	check(campaign.item_count("elixir")==1 and campaign.profile.energy==200,"key 4 uses elixir")
	hud.consumable_bar.refresh()
	check(hud.consumable_bar.buttons.health_large.disabled and hud.consumable_bar.buttons.energy_large.disabled,"empty or unneeded medicine disables button")
	hud.consumable_bar.use_item("energy_large")
	check(campaign.item_count("energy_large")==1,"full energy cannot waste a bottle")
	campaign.profile.energy=0
	paused=true
	hud.consumable_bar.use_item("energy_large")
	check(campaign.item_count("energy_large")==1,"quick bar cannot consume through another modal")
	paused=false
	var dialogue=root.get_node("Dialogue")
	var stock: Array=campaign.Shop.entries("items")
	preload("res://UI/shop_menu.gd").open(hub.get_node("NPCs/Guide"),"items",stock.find("health_large")/4)
	var purchase_button: Button
	for button in dialogue.choices_box.get_children():
		if button.get_meta("choice_id")=="health_large": purchase_button=button
	check(purchase_button!=null and purchase_button.icon!=null and purchase_button.text.contains("持有 ×0"),"merchant button displays icon and owned count")
	purchase_button.pressed.emit()
	check(campaign.item_count("health_large")==1,"merchant button purchases item")
	for button in dialogue.choices_box.get_children():
		if button.get_meta("choice_id")=="health_large": purchase_button=button
	check(purchase_button.text.contains("持有 ×1"),"merchant quantity refreshes after purchase")
	dialogue.close()
	hud.toggle_inventory()
	var bag=hud.inventory_panel
	for category in [0,1,2]:
		bag.select_category(category)
		for entry in bag.entries:
			check(entry.icon!=null and entry.tag.contains("×"),"inventory icon and count: "+entry.id)
	bag.select_category(1)
	bag.selected="energy_large"
	bag.refresh()
	var use_button: Button
	for child in bag.detail.get_children():
		if child is Button and child.text=="立即使用": use_button=child
	check(use_button!=null and not use_button.disabled,"bag presents enabled use button for large energy bottle")
	use_button.pressed.emit()
	check(campaign.item_count("energy_large")==0 and campaign.profile.energy==200,"bag use button consumes exactly once")
	check(bag.entries.any(func(entry): return entry.id=="energy_large" and entry.tag=="× 0" and not entry.enabled),"bag count and enabled state immediately refresh")
	hud.toggle_inventory()
	campaign.profile.health=0
	check(not campaign.consume_item("elixir") and campaign.item_count("elixir")==1,"medicine cannot revive a dead character")
	campaign.save_path="res://.godot/item-ui-save.json"
	campaign.saving_enabled=true
	campaign.save_progress()
	campaign.saving_enabled=false
	check(campaign.load_progress() and campaign.item_count("health_large")==1 and campaign.item_count("energy_large")==0,"item counts survive save and reload")
	hub.queue_free()
	await frames()
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer: child.stop()
	await create_timer(.3).timeout
	print("Item UI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
