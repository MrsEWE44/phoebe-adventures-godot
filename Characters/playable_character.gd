class_name PlayableCharacter
extends "res://Characters/character_base.gd"

var attack_timer := 0.0
var slash_timer := 0.0
var slash_direction := Vector2.RIGHT
var current_character := ""
@export var use_campaign_character := true
const Items = preload("res://Combat/items.gd")
const Projectile = preload("res://Combat/projectile.gd")
const Weapons = preload("res://Weapons/weapon_registry.gd")
var weapon_mount: Node2D
var normal_weapon: Resource
var combat_voice: Node
var defeat_resolved := false
var home_buff := false
var map_biome := "land"
var weapon_special_cooldowns: Dictionary = {}
var basketball_skill: Node2D
var last_basketball_skill := -1
var character_cooldowns: Dictionary={}
var _environment_key: Array=[]

func in_safe_circle() -> bool:
	return get_parent().has_method("is_spawn_safe") and get_parent().is_spawn_safe(position)

func is_action_locked() -> bool:
	return casting_remaining>0 or is_instance_valid(basketball_skill) or bool(get_meta("chapter3_dashing",false))

func refresh_environment() -> void:
	var world := get_parent()
	map_biome = str(world.get("biome")) if world.get("biome")!=null else ""
	home_buff = map_biome==definition.home_biome and world.get("allow_home_bonuses")!=false
	var key: Array=[definition,Campaign.player_level(),map_biome,home_buff,Campaign.equipment_bonus("speed_bonus")]
	if key==_environment_key: return
	_environment_key=key
	speed = definition.movement_speed*(definition.home_speed_multiplier if home_buff else 1.0)*(1.0+Campaign.equipment_bonus("speed_bonus"))
	ultimate = definition.ultimate.duplicate()
	ultimate.damage *= float(Campaign.player_stats(current_character).attack)/20.0
	ultimate.empowered = home_buff
	if home_buff:
		ultimate.damage *= 1.35
		ultimate.radius *= 1.35
		match str(definition.character_id):
			"phoebe": ultimate.pulse_count=3
			"nuonuo":
				ultimate.projectile_count=3
				ultimate.impact_radius=32
				ultimate.pierce=4

func attack_damage(base: float, skill := false) -> float:
	var multiplier: float = definition.home_skill_multiplier if skill and home_buff else (definition.home_damage_multiplier if home_buff else 1.0)
	multiplier *= Campaign.weapon_multiplier(normal_weapon.weapon_id)
	multiplier *= definition.damage_multiplier
	return base*multiplier*float(Campaign.player_stats(current_character).attack)/20.0

func damage_overdrive_active() -> bool:
	return not is_dead and Campaign.overdrive_remaining()>0

func _init() -> void:
	definition = preload("res://Characters/Definitions/phoebe.tres")

func _ready() -> void:
	super._ready()
	weapon_mount = preload("res://Weapons/weapon_mount.gd").new()
	add_child(weapon_mount)
	Campaign.profile_changed.connect(_refresh_character)
	Campaign.level_completed.connect(_on_level_completed)
	_refresh_character()
	voice.spoken.connect(_on_voice_started)
	combat_voice = preload("res://Characters/combat_voice.gd").new()
	add_child(combat_voice)
	Campaign.enemy_defeated.connect(combat_voice.defeated_enemy)
	if health <= 0:
		begin_death()
		death_remaining = death_delay

