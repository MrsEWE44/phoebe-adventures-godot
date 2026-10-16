extends SceneTree
class Arena extends Node2D:
	var player: Node2D
	var geometry: Node2D
	var level_index:=1
	var biome:="land"
	var adventure: Node
	func is_spawn_safe(p: Vector2) -> bool: return p.distance_to(Vector2(300,300))<64
var checks:=0
var failures:=0
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
func clear_projectiles() -> void:
	for shot in get_nodes_in_group("projectiles"): shot.queue_free()
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var arena:=Arena.new()
	root.add_child(arena)
	var terrain:=Node2D.new()
	arena.add_child(terrain)
	arena.geometry=load("res://Scence/Levels/geometry.gd").new()
	arena.add_child(arena.geometry)
	arena.geometry.build(terrain,Vector2(300,300),Vector2(600,600))
	arena.player=load("res://Player/Phoebe.tscn").instantiate()
	arena.player.position=Vector2(300,300)
	arena.add_child(arena.player)
	arena.player.set_physics_process(false)
	for id in ["sand_guard","thorn_shaman","tide_hunter","storm_jelly","sky_sentinel","wind_spirit"]:
		var enemy=load("res://Characters/Actors/%s.tscn"%id).instantiate()
		enemy.position=Vector2(440,300)
		enemy.level=arena
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.ultimate_cooldown=100
		await frames()
		check(enemy.character_type==1 and enemy.hurtbox_shape.shape.size.y>15,"new enemy is damageable with full body: "+id)
		check(enemy.sprite.sprite_frames.has_animation("walk"),"enemy reuses animated local artwork: "+id)
		var before: Vector2=enemy.position
		enemy.wander_timer=0
		enemy._physics_process(.05)
		check(not enemy.route.is_empty() and enemy.velocity.length()>0,"enemy patrols while player is safe: "+id)
		check(enemy.charge_windup==0 and get_nodes_in_group("projectiles").is_empty(),"safe circle prevents enemy targeting")
		# Direct engagement in an open arena, far from the safe circle.
		arena.player.position=Vector2(80,80)
		enemy.position=Vector2(180,80)
		enemy.route.clear()
		enemy.cooldown=0
		enemy.navigation_timer=0
		enemy._physics_process(.016)
		if enemy.definition.behavior=="charger":
			check(enemy.charge_windup>0,"charger shows a windup before dashing")
			enemy._physics_process(.61)
			check(enemy.charge_time>0,"charger transitions from windup to dash")
			enemy._physics_process(.05)
			check(enemy.velocity.length()>enemy.speed*2,"charge moves faster than normal movement")
		elif enemy.definition.ranged_attack:
			check(get_nodes_in_group("projectiles").size()==3,"ranged variant fires a three-shot fan")
		if enemy.definition.behavior=="orbit": check(enemy.velocity.dot(enemy.facing)<.1,"orbit variant strafes around player")
		clear_projectiles()
		enemy.queue_free()
		arena.player.position=Vector2(300,300)
		await frames()
	# A charged enemy must not cross into the protected circle.
	var charger=load("res://Characters/Actors/tide_hunter.tscn").instantiate()
	charger.position=Vector2(370,300)
	charger.level=arena
	arena.add_child(charger)
	charger.set_physics_process(false)
	charger.charge_direction=Vector2.LEFT
	charger.charge_time=.4
	await frames()
	var safe_hp: int=arena.player.health
	for i in 10: charger._physics_process(.03)
	check(not arena.is_spawn_safe(charger.position) and arena.player.health==safe_hp,"charging enemy cannot enter or damage safe circle")
	arena.queue_free()
	await frames()
	print("Expedition AI checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
