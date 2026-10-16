extends "res://Characters/character_base.gd"
## All monsters, animals and bosses share the same character contract as players.
const Frames = preload("res://Player/character_frames.gd")
const Projectile = preload("res://Combat/projectile.gd")
const Loot = preload("res://Combat/loot.gd")
var level: Node2D
var combat_target: Node2D
var kind := 0
@export var persistent_id := ""
var cooldown := 0.0
var navigation_timer := 0.0
var route := PackedVector2Array()
var sprite: AnimatedSprite2D
var attack_lock := 0.0
var death_timer := .7
var weapon_mount: Node2D
var dead: bool:
	get: return is_dead
var encounter_id := ""
var emerge_remaining := 0.0
var hit_flash := 0.0
var body_tint := Color.WHITE
var wander_origin := Vector2.ZERO
var wander_timer := 0.0
var charge_windup := 0.0
var charge_time := 0.0
var charge_direction := Vector2.RIGHT

func _ready() -> void:
	player_controlled = false
	idle_voice_enabled = false
	voice_profile = null
	character_type = CharacterType.ENEMY
	if definition==null:
		max_health = 28+(level.level_index if level!=null else 1)*6
		speed = 57 if kind==2 else 40
		ultimate = preload("res://Characters/Ultimates/creature.tres")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 2
	var collision := CollisionShape2D.new()
	collision.name = "FootCollision"
	var shape := RectangleShape2D.new()
	shape.size = definition.foot_size if definition!=null else Vector2(12,8)
	collision.position = definition.foot_offset if definition!=null else Vector2(0,-2)
	collision.shape = shape
	add_child(collision)
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	if definition!=null:
		sprite.sprite_frames = definition.animations
		sprite.scale = definition.sprite_scale
		sprite.position = definition.sprite_offset
	else:
		sprite.sprite_frames = Frames.creature(kind)
		sprite.scale = Vector2.ONE*(.11 if kind!=2 else .12)
		sprite.position.y = -9
	add_child(sprite)
	animated_sprite = sprite
	super._ready()
	# Ordinary creatures have no character dialogue or inherited player voice.
	voice_profile=null
	voice.profile=null
	if level!=null: scale_enemy(Campaign.encounter_level(level.level_index))
	sprite.frame_changed.connect(sync_hurtbox)
	sprite.animation_changed.connect(sync_hurtbox)
	sync_hurtbox()
	ultimate_cooldown = 4.0
	if definition!=null:
		weapon_mount = preload("res://Weapons/weapon_mount.gd").new()
		weapon_mount.aim_at_mouse = false
		weapon_mount.grip_offset = definition.sprite_offset+Vector2(0,-8)
		add_child(weapon_mount)
		weapon_mount.equip(preload("res://Weapons/weapon_registry.gd").get_weapon(default_weapon))
	wander_origin = position
	if definition!=null: body_tint=definition.body_tint
	_play(&"idle")
	if definition != null and definition.character_id in ["drowned_guard","tide_sorcerer"]:
		body_tint = Color(.5,.9,1)
		sprite.modulate = body_tint

func _physics_process(delta: float) -> void:
	if is_dead:
		death_timer -= delta
		if definition != null and definition.character_id in ["reef_crab","reef_shark","jellyfish","abyss_king"]:
			sprite.modulate.a = clampf(death_timer/.7,0,1)
			sprite.rotation = (.7-death_timer)*.65
		if death_timer<=0:
			queue_free()
		return
	if emerge_remaining>0:
		emerge_remaining = maxf(0,emerge_remaining-delta)
		sprite.modulate.a = 1-emerge_remaining*.6
		return
	tick_character(delta)
	if root_remaining>0 or is_dead: return
	hit_flash = maxf(0,hit_flash-delta)
	sprite.modulate = Color(1,.4,.4) if hit_flash>0 else body_tint
	if level==null or not is_instance_valid(level.player) or level.player.is_dead:
		return
	combat_target=preload("res://Combat/teams.gd").enemy_target(self,level)
	cooldown -= delta
	attack_lock = maxf(0,attack_lock-delta)
	navigation_timer -= delta
	var target: Vector2 = combat_target.position
	var distance := position.distance_to(target)
	facing = position.direction_to(target)
	sprite.flip_h = facing.x<0
	sync_hurtbox()
	velocity = Vector2.ZERO
	if casting_remaining>0:
		_play(&"ultimate")
		queue_redraw()
		return
	if charge_windup>0:
		charge_windup-=delta
		if charge_windup<=0: charge_time=.42
		queue_redraw()
		return
	if charge_time>0:
		charge_time-=delta
		velocity=charge_direction*speed*3*movement_factor()
		var before:=position
		move_and_slide()
		if level.has_method("is_spawn_safe") and level.is_spawn_safe(position): position=before
		if position.distance_to(combat_target.position)<30: combat_target.take_damage(outgoing(18),"physical")
		return
	var protected: bool=level.has_method("is_spawn_safe") and level.is_spawn_safe(target)
	if not protected and (combat_target.get("role")=="doro" or distance < (330 if character_type==CharacterType.BOSS else 260)):
		if definition!=null and definition.behavior=="charger" and cooldown<=0 and distance>45 and distance<170:
			charge_windup=.6
			charge_direction=facing
			cooldown=3.5
			queue_redraw()
			return
		if ultimate_charges>0 and ultimate_cooldown<=0 and distance<(180 if ultimate.mode=="shot" else ultimate.radius*.9):
			trigger_ultimate(facing)
			return
		if navigation_timer<=0:
			var ray := PhysicsRayQueryParameters2D.create(position,target,2)
			route = PackedVector2Array([target]) if get_world_2d().direct_space_state.intersect_ray(ray).is_empty() else level.geometry.path(position,target)
			navigation_timer = .6
		while not route.is_empty() and position.distance_to(route[0])<8:
			route.remove_at(0)
		var ranged: bool = kind==1 if definition==null else definition.ranged_attack or character_type==CharacterType.BOSS
		if not route.is_empty() and distance>(95 if ranged else 24):
			velocity = position.direction_to(route[0])*speed*movement_factor()
		if cooldown<=0:
			if ranged and distance<210:
				var projectile_count: int=definition.attack_projectiles if definition!=null else 1
				for projectile_index in projectile_count:
					var shot := Projectile.new()
					shot.position = position
					shot.direction = facing.rotated((projectile_index-(projectile_count-1)*.5)*.20)
					shot.hostile = true
					shot.damage = outgoing(9+mini(level.level_index,10))
					shot.damage_type = "magic"
					shot.speed = 125
					if definition != null and definition.aquatic:
						shot.texture = preload("res://Weapons/chapter2_art.gd").texture(7)
						shot.display_width = 16
					level.add_child(shot)
				cooldown = 1.8
				attack_lock = .5
				_play(&"attack")
			elif distance<28:
				var ray := PhysicsRayQueryParameters2D.create(global_position,combat_target.global_position,2)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					combat_target.take_damage(outgoing(8+mini(level.level_index,10)),"physical")
				cooldown = 1.0
				attack_lock = .5
				_play(&"attack")
	else:
		_patrol(delta)
	if definition!=null and definition.behavior=="orbit" and not protected and distance<170 and distance>55:
		velocity=facing.orthogonal()*speed*.75
	var before:=position
	move_and_slide()
	if level.has_method("is_spawn_safe") and level.is_spawn_safe(position):
		position=before
		velocity=Vector2.ZERO
		route.clear()
	sprite.flip_h = facing.x<0
	if attack_lock<=0:
		_play(&"walk" if velocity.length()>1 else &"idle")
	queue_redraw()