func _refresh_character() -> void:
	var selected := str(Campaign.profile.get("character", definition.character_id)) if use_campaign_character else str(definition.character_id)
	if selected != current_character or (use_campaign_character and definition!=Campaign.character_definition(selected)):
		if not current_character.is_empty(): character_cooldowns[current_character]=ultimate_cooldown
		ultimate_cooldown=float(character_cooldowns.get(selected,0.0))
		current_character = selected
		if combat_voice != null:
			combat_voice.reset_character()
		if use_campaign_character:
			definition = Campaign.character_definition(selected)
		apply_definition()
		voice.profile = definition.voice_profile
		note_activity()
		animated_sprite.play(&"down")
	max_health=float(Campaign.player_stats(selected).health)
	combat_level=Campaign.player_level()
	health = clampf(float(Campaign.profile.health),0,max_health)
	energy = clampi(int(Campaign.profile.energy),0,max_energy)
	injured = health <= max_health*.25
	ultimate_charges = Campaign.ultimate_charges(selected)
	if selected=="q_penguin": ultimate_cooldown=float(Campaign.profile.get("q_skill_cooldown",0))
	refresh_environment()
	normal_weapon = Weapons.get_weapon(Campaign.effective_weapon(selected))
	if casting_remaining <= 0:
		weapon_mount.equip(normal_weapon)


