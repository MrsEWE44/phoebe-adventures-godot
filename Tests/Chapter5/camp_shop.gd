extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	var d=root.get_node("Dialogue")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	for chapter in [4,5]:
		c.reset_state(60)
		c.active_level=0
		c.hub_chapter=chapter
		c.profile.coins=10000
		var world=load(c.Catalog.hub_path(chapter)).instantiate()
		root.add_child(world)
		await physics_frame
		await process_frame
		await process_frame
		var merchants=world.get_node("NPCs").get_children().filter(func(n):return n.service_role=="merchant")
		ck(merchants.size()==1,"one merchant in chapter "+str(chapter))
		var npc=merchants[0]
		var expected: String="巡演补给商" if chapter==4 else "余烬补给官"
		ck(npc.display_name==expected,"merchant display name")
		ck(npc.get_children().any(func(n):return n is Label and n.text==expected+" · E"),"overhead label matches dialogue")
		npc.interact()
		ck(d.active and d.speaker_label.text==expected,"merchant greeting")
		d.select("items")
		ck(d.active and d.speaker_label.text==expected and d.choices.any(func(o):return o.id=="experience_crystal"),"item store opens")
		var count: int=c.item_count("experience_crystal")
		var coins: int=c.profile.coins
		d.select("experience_crystal")
		ck(c.item_count("experience_crystal")==count+1,"purchase grants item")
		ck(c.profile.coins==coins-int(c.Shop.STOCK.experience_crystal.price),"purchase deducts exact price")
		ck(d.active and d.speaker_label.text==expected,"store remains open after purchase")
		d.select("next_stock")
		ck(d.choices.any(func(o):return o.id=="previous_stock"),"next stock page")
		d.select("previous_stock")
		ck(d.choices.any(func(o):return o.id=="experience_crystal"),"previous stock page")
		d.select("switch_stock")
		ck(d.active and d.choices.any(func(o):return o.id in c.Shop.entries("weapons")),"switch to weapons")
		d.close()
		ck(not paused,"closing resumes game")
		npc.interact()
		d.select("weapons")
		ck(d.active and d.speaker_label.text==expected,"direct weapon store opens")
		d.close()
		world.queue_free()
		await process_frame
		await process_frame
	print("CAMP SHOP: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
