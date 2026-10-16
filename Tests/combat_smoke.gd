extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state(1)
	var level = load("res://Scence/Levels/level_01.tscn").instantiate()
	level.spawn_enemies = false
	root.add_child(level)
	await physics_frame
	await process_frame
	var player = level.player
	player.position = Vector2(836,480)
	player.facing = Vector2.RIGHT
	var enemy = load("res://Combat/enemy.gd").new()
	enemy.level = level
	enemy.position = Vector2(868,480)
	level.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await process_frame
	check(campaign.profile.weapons.is_empty(),"no free starter weapon")
	var hp: int = enemy.health
	check(player.attack(false,false),"bare hand attack")
	check(enemy.health<hp,"melee hits enemy")
	check(not player.attack(false,false),"cooldown prevents repeated damage")
	enemy.take_damage(100,"magic")
	await process_frame
	await process_frame
	check(get_nodes_in_group("loot").size()<=1,"dead enemy may drop at most one random item")
	for drop in get_nodes_in_group("loot"): drop.queue_free()
	await process_frame
	var pickup=load("res://Combat/loot.gd").new()
	pickup.item_id="bronze_blade"
	pickup.position=Vector2(868,480)
	level.add_child(pickup)
	player.position = Vector2(868,480)
	await create_timer(.5).timeout
	check(campaign.profile.weapons.has("bronze_blade"),"pickup equips monster weapon")
	check(get_nodes_in_group("loot").is_empty(),"drop consumed once")
	campaign.profile.health = 100
	player.invulnerable = 0
	player.take_damage(20,"physical")
	var first_hit: float=100-campaign.profile.health
	check(first_hit>0 and first_hit<20,"base defense mitigates physical damage")
	player.take_damage(20,"physical")
	check(is_equal_approx(campaign.profile.health,100-first_hit),"invulnerability prevents double hit")
	campaign.grant_drop("armor")
	var health_before: float=campaign.profile.health
	player.invulnerable = 0
	player.take_damage(20,"physical")
	check(health_before-campaign.profile.health>0 and health_before-campaign.profile.health<first_hit,"armor reduces incoming damage")
	player.invulnerable = 0
	health_before=campaign.profile.health
	player.take_damage(20,"magic")
	var magic_before: float=health_before-campaign.profile.health
	campaign.grant_drop("amulet")
	health_before=campaign.profile.health
	player.invulnerable = 0
	player.take_damage(20,"magic")
	check(health_before-campaign.profile.health>0 and health_before-campaign.profile.health<magic_before,"amulet reduces magic damage")
	campaign.profile.health=campaign.player_stats().health-5
	campaign.grant_drop("health")
	check(campaign.consume_potion(true) and campaign.profile.health==campaign.player_stats().health,"health potion restores and clamps")
	check(not campaign.consume_potion(true),"cannot consume missing potion")
	campaign.grant_drop("rune_staff")
	check(campaign.equip_weapon("rune_staff"),"new loot is equipped explicitly")
	campaign.profile.energy = 200
	player.attack_timer = 0
	check(player.attack(false,false) and campaign.profile.energy==194,"magic weapon consumes energy")
	player.attack_timer = 0
	campaign.profile.energy = 0
	check(not player.attack(true,false),"no skill without energy")
	campaign.grant_drop("energy")
	check(campaign.consume_potion(false) and campaign.profile.energy==70,"energy potion")
	player.attack_timer = 0
	check(player.attack(true,false) and campaign.profile.energy==50,"character skill")
	check(not campaign.switch_character(),"nuonuo locked initially")
	player.invulnerable = 0
	player.take_damage(999,"magic")
	check(campaign.profile.health==0 and player.is_dead,"death state exposes empty health bar")
	check(player.voice.last_event=="death","empty health plays death voice")
	player._physics_process(4)
	check(campaign.profile.health==0 and player.is_dead and paused,"defeat shows choice rather than automatic respawn")
	paused = false
	check(campaign.profile.weapons.has("rune_staff"),"equipment survives death")
	level.queue_free()
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.25).timeout
	print("COMBAT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