func _physics_process(_delta: float) -> void:
	Campaign.profile.q_skill_cooldown=maxf(0,float(Campaign.profile.get("q_skill_cooldown",0))-_delta)
	for id in character_cooldowns: character_cooldowns[id]=maxf(0,float(character_cooldowns[id])-_delta)
	for id in weapon_special_cooldowns: weapon_special_cooldowns[id]=maxf(0,float(weapon_special_cooldowns[id])-_delta)
	if is_dead:
		if Campaign.active_level==0: return
		death_remaining -= _delta
		if death_remaining <= 0 and not defeat_resolved:
			_resolve_defeat()
		return
	if bool(get_meta("chapter3_dashing",false)):
		tick_character(_delta)
		return
	if is_instance_valid(basketball_skill):
		tick_character(_delta)
		return
	attack_timer = maxf(0,attack_timer-_delta)
	slash_timer = maxf(0,slash_timer-_delta)
	super._physics_process(_delta)
	if current_character=="q_penguin": ultimate_cooldown=Campaign.profile.q_skill_cooldown
	if normal_weapon.auto_fire and attack_timer<=0 and not is_dead:
		var target: Node2D
		var distance:=500.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var d:=global_position.distance_to(enemy.combat_center())
			if d<distance and get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,enemy.combat_center(),2)).is_empty():
				target=enemy
				distance=d
		if target!=null:
			facing=global_position.direction_to(target.combat_center())
			attack(false,false)
	if casting_remaining <= 0 and weapon_mount.definition != normal_weapon:
		weapon_mount.equip(normal_weapon)
	animated_sprite.modulate.a = .5 if invulnerable > 0 and fmod(invulnerable,.16) < .08 else 1.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or Dialogue.active or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			attack(false,true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			attack(true,true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J: attack(false,true)
			KEY_K: attack(true,true)
			KEY_Q: Campaign.consume_potion(true)
			KEY_R: Campaign.consume_potion(false)
			KEY_2: Campaign.consume_item("health_large")
			KEY_3: Campaign.consume_item("energy_large")
			KEY_4: Campaign.consume_item("elixir")
			KEY_5: Campaign.consume_item("battle_overdrive")
			KEY_TAB:
				if casting_remaining <= 0:
					Campaign.switch_character()
			KEY_1: Campaign.cycle_weapon()
			KEY_G: drop_weapon()
			KEY_V: trigger_weapon_special()
			KEY_H: trigger_flying_kick()
			KEY_T: Campaign.consume_ultimate_potion()
		if ultimate != null and event.physical_keycode == ultimate.key:
			trigger_ultimate(global_position.direction_to(get_global_mouse_position()))

func attack(skill: bool = false, mouse_aim: bool = true) -> bool:
	if skill and current_character=="q_penguin":
		return fire_q_piercing(global_position.direction_to(get_global_mouse_position()) if mouse_aim else facing)
	if skill and normal_weapon.special_attack==WeaponDefinition.SpecialAttack.THUNDER_CRESCENT:
		return trigger_weapon_special(global_position.direction_to(get_global_mouse_position()) if mouse_aim else facing)
	note_activity()
	if is_dead or attack_timer > 0 or is_action_locked() or Dialogue.active or get_tree().paused:
		return false
	if in_safe_circle():
		Campaign.message.emit("离开蓝色复活圈后才能攻击。圈内可安全整理装备。")
		return false
	var weapon := Items.item(normal_weapon.weapon_id)
	var cost: int = 20 if skill else int(weapon.cost)
	if int(Campaign.profile.energy) < cost:
		Campaign.message.emit("技能能量不足，击败怪物寻找能量药剂。")
		voice.play_event("exhausted")
		return false
	Campaign.profile.energy = int(Campaign.profile.energy)-cost
	Story.note_action("skill" if skill else "attack")
	attack_timer = .8 if skill else float(weapon.cooldown)
	if home_buff: attack_timer /= definition.home_attack_speed_multiplier
	var aim := global_position.direction_to(get_global_mouse_position()) if mouse_aim else facing
	if aim.is_zero_approx():
		aim = facing
	slash_direction = aim
	if normal_weapon.weapon_id in preload("res://Scence/Chapter5/abilities.gd").IDS:
		preload("res://Scence/Chapter5/abilities.gd").play(self,aim,false)
		weapon_mount.fire(aim,false)
		Campaign.profile_changed.emit()
		return true
	if normal_weapon.weapon_id in preload("res://Scence/Chapter4/music_combat.gd").IDS:
		preload("res://Scence/Chapter4/music_combat.gd").play(self,aim,false)
		weapon_mount.fire(aim,false)
		Campaign.profile_changed.emit()
		return true
	if skill and (current_character in ["doro","gugu"] or normal_weapon.weapon_id=="penguin_rock"):
		if normal_weapon.weapon_id=="penguin_rock": preload("res://Scence/Chapter3/abilities.gd").stone_rain(self,aim)
		else: preload("res://Scence/Chapter3/abilities.gd").skill(self,aim)
		if current_character=="doro": play_chapter3_cast(aim)
		Campaign.profile_changed.emit()
		return true
	if skill and current_character=="ikun":
		last_basketball_skill=randi_range(0,1)
		basketball_skill=load("res://Combat/basketball_skill.gd").new()
		basketball_skill.actor=self
		basketball_skill.mode=last_basketball_skill
		basketball_skill.aim=aim
		get_parent().add_child(basketball_skill)
		Campaign.profile_changed.emit()
		voice.play_event("skill")
		return true
	var specification: Resource = normal_weapon
	var skill_spec: Resource = Weapons.get_weapon(definition.skill_weapon) if not definition.skill_weapon.is_empty() else null
	weapon_mount.fire(aim,not skill and weapon.kind == "melee")
	Global.play_sfx("shot")
	if skill or weapon.kind == "ranged":
		var count: int = int(definition.skill_projectiles) if skill else specification.pellets
		if skill and home_buff: count += 1
		var spread: float = .17*(count-1) if skill else deg_to_rad(specification.spread_degrees)
		var muzzle: Vector2 = weapon_mount.muzzle_position() if not skill else global_position+aim*14
		# Muzzles beyond a close wall must not spawn projectiles through it.
		var obstruction := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,muzzle,2))
		if not obstruction.is_empty():
			muzzle = obstruction.position-aim*2
		for i in count:
			var shot := Projectile.new()
			shot.source_actor=weakref(self)
			var angle: float = lerpf(-spread*.5,spread*.5,float(i)/(count-1)) if count>1 else randf_range(-spread*.5,spread*.5)
			shot.direction = aim.rotated(angle)
			shot.position = get_parent().to_local(muzzle)
			shot.damage = attack_damage(30 if skill else int(weapon.damage),skill)
			shot.damage_type = "magic" if skill else str(weapon.damage_type)
			shot.distance_left = 400 if skill else float(weapon.range)
			shot.texture = preload("res://Weapons/weapon_art.gd").texture(15) if skill else specification.projectile_texture
			shot.display_width = 18 if skill else specification.projectile_width
			shot.speed = 320 if skill else specification.projectile_speed
			shot.hit_radius = 0 if skill else specification.projectile_hit_radius
			shot.explosion_radius = 0 if skill else specification.explosion_radius
			shot.pierce_left = 0 if skill else specification.pierce
			shot.aquatic_multiplier = 1.0 if skill else specification.aquatic_multiplier
			shot.bounces_left = 0 if skill else specification.bounces
			shot.homing = not skill and specification.homing
			shot.boss_multiplier = specification.boss_multiplier
			shot.hit_effect = specification.hit_effect
			shot.target_multipliers = specification.target_multipliers
			if not skill:
				shot.target_health_ratios=specification.target_health_ratios
				shot.critical_chance=specification.critical_chance
				shot.critical_multiplier=specification.critical_multiplier
				shot.chain_targets=specification.chain_targets
				shot.chain_radius=specification.chain_radius
			if skill and skill_spec != null:
				shot.texture = skill_spec.projectile_texture
				shot.display_width = 18
				shot.hit_radius = 5
				shot.bounces_left = 3
				shot.pierce_left = 1
			get_parent().add_child(shot)
	else:
		slash_timer = .18
		if current_character=="gugu": play_chapter3_cast(aim)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var center: Vector2 = enemy.combat_center() if enemy.has_method("combat_center") else enemy.global_position
			var offset: Vector2 = center-(global_position+Vector2(0,-12))
			if offset.length() <= float(weapon.range) and (offset.length()<22 or aim.dot(offset.normalized()) > cos(specification.melee_half_angle)):
				var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-12),center,2)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					var amount := attack_damage(int(weapon.damage))
					if enemy.get("definition") != null and enemy.definition.aquatic:
						amount = (amount * specification.aquatic_multiplier)
					preload("res://Combat/player_damage.gd").hit(self,enemy,amount,str(weapon.damage_type))
					preload("res://Combat/weapon_status.gd").apply(enemy,specification.hit_effect,amount,self)
	Campaign.profile_changed.emit()
	if combat_voice != null:
		combat_voice.attacked()
	if skill:
		voice.play_event("skill")
	return true

