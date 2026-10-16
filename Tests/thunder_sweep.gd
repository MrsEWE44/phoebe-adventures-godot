extends SceneTree
var checks:=0
var failures:=0
class TestWorld extends Node2D:
	var background:=Sprite2D.new()
var world: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func enemy_at(point: Vector2) -> Node:
	var enemy=load("res://Characters/Actors/orc.tscn").instantiate()
	enemy.position=point
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health=5000
	enemy.max_health=5000
	enemy.defense_rating=100000
	return enemy
func run() -> void:
	root.size=Vector2i(1280,720)
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.active_level=18
	world=TestWorld.new()
	root.add_child(world)
	world.add_child(world.background)
	var player=load("res://Player/Phoebe.tscn").instantiate()
	player.position=Vector2(100,300)
	world.add_child(player)
	player.set_physics_process(false)
	player.facing=Vector2.RIGHT
	campaign.grant_drop("pili_blade")
	campaign.equip_weapon("pili_blade")
	var hud=load("res://UI/game_hud.gd").new()
	hud.world=world
	world.add_child(hud)
	hud._process(.2)
	check(hud.weapon_special_button.visible and not hud.weapon_special_button.disabled and hud.weapon_special_button.text.contains("一刀999"),"dedicated clickable weapon skill button")
	var upper=enemy_at(Vector2(280,160))
	var lower=enemy_at(Vector2(300,450))
	var far=enemy_at(Vector2(300,590))
	await frames()
	var charges: int=campaign.ultimate_charges("phoebe")
	check(player.attack(true,false),"right click/K dispatches weapon's crescent")
	check(campaign.profile.energy==160 and campaign.ultimate_charges("phoebe")==charges,"weapon skill spends 40 energy and no character charges")
	check(not player.trigger_weapon_special(Vector2.RIGHT),"right click and V share cooldown")
	var wave: Node=get_nodes_in_group("weapon_specials")[0]
	wave.set_physics_process(false)
	wave._physics_process(.18)
	wave._physics_process(.3)
	check(upper.health==4001 and lower.health==4001 and far.health==5000,"wide sweep deals exactly 999 true damage and respects radius")
	check(wave.damage==999,"fixed skill damage ignores player growth")
	wave._physics_process(.1)
	check(upper.health==4001 and lower.health==4001,"same sweep cannot hit a target twice")
	wave.queue_free()
	for enemy in [upper,lower,far]: enemy.queue_free()
	await frames()
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(220,290)
	var collider:=CollisionShape2D.new()
	collider.shape=RectangleShape2D.new()
	collider.shape.size=Vector2(12,500)
	wall.add_child(collider)
	world.add_child(wall)
	var behind=enemy_at(Vector2(280,300))
	var npc=load("res://Characters/Actors/soldier.tscn").instantiate()
	npc.position=Vector2(150,300)
	world.add_child(npc)
	npc.set_physics_process(false)
	var hp: float=npc.health
	await frames()
	player.weapon_special_cooldowns.clear()
	campaign.profile.player_level=100
	campaign.profile.weapon_upgrades.pili_blade=10
	campaign.profile_changed.emit()
	hud._process(.2)
	hud.weapon_special_button.pressed.emit()
	check(get_nodes_in_group("weapon_specials").size()==1,"HUD button casts actual crescent effect")
	wave=get_nodes_in_group("weapon_specials")[0]
	check(wave.damage==999,"level 100 and +10 weapon still deal fixed 999")
	wave.set_physics_process(false)
	wave._physics_process(.6)
	check(behind.health==5000 and npc.health==hp,"sweep stops at walls and excludes neutral NPCs")
	hud._process(.2)
	check(hud.weapon_special_button.disabled and hud.weapon_special_button.text.contains("冷却"),"button shows shared cooldown")
	world.queue_free()
	await frames()
	print("Thunder crescent sweep: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
