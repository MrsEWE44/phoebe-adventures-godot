extends SceneTree
const Registry = preload("res://Weapons/weapon_registry.gd")
const Items = preload("res://Combat/items.gd")
var checks := 0
var failures := 0
var world: Node2D
var hero: CharacterBody2D
var campaign: Node

class Target extends CharacterBody2D:
	var health := 1000
	func _ready():
		collision_layer = 4
		collision_mask = 0
		add_to_group("enemies")
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 7
		collider.shape = shape
		add_child(collider)
	func take_damage(amount: int,_type: String):
		health -= amount

func _initialize():
	call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func clear_shots():
	for shot in get_nodes_in_group("projectiles"):
		shot.queue_free()
	await process_frame
func target_at(p: Vector2) -> Target:
	var target := Target.new()
	target.position = p
	world.add_child(target)
	return target
func wall_at(p: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.position = p
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2,90)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	return wall
func projectile_at(p: Vector2, explosive := false, piercing := false):
	var shot = load("res://Combat/projectile.gd").new()
	shot.position = p
	shot.damage = 40
	shot.speed = 1000
	shot.explosion_radius = 50 if explosive else 0
	shot.pierce_left = 2 if piercing else 0
	world.add_child(shot)
	shot.set_physics_process(false)
	return shot

func run():
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	world = Node2D.new()
	root.add_child(world)
	hero = load("res://Player/Phoebe.tscn").instantiate()
	hero.position = Vector2(250,300)
	world.add_child(hero)
	hero.set_physics_process(false)
	hero.get_node("Camera2D").enabled = false
	check(Registry.all().size()==29 and not Registry.all().keys().any(func(id): return id in Registry.RETIRED),"retained and chapter-four music weapons are registered")
	check(campaign.profile.weapons.is_empty(),"no free starter weapon")
	for id in Registry.drop_ids():
		var weapon: Resource = Registry.get_weapon(id)
		check(weapon is WeaponDefinition,"shared weapon definition "+id)
		check(weapon.texture!=null and (weapon.kind=="melee" or weapon.projectile_texture!=null),"generated textures "+id)
		check(weapon.texture.region.end.x<=weapon.texture.atlas.get_width(),"atlas crop valid "+id)
		campaign.grant_drop(id)
		check(hero.weapon_mount.definition==weapon,"drop immediately updates held weapon "+id)
		hero.attack_timer = 0
		campaign.profile.energy = 200
		hero.facing = Vector2.RIGHT
		check(hero.attack(false,false),"weapon attacks "+id)
		check(campaign.profile.energy==200-weapon.energy_cost,"energy per trigger "+id)
		check(not hero.attack(false,false),"weapon cooldown "+id)
		if weapon.kind=="ranged":
			check(get_nodes_in_group("projectiles").size()==weapon.pellets,"pellet count "+id)
			for shot in get_nodes_in_group("projectiles"):
				check(shot.texture==weapon.projectile_texture and shot.speed==weapon.projectile_speed,"projectile inherits weapon configuration "+id)
		await clear_shots()
	var available: Dictionary = {}
	for index in range(1,28):
		for id in Registry.drops_for_level(index): available[id]=true
	for id in Registry.drop_ids():
		check(available.has(id)==(id in ["bronze_blade","iron_pistol","harpoon","coral_trident"]),"only chapter weapons are available in random loot "+id)
	hero.weapon_mount.update_aim(Vector2.UP)
	check(hero.weapon_mount.z_index>0 and hero.weapon_mount.position.y < -7,"upward weapon stays in front of hero")
	hero.weapon_mount.update_aim(Vector2.LEFT)
	check(hero.weapon_mount.sprite.flip_v and hero.weapon_mount.position.x<0,"left aim flips grip and orbit")
	hero.weapon_mount.update_aim(Vector2.DOWN)
	check(hero.weapon_mount.z_index>0 and hero.weapon_mount.position.y>0,"downward weapon in front")
	for character in ["phoebe","nuonuo"]:
		campaign.profile.character = character
		campaign.profile.health = 100
		campaign.profile_changed.emit()
		for state in [&"hit",&"hurt",&"death"]:
			check(hero.reaction_sprite.sprite_frames.get_frame_count(state)==4,"four generated frames "+character+" "+str(state))
		hero.invulnerable = 0
		hero.take_damage(80)
		check(hero.reaction_sprite.animation==&"hit" and hero.reaction_sprite.visible,"damage triggers hit animation "+character)
		hero.hit_remaining = 0
		hero.direction = Vector2.ZERO
		hero._update_reaction()
		check(hero.reaction_sprite.animation==&"hurt","low health triggers injured idle "+character)
		hero.direction = Vector2.RIGHT
		hero._update_reaction()
		check(hero.animated_sprite.visible and not hero.reaction_sprite.visible,"injured movement preserves walk animation "+character)
		hero.invulnerable = 0
		hero.take_damage(1000)
		check(hero.reaction_sprite.animation==&"death" and not hero.reaction_sprite.sprite_frames.get_animation_loop(&"death"),"death animation does not loop "+character)
		hero.weapon_mount.update_aim(Vector2.RIGHT)
		check(not hero.weapon_mount.visible,"death hides held weapon "+character)
		hero._respawn()
		check(hero.animated_sprite.visible and not hero.reaction_sprite.visible,"respawn restores walking sprite "+character)

	var first := target_at(Vector2(350,100))
	var second := target_at(Vector2(390,100))
	var wall := wall_at(Vector2(420,100))
	var behind := target_at(Vector2(450,100))
	await physics_frame
	await physics_frame
	var shot = projectile_at(Vector2(300,100),false,true)
	shot._physics_process(.2)
	check(first.health==960 and second.health==960,"sniper pierces two real targets in one sweep")
	check(behind.health==1000 and shot.spent,"piercing projectile still stops at a thin wall")
	await clear_shots()
	first.free()
	second.free()
	wall.free()
	behind.free()
	first = target_at(Vector2(350,100))
	second = target_at(Vector2(360,120))
	wall = wall_at(Vector2(378,100))
	behind = target_at(Vector2(389,100))
	await physics_frame
	await physics_frame
	shot = projectile_at(Vector2(300,100),true)
	shot._physics_process(.1)
	check(first.health==960 and second.health==960,"rocket explosion damages nearby targets once")
	check(behind.health==1000,"explosion does not damage through walls")
	await clear_shots()
	first.free()
	second.free()
	wall.free()
	behind.free()
	hero.position = Vector2(250,300)
	wall = wall_at(Vector2(270,300))
	behind = target_at(Vector2(310,293))
	campaign.profile.equipped = "iron_pistol"
	campaign.profile.energy = 200
	campaign.profile_changed.emit()
	hero.attack_timer = 0
	hero.facing = Vector2.RIGHT
	await physics_frame
	await physics_frame
	hero.attack(false,false)
	for bullet in get_nodes_in_group("projectiles"):
		bullet.set_physics_process(false)
		bullet._physics_process(.15)
	check(behind.health==1000,"close-wall muzzle cannot shoot through terrain")
	world.queue_free()
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.3).timeout
	print("WEAPONS / ANIMATIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