func take_damage(amount: float, type: String = "physical") -> void:
	if not can_receive_damage() or amount <= 0:
		return
	if in_safe_circle(): return
	var defense: float=Campaign.player_defense(type)
	if home_buff: defense+=definition.home_defense*Campaign.Growth.defense_scale(combat_level)
	health=float(Campaign.profile.health)
	var received: float=amount if type=="true" else Campaign.Growth.mitigate(amount,defense,combat_level)
	super.take_damage(received,type)
	Campaign.profile.health = health
	invulnerable = .65
	if float(Campaign.profile.health) == 0:
		slash_timer = 0.0
		Campaign.mark_character_dead()
		death_remaining = maxf(death_delay,minf(3.0,voice.player.stream.get_length() if voice.player.stream!=null else death_delay))
		defeat_resolved = false
	elif combat_voice != null:
		combat_voice.hurt()

	Campaign.profile_changed.emit()

func play_chapter3_cast(aim: Vector2) -> void:
	if cast_sprite==null: return
	casting_remaining=.4
	ultimate_effect_pending=false
	animated_sprite.hide()
	if reaction_sprite!=null: reaction_sprite.hide()
	cast_sprite.show()
	cast_sprite.flip_h=aim.x>0
	cast_sprite.play("attack")
	cast_sprite.set_frame_and_progress(0,0)
	note_activity()

