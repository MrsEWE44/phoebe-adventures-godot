extends "res://Characters/character_base.gd"
@export var role: String="mutsumi"
var level: Node2D
var protected:=false
var captive:=false
var record: Dictionary={}
var fire_clock:=1.0
var path_clock:=0.0
var taunt_clock:=8.0
var path:=PackedVector2Array()
var corpse_time:=1.2
func _ready() -> void:
	definition=Campaign.character_definition(role)
	player_controlled=false
	idle_voice_enabled=false
	super._ready()
	player_controlled=false
	character_type=CharacterType.NPC if captive else CharacterType.PLAYER
	$Cage.visible=captive
	configure_hurtbox()
	collision_layer=0
	collision_mask=2
	max_health=900 if protected else 650
	health=clampf(float(record.get("hp",max_health)),0,max_health)
	if not captive: add_to_group("allies")
	voice.play_event("dialogue")
	if protected:
		var instrument:=Sprite2D.new()
		instrument.name="StageInstrument"
		var id: String={"mutsumi":"pink_cello","anon":"voice_wave","soyo":"ivory_cello"}.get(role,"voice_wave")
		var weapon: Resource=preload("res://Weapons/weapon_registry.gd").get_weapon(id)
		instrument.texture=weapon.texture
		if instrument.texture!=null: instrument.scale=Vector2.ONE*32.0/maxf(1,instrument.texture.get_height())
		instrument.position=Vector2(18,-22)
		add_child(instrument)
	if health<=0:
		begin_death()
		if protected: level.fail_ensemble.call_deferred()
func _physics_process(delta: float) -> void:
	if is_dead:
		corpse_time-=delta
		if corpse_time<=0:
			hide()
			if not voice.player.playing: queue_free()
		return
	if captive: return
	tick_character(delta)
	hit_remaining=maxf(0,hit_remaining-delta)
	_update_reaction()
	fire_clock-=delta
	taunt_clock-=delta
	path_clock-=delta
	var target: Node2D
	var distance:=INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_parent()!=level or enemy.is_dead: continue
		var d:=position.distance_to(enemy.position)
		if d<distance: distance=d;target=enemy
	if target==null: return
	if role.begins_with("penguin") and distance<330 and taunt_clock<=0:
		taunt_clock=randf_range(12,17) if voice.play_event("taunt") else 1.5
	if not protected:
		if path_clock<=0:
			path=level.geometry.path(position,target.position)
			path_clock=.6
		while not path.is_empty() and position.distance_to(path[0])<10: path.remove_at(0)
		direction=position.direction_to(path[0]) if not path.is_empty() and distance>110 else Vector2.ZERO
		velocity=direction*100*movement_factor()
		_update_animation()
		move_and_slide()
	if fire_clock<=0 and distance<330:
		fire_clock=1.2
		if not role.begins_with("penguin") or get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(combat_center(),target.combat_center(),2)).is_empty():
			if role.begins_with("penguin"):
				var stone=preload("res://Combat/projectile.gd").new()
				stone.position=combat_center()
				stone.direction=combat_center().direction_to(target.combat_center())
				stone.damage=150
				stone.texture=preload("res://Weapons/chapter3_art.gd").texture(5)
				stone.speed=300
				stone.display_width=24
				stone.hit_radius=7
				level.add_child(stone)
			elif shield_active() and target.definition.character_id.begins_with("naiwa"):
				level.assimilate(target,true)
			else: target.take_damage(100 if protected else 150,"magic")
			var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
			wave.position=combat_center()
			wave.radius=distance
			wave.line=true
			wave.direction=combat_center().direction_to(target.combat_center())
			level.add_child(wave)
	record.hp=health
	queue_redraw()
func take_damage(amount: float, type: String="physical") -> void:
	if captive: return
	super.take_damage(amount*(.02 if shield_active() else .45),type)
	record.hp=health
	if is_dead and protected: level.fail_ensemble()
func shield_active() -> bool:
	return protected and level.level_index==37 and bool(level.state.get("ensemble_active",false)) and not is_dead
func begin_death() -> void:
	if is_dead: return
	super.begin_death()
	record.hp=0
	remove_from_group("allies")
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)
	Campaign.request_save()
func interact() -> void:
	Dialogue.open(definition.display_name,["解除这里的控制，完成战斗后我会加入你。" if captive else "我会帮你牵制敌人，请留意首领蓄力的红色标记。"],[],self)
	voice.play_event("dialogue")
func _draw() -> void:
	if protected and not is_dead:
		if shield_active():
			draw_circle(Vector2(0,-30),43,Color(.25,.75,1,.18))
			draw_arc(Vector2(0,-30),43,0,TAU,48,Color("8beaff"),2.5)
			draw_string(ThemeDB.fallback_font,Vector2(-28,-80),"护盾 98%",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("bff6ff"))
		draw_circle(Vector2.ZERO,23,Color(.3,.8,1,.14))
		draw_arc(Vector2.ZERO,23,0,TAU,32,Color("aefcff"),2)
	if not captive and not is_dead:
		draw_rect(Rect2(-27,-72,54,5),Color("293344"))
		draw_rect(Rect2(-27,-72,54*health/max_health,5),Color("80ffd4"))
