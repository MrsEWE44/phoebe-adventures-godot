extends SceneTree
var checks:=0
var failures:=0
var campaign: Node
var world: Node2D
var player: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func frames(n:=2) -> void:
	for i in n:
		await process_frame
		await physics_frame
func enemy_at(point: Vector2) -> Node2D:
	var enemy=load("res://Characters/Actors/orc.tscn").instantiate()
	enemy.position=point
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.max_health=1000
	enemy.health=1000
	return enemy
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	world=Node2D.new()
	root.add_child(world)
	player=load("res://Player/Phoebe.tscn").instantiate()
	player.position=Vector2(100,100)
	world.add_child(player)
	player.set_physics_process(false)
	campaign.profile.ikun_unlocked=true
	campaign.profile.nuonuo_unlocked=true
	campaign.grant_drop("iron_pistol")
	check(campaign.select_character("ikun"),"select Ikun")
	check(player.normal_weapon.weapon_id=="basketball","switch ignores previous gun")
	check(not campaign.equip_weapon("iron_pistol"),"cannot equip gun")
	campaign.grant_drop("pili_blade")
	check(player.normal_weapon.weapon_id=="basketball" and "pili_blade" in campaign.profile.weapons,"pickup stores blade without equipping")
	campaign.cycle_weapon()
	check(player.normal_weapon.weapon_id=="basketball" and not player.drop_weapon(),"cycle/drop cannot remove exclusive basketball")
	var seen: Dictionary={}
	for i in 24:
		player.attack_timer=0
		campaign.profile.energy=200
		check(player.attack(true,false),"random skill starts")
		seen[player.last_basketball_skill]=true
		check(not campaign.select_character("nuonuo"),"cannot switch during dribble/pass")
		player.basketball_skill.queue_free()
		await frames(1)
	check(seen.size()==2,"random selection exercises both basketball skills")
	# Straight pass damages a line of enemies and never explodes sideways.
	var a=enemy_at(Vector2(220,100))
	var b=enemy_at(Vector2(290,100))
	var side=enemy_at(Vector2(240,175))
	await frames()
	var skill=load("res://Combat/basketball_skill.gd").new()
	skill.actor=player
	skill.aim=Vector2.RIGHT
	skill.mode=0
	player.basketball_skill=skill
	world.add_child(skill)
	skill.set_physics_process(false)
	skill._physics_process(.3)
	await frames(1)
	for shot in get_nodes_in_group("projectiles"):
		check(shot.explosion_radius==0 and shot.bounces_left==0 and shot.damage>=130,"pass has high damage, no AoE or bounce")
	await frames(25)
	check(a.health<1000 and b.health<1000 and side.health==1000,"pass pierces line only")
	for enemy in [a,b,side]: enemy.queue_free()
	for shot in get_nodes_in_group("projectiles"): shot.queue_free()
	await frames()
	# The elevated pass origin must not spawn on the far side of a close horizontal wall.
	var muzzle_wall:=StaticBody2D.new()
	muzzle_wall.collision_layer=2
	muzzle_wall.position=Vector2(100,91)
	var muzzle_shape:=CollisionShape2D.new()
	muzzle_shape.shape=RectangleShape2D.new()
	muzzle_shape.shape.size=Vector2(160,4)
	muzzle_wall.add_child(muzzle_shape)
	world.add_child(muzzle_wall)
	var beyond=enemy_at(Vector2(100,45))
	await frames()
	skill=load("res://Combat/basketball_skill.gd").new()
	skill.actor=player
	skill.aim=Vector2.UP
	skill.mode=0
	player.basketball_skill=skill
	world.add_child(skill)
	await frames(40)
	check(beyond.health==1000,"close-wall pass cannot spawn through terrain")
	beyond.queue_free()
	muzzle_wall.queue_free()
	await frames()
	# Drive damages adjacent targets once, moves actor, and respects terrain.
	player.position=Vector2(100,100)
	var near=enemy_at(Vector2(155,125))
	var far=enemy_at(Vector2(155,250))
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(230,100)
	var shape:=CollisionShape2D.new()
	shape.shape=RectangleShape2D.new()
	shape.shape.size=Vector2(10,180)
	wall.add_child(shape)
	world.add_child(wall)
	await frames()
	skill=load("res://Combat/basketball_skill.gd").new()
	skill.actor=player
	skill.aim=Vector2.RIGHT
	skill.mode=1
	player.basketball_skill=skill
	world.add_child(skill)
	await frames(85)
	check(player.position.x>110 and player.position.x<225,"dribble advances but cannot cross wall")
	check(near.health==900 and far.health==1000,"dribble AoE hits nearby targets once")
	check(not is_instance_valid(player.basketball_skill),"dribble releases movement lock")
	near.queue_free()
	far.queue_free()
	wall.queue_free()
	await frames()
	# NPC upgrades act on the effective basketball, not a previous character's gun.
	campaign.profile.equipped="iron_pistol"
	campaign.level_state(1).encounters={"smith":{"kind":"npc","gift_kind":"upgrade","gift_claimed":false,"cleared":true,"actors":[]}}
	campaign.claim_encounter_gift(1,"smith")
	check(campaign.weapon_upgrade("basketball")==1 and campaign.weapon_upgrade("iron_pistol")==0,"NPC upgrades exclusive equipped basketball")
	# Character ultimate uses the same two variants with a damage boost.
	var charges: int=campaign.ultimate_charges("ikun")
	check(player.trigger_ultimate(Vector2.RIGHT) and player.basketball_skill.boosted,"Ikun ultimate boosts one of the two skills")
	check(campaign.ultimate_charges("ikun")==charges-1,"ultimate spends one charge")
	player.basketball_skill.queue_free()
	await frames()
	check(campaign.select_character("nuonuo") and campaign.equip_weapon("pili_blade"),"other characters can equip special blade")
	player.position=Vector2(100,100)
	root.warp_mouse(Vector2(500,100))
	var close=enemy_at(Vector2(220,120))
	var distant=enemy_at(Vector2(220,300))
	await frames()
	var energy: int=campaign.profile.energy
	var ult: int=campaign.ultimate_charges("nuonuo")
	check(player.trigger_weapon_special(Vector2.RIGHT),"weapon special casts independently")
	check(campaign.profile.energy==energy-45 and campaign.ultimate_charges("nuonuo")==ult,"weapon special consumes energy, not character charges")
	check(not player.trigger_weapon_special(),"weapon special cooldown blocks repeat")
	await frames(60)
	check(close.health<1000 and distant.health==1000,"animated crescent deals bounded area damage")
	close.queue_free()
	distant.queue_free()
	# A wall blocks the entire special; neutral NPCs remain immune.
	wall=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(180,100)
	shape=CollisionShape2D.new()
	shape.shape=RectangleShape2D.new()
	shape.shape.size=Vector2(10,250)
	wall.add_child(shape)
	world.add_child(wall)
	var behind=enemy_at(Vector2(215,100))
	var npc=load("res://Characters/Actors/soldier.tscn").instantiate()
	npc.position=Vector2(140,100)
	world.add_child(npc)
	npc.set_physics_process(false)
	var npc_hp: int=npc.health
	await frames()
	player.weapon_special_cooldowns.clear()
	check(player.trigger_weapon_special(Vector2.RIGHT),"wall test casts crescent")
	await frames(60)
	check(behind.health==1000 and npc.health==npc_hp,"crescent cannot hit through walls or hurt neutral NPCs")
	wall.queue_free()
	behind.queue_free()
	npc.queue_free()
	for id in ["nuonuo","ikun"]:
		campaign.select_character(id)
		player.direction=Vector2.RIGHT
		player._update_animation()
		player.animated_sprite.set_frame_and_progress(0,0)
		await create_timer(.15).timeout
		check(player.animated_sprite.is_playing() and player.animated_sprite.frame>0,"in-game walk advances frames "+id)
		var spec: Resource=campaign.character_definition(id)
		for animation in ["down","left","up"]:
			check(spec.animations.get_frame_count(animation)==4,"four walk frames "+id+"/"+animation)
			var hashes: Dictionary={}
			for i in 4:
				var tex: Texture2D=spec.animations.get_frame_texture(animation,i)
				hashes[hash(tex.get_image().get_data())]=true
			check(hashes.size()>=3,"walk frames contain different pixels "+id+"/"+animation)
	# Death cancels a pending pass before its projectile can appear.
	skill=load("res://Combat/basketball_skill.gd").new()
	skill.actor=player
	skill.mode=0
	player.basketball_skill=skill
	world.add_child(skill)
	player.invulnerable=0
	player.take_damage(10000)
	await frames(3)
	check(not is_instance_valid(player.basketball_skill) and not player.weapon_mount.visible,"death cancels pending skill and hides basketball")
	check(get_nodes_in_group("projectiles").is_empty(),"cancelled pass emits no projectile")
	world.queue_free()
	await frames()
	# A real legacy save may still hold the prior character's gun in equipped.
	campaign.reset_state()
	var catalog=load("res://Scence/Levels/catalog.gd")
	for index in range(8,17):
		campaign.level_state(index).doors=catalog.all_door_ids(index)
		campaign.level_state(index).adventure_version=0
		campaign.completed.append(index)
	campaign.profile.character="ikun"
	campaign.profile.weapons=["iron_pistol","pili_blade"]
	campaign.profile.equipped="iron_pistol"
	campaign.save_path="res://.godot/combat_update_save.json"
	campaign.saving_enabled=true
	check(campaign.save_progress() and campaign.load_progress(),"legacy weapon save round-trip")
	check(campaign.profile.character=="ikun" and campaign.effective_weapon()=="basketball","reload ignores incompatible saved gun for Ikun")
	var bag=load("res://UI/inventory.gd").new()
	root.add_child(bag)
	bag.category=2
	var entries: Array=bag.build_entries()
	check(entries.any(func(entry): return entry.id=="iron_pistol" and not entry.enabled),"backpack disables incompatible gun after reload")
	campaign.select_character("phoebe")
	check(campaign.effective_weapon()=="iron_pistol","switching back preserves previous character's weapon")
	bag.queue_free()
	await frames()
	campaign.saving_enabled=false
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(campaign.save_path+suffix)
	print("Combat update checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