func trigger_ultimate(aim: Vector2 = Vector2.RIGHT) -> bool:
	if Dialogue.active or get_tree().paused or is_action_locked():
		return false
	if in_safe_circle() or get_parent().get("allow_ultimates")==false: return false
	if normal_weapon.weapon_id in preload("res://Scence/Chapter5/abilities.gd").IDS:
		if is_dead or ultimate_cooldown>0 or Campaign.ultimate_charges(current_character)<=0: return false
		Campaign.profile.ultimate_charges[current_character]=Campaign.ultimate_charges(current_character)-1
		ultimate_cooldown=12
		preload("res://Scence/Chapter5/abilities.gd").play(self,aim,true)
		ultimate_started.emit()
		Campaign.profile_changed.emit()
		Campaign.save_progress()
		return true
	if normal_weapon.weapon_id in preload("res://Scence/Chapter4/music_combat.gd").IDS:
		if is_dead: return false
		if normal_weapon.weapon_id=="conductor" and get_parent().has_method("conduct") and Campaign.active_level==37:
			return get_parent().conduct(self)
		if ultimate_cooldown>0 or Campaign.ultimate_charges(current_character)<=0: return false
		Campaign.profile.ultimate_charges[current_character]=Campaign.ultimate_charges(current_character)-1
		ultimate_cooldown=12
		preload("res://Scence/Chapter4/music_combat.gd").play(self,aim,true)
		ultimate_started.emit()
		Campaign.profile_changed.emit()
		Campaign.save_progress()
		return true
	if in_safe_circle() or get_parent().get("allow_ultimates")==false:
		Campaign.message.emit("当前区域禁止释放大招。")
		return false
	if current_character=="q_penguin": return fire_q_piercing(aim)
	if current_character in ["doro","gugu"]:
		if is_dead or ultimate_cooldown>0 or Campaign.ultimate_charges(current_character)<=0: return false
		Campaign.profile.ultimate_charges[current_character]=Campaign.ultimate_charges(current_character)-1
		ultimate_cooldown=ultimate.cooldown
		preload("res://Scence/Chapter3/abilities.gd").skill(self,aim,true)
		if current_character=="doro": play_chapter3_cast(aim)
		note_activity()
		ultimate_started.emit()
		stats_changed.emit()
		Campaign.profile_changed.emit()
		Campaign.save_progress()
		return true
	if current_character=="ikun":
		ultimate_charges=Campaign.ultimate_charges(current_character)
		if is_dead or ultimate_charges<=0 or ultimate_cooldown>0: return false
		ultimate_charges-=1
		Campaign.profile.ultimate_charges[current_character]=ultimate_charges
		ultimate_cooldown=ultimate.cooldown
		last_basketball_skill=randi_range(0,1)
		basketball_skill=load("res://Combat/basketball_skill.gd").new()
		basketball_skill.actor=self
		basketball_skill.mode=last_basketball_skill
		basketball_skill.aim=aim
		basketball_skill.boosted=true
		get_parent().add_child(basketball_skill)
		note_activity()
		voice.play_event("ultimate")
		ultimate_started.emit()
		stats_changed.emit()
		Campaign.profile_changed.emit()
		Campaign.save_progress()
		return true
	ultimate_charges = Campaign.ultimate_charges(current_character)
	if not super.trigger_ultimate(aim):
		Campaign.message.emit("大招暂不可用：等待冷却，或按 T 使用绝杀药剂。")
		return false
	note_activity()
	weapon_mount.equip(Weapons.get_weapon(ultimate.weapon_id))
	Campaign.profile.ultimate_charges[current_character] = ultimate_charges
	Campaign.profile_changed.emit()
	Campaign.save_progress()
	return true

func restore_health(amount: float) -> void:
	if not is_dead:
		Campaign.profile.health = minf(max_health,float(Campaign.profile.health)+amount)
		Campaign.profile_changed.emit()
		Campaign.save_progress()

