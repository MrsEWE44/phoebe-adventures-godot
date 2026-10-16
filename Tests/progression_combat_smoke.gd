extends SceneTree
const Growth=preload("res://Characters/progression.gd")
const Status=preload("res://Combat/weapon_status.gd")
const Shop=preload("res://UI/shop_menu.gd")
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
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.profile.coins=100000
	var hub=load("res://Scence/Chapter3.tscn").instantiate()
	root.add_child(hub)
	hub.player.set_physics_process(false)
	var npc=hub.get_node("NPCs/Guide")
	var dialogue=root.get_node("Dialogue")
	campaign.profile.player_level=29
	Shop.open(npc,"weapons")
	check(dialogue.active and paused,"shop opens paused")
	dialogue.select("pili_blade")
	check(campaign.profile.coins==100000 and "pili_blade" not in campaign.profile.weapons,"Lv29 merchant rejects advanced weapon without charging")
	campaign.profile.player_level=30
	dialogue.select("pili_blade")
	check(campaign.profile.coins==99400 and "pili_blade" in campaign.profile.weapons,"Lv30 purchase charges exact price")
	dialogue.select("pili_blade")
	check(campaign.profile.coins==99400,"duplicate weapon purchase rejected")
	dialogue.select("next_stock")
	check(dialogue.choices[0].id=="shock_rifle","next merchant page opens")
	dialogue.select("shock_rifle")
	check(campaign.profile.coins==99120 and "shock_rifle" in campaign.profile.weapons,"element weapon bought through dialogue callback")
	dialogue.select("switch_stock")
	check(dialogue.choices[0].id=="health","category switches back to items")
	dialogue.select("health")
	check(campaign.profile.health_potions==1,"consumable purchase added to bag")
	dialogue.select("close")
	check(not paused and not dialogue.active,"leaving merchant restores gameplay")
	hub.queue_free()
	await frames()
	var arena=load("res://Scence/Levels/level_20.tscn").instantiate()
	arena.spawn_enemies=false
	root.add_child(arena)
	arena.set_process(false)
	var player=arena.player
	player.set_physics_process(false)
	player.position=arena.geometry.nearest(arena.get_node("ArenaCenter").position)
	player.weapon_mount.aim_at_mouse=false
	player.facing=Vector2.RIGHT
	var enemies: Array=[]
	for i in 4:
		var enemy=arena.spawn_kind("naiwa_mini",false,player.position+Vector2(65+i*22,0))
		enemy.set_physics_process(false)
		enemy.emerge_remaining=0
		enemies.append(enemy)
	await frames()
	var power: float=player.attack_damage(10)
	var initial: float=enemies[0].health
	Status.apply(enemies[0],"burn",power)
	enemies[0].tick_character(.1)
	check(enemies[0].health<initial and enemies[0].dot_remaining>3,"burn ticks scaled damage")
	Status.apply(enemies[0],"frost",power)
	check(is_equal_approx(enemies[0].root_remaining,.25) and enemies[0].movement_factor()==0,"boss freeze shorter and blocks movement")
	Status.apply(enemies[0],"shock",power)
	var damaged:=0
	for i in range(1,4):
		if enemies[i].health<enemies[i].max_health: damaged+=1
	check(damaged==2,"shock chains to exactly two nearby targets")
	var shot=load("res://Combat/projectile.gd").new()
	shot.position=player.position
	shot.damage=power
	shot.hit_effect="frost"
	arena.add_child(shot)
	shot.set_physics_process(false)
	shot._hit(enemies[3].hurtbox)
	check(enemies[3].root_remaining>0,"projectile forwards element effect through hurtbox")
	for enemy in enemies: enemy.queue_free()
	await frames()
	campaign.equip_weapon("shock_rifle")
	var normal: float=player.attack_damage(10)
	var skill: float=player.attack_damage(10,true)
	campaign.upgrade_weapon("shock_rifle")
	check(is_equal_approx(player.attack_damage(10),normal*1.1),"upgrade changes held weapon damage immediately")
	check(is_equal_approx(player.attack_damage(10,true),skill*1.1),"upgrade also scales weapon skill damage")
	campaign.equip_weapon("pili_blade")
	var boss=arena.spawn_kind("naiwa_mini",false,player.position+Vector2(85,0))
	boss.set_physics_process(false)
	boss.emerge_remaining=0
	await frames()
	var started: bool=player.trigger_weapon_special(Vector2.RIGHT)
	check(started,"thunder crescent can be released")
	await create_timer(.5).timeout
	check(boss.is_dead,"actual crescent sweep kills same-level Naiwa miniboss")
	var xp: int=campaign.profile.experience
	boss.take_damage(boss.max_health,"true")
	check(campaign.profile.experience==xp,"dead target cannot grant XP twice")
	var survivor=arena.spawn_kind("penguin_full",false,player.position+Vector2(-100,0))
	survivor.set_physics_process(false)
	survivor.take_damage(survivor.max_health*.2,"true")
	arena.snapshot()
	var record: Dictionary=survivor.record.duplicate(true)
	var hp: float=survivor.health
	var maximum: float=survivor.max_health
	survivor.queue_free()
	await frames()
	survivor=arena.restore_actor(record)
	survivor.set_physics_process(false)
	check(is_equal_approx(survivor.health,hp) and is_equal_approx(survivor.max_health,maximum),"restore does not heal or scale enemy twice")
	var cannon=load("res://Combat/projectile.gd").new()
	cannon.decisive=true
	cannon.pierce_left=100
	arena.add_child(cannon)
	cannon.set_physics_process(false)
	cannon._hit(survivor.hurtbox)
	check(is_equal_approx(survivor.health,hp-maximum*.5),"decisive cannon removes half scaled maximum HP")
	cannon._hit(survivor)
	check(is_equal_approx(survivor.health,hp-maximum*.5),"body and hurtbox cannot double decisive damage")
	check(Growth.number(Growth.stats(100).health)=="595" and Growth.number(100)=="100","health uses ordinary readable numbers")
	var level: int=survivor.combat_level
	campaign.profile.player_level=50
	check(campaign.encounter_level(20)==level,"ongoing encounter level stays stable after player growth")
	arena.queue_free()
	await frames()
	print("Progression combat/shop: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