func _patrol(delta: float) -> void:
	wander_timer-=delta
	if wander_timer<=0:
		wander_timer=2.0+randf()*1.5
		var target: Vector2=level.geometry.nearest(wander_origin+Vector2.from_angle(randf()*TAU)*randf_range(35,95))
		if not level.has_method("is_spawn_safe") or not level.is_spawn_safe(target): route=level.geometry.path(position,target)
	while not route.is_empty() and position.distance_to(route[0])<8: route.remove_at(0)
	if not route.is_empty():
		velocity=position.direction_to(route[0])*speed*.55
		facing=velocity.normalized()

func sync_hurtbox() -> void:
	if definition == null or hurtbox == null: return
	var bounds := Rect2(definition.hurtbox_offset-definition.hurtbox_size*.5,definition.hurtbox_size)
	var frames: Array = definition.hurtbox_frames.get(str(sprite.animation),[])
	if not frames.is_empty(): bounds = frames[mini(sprite.frame,frames.size()-1)]
	hurtbox_shape.shape.size = bounds.size
	var center := bounds.get_center()
	# Flip around the sprite pivot, not around the actor's origin.
	if sprite.flip_h: center.x = sprite.position.x*2-center.x
	hurtbox.position = center
	queue_redraw()

func _play(animation: StringName) -> void:
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)
	else:
		sprite.play(&"default")

func take_damage(amount: float, type: String = "physical") -> void:
	if not can_receive_damage() or amount <= 0:
		return
	var received: float=amount if type=="true" else Campaign.Growth.mitigate(amount,defense_rating,combat_level)
	super.take_damage(received,type)
	if not is_dead:
		hit_flash = .18
		attack_lock = .25
		if casting_remaining<=0:
			_play(&"hit")
	queue_redraw()

func begin_death() -> void:
	if is_dead:
		return
	super.begin_death()
	remove_from_group("enemies")
	set_deferred("collision_layer",0)
	sprite.modulate = Color.WHITE
	_play(&"death")
	Campaign.award_experience(combat_level,character_type==CharacterType.BOSS)
	Campaign.profile.kills = int(Campaign.profile.kills)+1
	Campaign.profile.coins = int(Campaign.profile.coins)+roundi((25 if character_type==CharacterType.BOSS else 7)*(1+combat_level*.08))
	Campaign.profile_changed.emit()
	Campaign.enemy_defeated.emit()
	if level!=null and level.get("adventure")!=null and not encounter_id.is_empty():
		level.adventure.actor_died(self)
	var item_id:=preload("res://Combat/items.gd").enemy_drop(level.level_index if level!=null else 1,character_type==CharacterType.BOSS)
	if not item_id.is_empty():
		var loot := Loot.new()
		loot.item_id=item_id
		loot.position = position
		get_parent().call_deferred("add_child",loot)
	if character_type==CharacterType.BOSS and level!=null and not persistent_id.is_empty():
		var state: Dictionary = Campaign.level_state(level.level_index)
		if persistent_id not in state.bosses_defeated:
			state.bosses_defeated.append(persistent_id)
	Campaign.request_save()

func _draw() -> void:
	if charge_windup>0:
		draw_line(Vector2.ZERO,charge_direction*100,Color(1,.25,.2,.6),8)
	if not is_dead:
		var width := 44.0 if character_type==CharacterType.BOSS else 28.0
		var top: float = hurtbox.position.y-hurtbox_shape.shape.size.y*.5-8 if hurtbox!=null else -37.0
		draw_rect(Rect2(-width*.5,top,width,4),Color("422f36"))
		draw_rect(Rect2(-width*.5,top,width*float(health)/max_health,4),Color("f17b77"))
