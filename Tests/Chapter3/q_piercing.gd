extends SceneTree
var checks:=0
var failures:=0
var world: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames() -> void:
	for i in 3:
		await physics_frame
		await process_frame
func enemy_at(center: Vector2) -> Node:
	var enemy=load("res://Characters/Actors/orc.tscn").instantiate()
	world.add_child(enemy)
	enemy.position+=center-enemy.combat_center()
	enemy.set_physics_process(false)
	enemy.health=100000
	enemy.max_health=100000
	enemy.defense_rating=0
	return enemy
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	campaign.hub_chapter=3
	campaign.active_level=24
	campaign.select_character("q_penguin")
	world=Node2D.new()
	root.add_child(world)
	var player=load("res://Player/Phoebe.tscn").instantiate()
	player.position=Vector2(100,300)
	world.add_child(player)
	player.set_physics_process(false)
	var origin: Vector2=player.combat_center()
	var row: Array=[]
	for offset in [70,140,210]: row.append(enemy_at(origin+Vector2(offset,0)))
	var side=enemy_at(origin+Vector2(140,70))
	var behind=enemy_at(origin+Vector2(380,0))
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=origin+Vector2(300,0)
	var shape:=CollisionShape2D.new()
	shape.shape=RectangleShape2D.new()
	shape.shape.size=Vector2(10,180)
	wall.add_child(shape)
	world.add_child(wall)
	await frames()
	check(player.trigger_ultimate(Vector2.RIGHT),"Q casts straight piercing skill")
	var shot: Node=get_nodes_in_group("projectiles")[0]
	shot.set_physics_process(false)
	var expected: float=player.attack_damage(900,true)
	check(shot.damage==expected and shot.damage_type=="physical","previous skill damage and damage type are unchanged")
	check(shot.pierce_all and shot.explosion_radius==0 and shot.direction==Vector2.RIGHT,"shot travels in aimed line without area explosion")
	check(campaign.profile.q_skill_cooldown==15 and not player.trigger_weapon_special(Vector2.RIGHT),"skill buttons share 15 second cooldown")
	for i in 8:
		if shot.spent: break
		shot._physics_process(.1)
	for enemy in row: check(is_equal_approx(enemy.health,100000-expected),"each enemy in line receives original damage exactly once")
	check(side.health==100000,"enemy outside line receives no splash damage")
	check(behind.health==100000 and shot.spent,"wall stops shot before enemy behind wall")
	world.queue_free()
	await frames()
	print("Q piercing skill: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
