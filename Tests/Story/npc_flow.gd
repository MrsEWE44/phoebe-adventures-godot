extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames() -> void:
	for i in 3:
		await process_frame
		await physics_frame
func run() -> void:
	var campaign=root.get_node("Campaign")
	var story=root.get_node("Story")
	var dialogue=root.get_node("Dialogue")
	campaign.saving_enabled=false
	story.automatic_enabled=true
	for index in range(1,28):
		campaign.reset_state()
		# Old saves already marked the former Phoebe narration as seen.
		story.progress().seen.append(str(index)+":intro")
		var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		level.spawn_enemies=false
		root.add_child(level)
		level.player.set_physics_process(false)
		var start: Vector2=level.player.position
		await frames()
		check(dialogue.active and paused and dialogue.speaker_label.text==story.npc_name(index)+" · 剧情引导","automatic NPC speaker for stage %d"%index)
		check(dialogue.content_label.text.contains(story.entry(index).briefing) and not dialogue.choices.is_empty(),"unique NPC briefing and buttons for stage %d"%index)
		check(level.player.position==start and get_nodes_in_group("enemies").is_empty(),"briefing does not require movement or spawn enemies")
		dialogue.select(story.entry(index).intro.choices[0].id)
		check(story.last_voice_character==story.entry(index).intro.choices[0].get("speaker","phoebe"),"choice plays correct character response")
		dialogue.close()
		var npcs: Array=get_nodes_in_group("story_guides").filter(func(n): return n.get_parent()==level)
		var expected:=4 if index in [1,5,6,15,16,23,24,25,26,27] else 3
		check(npcs.size()==expected,"service roster count stage %d"%index)
		var roles: Array=[]
		for npc in npcs:
			check(npc.service_role not in roles,"each service occurs once per stage")
			roles.append(npc.service_role)
			check(not npc.can_receive_damage() and npc.collision_layer==0,"NPC is neutral and never blocks walking")
			check(level.geometry.path(start,npc.position).size()>1,"NPC reachable before opening doors stage %d"%index)
			for chest in get_nodes_in_group("chests"):
				if level.is_ancestor_of(chest): check(npc.global_position.distance_to(chest.global_position)>=48,"services leave chest interaction space")
			for other in npcs:
				if npc!=other: check(npc.position.distance_to(other.position)>=36,"NPCs do not overlap")
			npc.interact()
			check(dialogue.active and dialogue.source==npc,"service opens its own interaction")
			if npc.service_role=="guide": check(not dialogue.choices.any(func(o): return o.id in ["items","mechanisms","heal","upgrade"]),"guide only handles story")
			if npc.service_role=="puzzle":
				dialogue.select("mechanisms")
				check(dialogue.content_label.text.contains("提示"),"scholar gives progressive hints")
			if npc.service_role=="merchant":
				campaign.profile.coins=50
				var before: int=campaign.item_count("health")
				dialogue.select("items")
				dialogue.select("health")
				check(campaign.profile.coins==38 and campaign.item_count("health")==before+1,"merchant really sells consumables")
			if npc.service_role=="medic":
				campaign.profile.health=campaign.player_stats().health
				dialogue.select("heal")
				check(not campaign.level_state(index).get("medic_used",false),"full health does not spend treatment")
				campaign.profile.health=20
				dialogue.select("heal")
				var healed: float=campaign.profile.health
				dialogue.select("heal")
				check(healed>20 and campaign.profile.health==healed and campaign.level_state(index).medic_used,"treatment cannot be farmed")
			if npc.service_role=="smith":
				campaign.profile.coins=1000
				var cost: int=campaign.upgrade_cost("fists")
				dialogue.select("upgrade")
				check(campaign.weapon_upgrade("fists")==1 and campaign.profile.coins==1000-cost,"smith charges for real weapon reinforcement")
			dialogue.close()
		if index>=18:
			var merchant=level.get_node("Service_merchant")
			level.player.position=merchant.position
			var event:=InputEventKey.new()
			event.pressed=true
			event.physical_keycode=KEY_E
			level._unhandled_input(event)
			check(dialogue.source==merchant,"E chooses nearest NPC instead of first guide")
			dialogue.close()
		level.queue_free()
		await frames()
		level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
		level.spawn_enemies=false
		root.add_child(level)
		await frames()
		check(dialogue.active and dialogue.content_label.text.contains("你回来了"),"every real reentry greets automatically")
		dialogue.select("recap")
		check(dialogue.content_label.text.contains(story.entry(index).briefing),"repeat greeting can replay full NPC story")
		dialogue.close()
		level.queue_free()
		await frames()
	print("NPC briefing and services: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