func drop_weapon() -> bool:
	if is_dead or is_action_locked() or not definition.allowed_weapons.is_empty() or Dialogue.active or get_tree().paused:
		return false
	var id := str(Campaign.profile.equipped)
	if id==default_weapon or id not in Campaign.profile.weapons:
		return false
	var loot := preload("res://Combat/loot.gd").new()
	loot.item_id = id
	loot.position = position
	loot.pickup_delay = 1.0
	loot.dropped_by = self
	get_parent().add_child(loot)
	Campaign.profile.weapons.erase(id)
	Campaign.profile.equipped = Campaign.profile.weapons[0] if not Campaign.profile.weapons.is_empty() else "fists"
	Campaign.profile_changed.emit()
	Campaign.save_progress()
	note_activity()
	return true

func trigger_weapon_special(aim: Vector2 = Vector2.INF) -> bool:
	if is_dead or casting_remaining>0 or is_instance_valid(basketball_skill) or Dialogue.active or get_tree().paused or in_safe_circle(): return false
	if get_parent().get("allow_ultimates")==false: return false
	if normal_weapon.special_attack==0 or bool(get_meta("chapter3_dashing",false)): return false
	var direction: Vector2=aim if aim.is_finite() else global_position.direction_to(get_global_mouse_position())
	if current_character=="q_penguin": return fire_q_piercing(direction)
	if normal_weapon.special_attack in [WeaponDefinition.SpecialAttack.DECISIVE_CANNON,WeaponDefinition.SpecialAttack.EXPLOSIVE_ROUND]: return false
	if float(weapon_special_cooldowns.get(normal_weapon.weapon_id,0))>0:
		Campaign.message.emit("武器绝招正在冷却。")
		return false
	if int(Campaign.profile.energy)<normal_weapon.special_energy_cost:
		Campaign.message.emit("武器绝招能量不足。")
		return false
	Campaign.profile.energy-=normal_weapon.special_energy_cost
	weapon_special_cooldowns[normal_weapon.weapon_id]=normal_weapon.special_cooldown
	if normal_weapon.special_attack==WeaponDefinition.SpecialAttack.METEOR:
		preload("res://Scence/Chapter3/abilities.gd").meteor(self,direction)
		Campaign.profile_changed.emit()
		Campaign.save_progress()
		return true
	var effect=load("res://Combat/thunder_crescent.gd").new()
	effect.actor=self
	effect.spec=normal_weapon
	effect.aim=aim if aim.is_finite() else global_position.direction_to(get_global_mouse_position())
	get_parent().add_child(effect)
	note_activity()
	weapon_mount.fire(effect.aim,true)
	Campaign.message.emit(normal_weapon.special_name+"！")
	Campaign.profile_changed.emit()
	Campaign.save_progress()
	return true

func _draw() -> void:
	if slash_timer > 0:
		var reach := float(Items.item(str(Campaign.profile.equipped)).range)
		draw_arc(Vector2.ZERO,reach*.7,slash_direction.angle()-1.0,slash_direction.angle()+1.0,20,Color(1,.87,.54,slash_timer/.18),3)

@export_range(0.2,5.0,0.1) var death_delay := 1.2
var death_remaining := 0.0

func _respawn() -> void:
	Campaign.profile.health = max_health
	is_dead = false
	if hurtbox != null:
		hurtbox.set_deferred("collision_layer",16)
	injured = false
	reset_reaction()
	invulnerable = 2.0
	animated_sprite.modulate = Color.WHITE
	note_activity()
	if get_parent().has_method("respawn_player"):
		get_parent().respawn_player()
	_reset_after_revive()
	Campaign.profile_changed.emit()
	Campaign.message.emit("已回到本关入口，机关与装备进度保留。")

func _resolve_defeat() -> void:
	defeat_resolved = true
	if Campaign.switch_to_survivor():
		_reset_after_revive()
		injured = health <= max_health*.25
		reset_reaction()
		animated_sprite.modulate = Color.WHITE
		invulnerable = 2.0
		note_activity()
	else:
		var screen := preload("res://UI/defeat_screen.gd").new()
		screen.level_index = Campaign.active_level
		get_parent().add_child(screen)

func revive_from_item() -> void:
	_refresh_character()
	defeat_resolved=false
	death_remaining=death_delay
	_reset_after_revive()
	animated_sprite.modulate=Color.WHITE
	note_activity()
	voice.play_event("battle")

