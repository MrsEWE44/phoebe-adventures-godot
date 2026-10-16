extends SceneTree
var checks := 0
var failures := 0
var campaign: Node
const Projectile = preload("res://Combat/projectile.gd")
const Weapons = preload("res://Weapons/weapon_registry.gd")

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	var world := Node2D.new()
	root.add_child(world)
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.position=Vector2(180,100)
	var collider:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(6,150)
	collider.shape=shape
	wall.add_child(collider)
	world.add_child(wall)
	await frames(2)
	var ball:=Projectile.new()
	ball.position=Vector2(100,100)
	ball.direction=Vector2.RIGHT
	ball.speed=500
	ball.distance_left=600
	ball.bounces_left=2
	ball.texture=preload("res://Weapons/chapter2_art.gd").texture(0)
	ball.hit_radius=5
	world.add_child(ball)
	await frames(15)
	check(is_instance_valid(ball) and ball.direction.x<0 and ball.bounces_left==1,"basketball physically reflects from terrain")
	check(is_instance_valid(ball) and ball.position.x<170,"bounced ball cannot pass through wall")
	if is_instance_valid(ball):ball.queue_free()
	var crab=load("res://Characters/Actors/reef_crab.tscn").instantiate()
	crab.position=Vector2(100,300)
	world.add_child(crab)
	crab.set_physics_process(false)
	crab.defense_rating=25 # Fixed armor isolates the 1.6x aquatic counter from level growth.
	var basic:=Projectile.new()
	basic.damage=20
	world.add_child(basic)
	var hp:float=crab.health
	basic._hit(crab.hurtbox)
	check(is_equal_approx(crab.health,hp-16),"ordinary projectile applies armor mitigation")
	crab.invulnerable=0
	var harpoon:=Projectile.new()
	harpoon.damage=20
	harpoon.aquatic_multiplier=1.6
	world.add_child(harpoon)
	hp=crab.health
	harpoon._hit(crab.hurtbox)
	check(is_equal_approx(crab.health,hp-25.6),"water weapon counter affects full-body damage area")
	crab.queue_free()
	campaign.profile.ikun_unlocked=true
	campaign.profile.character="ikun"
	var player=load("res://Player/Ikun.tscn").instantiate()
	player.position=Vector2(400,400)
	world.add_child(player)
	player.set_physics_process(false)
	check(player.definition.character_id=="ikun" and player.health==campaign.player_stats("ikun").health and player.energy==200,"new character inherits current level stats")
	check(player.normal_weapon.weapon_id=="basketball","independent default basketball equipped")
	player.facing=Vector2.RIGHT
	check(player.attack(true,false),"basketball skill can cast")
	check(is_instance_valid(player.basketball_skill) and campaign.profile.energy==180,"random basketball skill starts and spends energy")
	player.basketball_skill.queue_free()
	await frames(2)
	check(player.trigger_ultimate(Vector2.RIGHT),"ultimate casts")
	check(player.basketball_skill.boosted and campaign.ultimate_charges("ikun")==2,"ultimate boosts a random skill and spends a charge")
	player.invulnerable=0
	player.take_damage(10000)
	check(player.voice.last_event=="death","death plays designated voice event")
	player._physics_process(5)
	check(campaign.profile.character=="phoebe" and not player.is_dead,"death automatically switches to living teammate")
	check(player.hurtbox.collision_layer==16,"survivor remains damageable")
	for id in ["harpoon","coral_trident","torpedo"]:
		var spec:=Weapons.get_weapon(id)
		check(spec.aquatic_multiplier==1.6 and spec.texture!=null,"water weapon definition "+id)
	world.queue_free()
	await frames(3)
	print("Chapter2 combat checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
