extends SceneTree
var checks:=0
var failures:=0
var world: Node2D
class TestWorld extends Node2D:
	var background:=Sprite2D.new()
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
	enemy.max_health=5000
	enemy.health=5000
	return enemy
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.active_level=27
	campaign.profile.gugu_unlocked=true
	campaign.profile.weapons.append("penguin_rock")
	world=TestWorld.new()
	root.add_child(world)
	world.add_child(world.background)
	var player=load("res://Player/Phoebe.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	campaign.select_character("gugu")
	player.position=Vector2(100,300)
	player.invulnerable=999
	var original: Transform2D=player.animated_sprite.transform
	var original_mask: int=player.collision_mask
	var row: Array=[]
	for x in [175,255,335]: row.append(enemy_at(Vector2(x,300)))
	var outside=enemy_at(Vector2(230,480))
	var npc=load("res://Characters/Actors/soldier.tscn").instantiate()
	npc.position=Vector2(210,300)
	world.add_child(npc)
	npc.set_physics_process(false)
	var npc_hp: float=npc.health
	await frames()
	check(player.trigger_flying_kick(Vector2.RIGHT),"Gugu inherited kick starts")
	var kick=get_nodes_in_group("flying_kicks")[0]
	kick.set_physics_process(false)
	kick._physics_process(.2)
	check(player.position==Vector2(100,300) and kick.get_node("Leg/WebbedFoot").visible,"windup shows extended foot before movement")
	check(player.is_action_locked() and campaign.profile.energy==170 and not player.trigger_flying_kick(Vector2.RIGHT),"one energy cost and action lock prevent double cast")
	for i in 5: kick._physics_process(.1)
	check(row.all(func(e): return e.health<5000) and outside.health==5000,"straight sweep hits every enemy in line only")
	var hp: float=row[1].health
	kick._physics_process(0)
	check(row[1].health==hp and npc.health==npc_hp,"each target hit once and neutral NPC immune")
	for i in 5: kick._physics_process(.1)
	await frames()
	check(not player.is_action_locked() and player.collision_mask==original_mask and player.animated_sprite.transform.is_equal_approx(original),"completion restores movement, collision and animation transform")
	check(not player.trigger_flying_kick(Vector2.RIGHT),"nine-second cooldown remains after dash")
	player.position=Vector2(100,300)
	player.weapon_special_cooldowns.clear()
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(190,300)
	var collider:=CollisionShape2D.new()
	collider.shape=RectangleShape2D.new()
	collider.shape.size=Vector2(12,400)
	wall.add_child(collider)
	world.add_child(wall)
	var before: float=row[1].health
	await frames()
	player.trigger_flying_kick(Vector2.RIGHT)
	kick=get_nodes_in_group("flying_kicks")[0]
	kick.set_physics_process(false)
	kick._physics_process(.7)
	await frames()
	check(player.position.x<190 and row[1].health==before and not player.is_action_locked(),"wall stops dash and blocks damage behind it")
	player.weapon_special_cooldowns.clear()
	player.trigger_flying_kick(Vector2.LEFT)
	kick=get_nodes_in_group("flying_kicks")[0]
	kick.set_physics_process(false)
	player.is_dead=true
	kick._physics_process(.1)
	await frames()
	check(not player.get_meta("chapter3_dashing",false) and player.collision_mask==original_mask,"death cancels dash and releases movement lock")
	world.queue_free()
	await frames()
	campaign.reset_state()
	var arena=load("res://Scence/Levels/level_27.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	arena.video_started=true
	var boss=arena.spawn_kind("penguin_full",false)
	boss.set_physics_process(false)
	boss.target_point=boss.position+Vector2.RIGHT*300
	boss.execute("kick")
	check(get_nodes_in_group("flying_kicks").size()==1,"full boss casts shared animated flying kick")
	var mini=arena.spawn_kind("penguin_mini",false)
	mini.set_physics_process(false)
	check(not mini.ability_allowed("kick") and boss.ability_allowed("kick"),"only full form has complete kick ability")
	arena.queue_free()
	await frames()
	print("Flying kick: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