func fire_q_piercing(aim: Vector2) -> bool:
	if current_character!="q_penguin" or is_dead or is_action_locked() or get_tree().paused or Dialogue.active: return false
	if in_safe_circle() or get_parent().get("allow_ultimates")==false or float(Campaign.profile.q_skill_cooldown)>0: return false
	var spec:=Weapons.get_weapon("q_ak")
	var shot:=Projectile.new()
	shot.source_actor=weakref(self)
	shot.position=combat_center()
	shot.direction=aim.normalized() if not aim.is_zero_approx() else facing
	shot.damage=attack_damage(spec.special_damage,true)
	shot.explosion_radius=0
	shot.pierce_all=true
	shot.texture=spec.projectile_texture
	shot.display_width=24
	shot.hit_radius=5
	shot.speed=470
	shot.distance_left=650
	get_parent().add_child(shot)
	Campaign.profile.q_skill_cooldown=definition.ultimate.cooldown
	ultimate_cooldown=Campaign.profile.q_skill_cooldown
	play_chapter3_cast(shot.direction)
	weapon_mount.fire(shot.direction,false)
	voice.play_event("ultimate")
	Campaign.save_progress()
	return true

func _on_level_completed(_index: int) -> void:
	if not is_dead and use_campaign_character:
		voice.play_event("victory")

func express_emotion(event: String) -> void:
	if not is_dead:
		voice.play_event(event)

func _on_voice_started(_event: String, _slot: int, subtitle: String) -> void:
	if subtitle.is_empty(): return
	Campaign.message.emit(str(definition.display_name)+"："+subtitle)

func trigger_flying_kick(aim: Vector2=Vector2.ZERO) -> bool:
	if is_dead or is_action_locked() or Dialogue.active or get_tree().paused or in_safe_circle(): return false
	if get_parent().get("allow_ultimates")==false: return false
	if not Campaign.profile.get("gugu_unlocked",false) or current_character!="gugu": return false
	if float(weapon_special_cooldowns.get("flying_kick",0))>0 or Campaign.profile.energy<30: return false
	Campaign.profile.energy-=30
	weapon_special_cooldowns.flying_kick=9.0
	var dash=preload("res://Scence/Chapter3/flying_kick.tscn").instantiate()
	dash.actor=self
	dash.aim=aim if not aim.is_zero_approx() else global_position.direction_to(get_global_mouse_position())
	dash.damage=attack_damage(450,true)
	dash.friendly_fire=true
	get_parent().add_child(dash)
	Campaign.profile_changed.emit()
	return true

func _reset_after_revive() -> void:
	is_dead=false
	casting_remaining=0
	ultimate_effect_pending=false
	hit_remaining=0
	slow_remaining=0
	root_remaining=0
	dot_remaining=0
	velocity=Vector2.ZERO
	set_meta("chapter3_dashing",false)
	if is_instance_valid(basketball_skill): basketball_skill.queue_free()
	basketball_skill=null
	collision_layer=65
	collision_mask=62
	if hurtbox!=null: hurtbox.set_deferred("collision_layer",16)
	if cast_sprite!=null: cast_sprite.hide()
	animated_sprite.rotation=0
	animated_sprite.scale=definition.sprite_scale
	reset_reaction()
	invulnerable=2.0
	set_physics_process(false)
	_safe_revive_position.call_deferred()

func _safe_revive_position() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	var world:=get_parent()
	if world.get("geometry")!=null:
		var safe: Vector2=world.geometry.safe_spawn(position,self)
		if safe.is_finite(): position=safe
	set_physics_process(true)

func apply_status(slow: float, root_time:=0.0, damage_over_time:=0.0, duration:=4.0) -> void:
	super.apply_status(slow*(1.0-Campaign.equipment_bonus("slow_resist")),root_time,damage_over_time,duration)
