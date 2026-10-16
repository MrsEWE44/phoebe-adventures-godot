class_name GameCharacter
extends CharacterBody2D
## All players, enemies, neutral NPCs and bosses inherit this character contract.
signal died
signal stats_changed
signal ultimate_started
enum CharacterType { PLAYER, ENEMY, NPC, BOSS }
@export var definition: Resource
## Authored actor scenes own their collision shapes; definitions never resize them.
@export var use_scene_collision_shapes := false
@export var character_type: CharacterType = CharacterType.PLAYER
@export var max_health := 100.0
@export var max_energy := 200
@export var default_weapon := "fists"
@export var ultimate: Resource
var health := 100.0
var energy := 200
var ultimate_charges := 3
var ultimate_cooldown := 0.0
var casting_remaining := 0.0
var ultimate_effect_pending := false
var ultimate_direction := Vector2.RIGHT
var cast_sprite: AnimatedSprite2D
var invulnerable := 0.0
@export_range(0.0,1000.0,1.0) var speed := 100.0
@export var player_controlled := true
@export var idle_voice_enabled := true
@export_range(0.1,60.0,.1) var idle_voice_delay := 4.0
@export var voice_profile: Resource = preload("res://Characters/Voices/phoebe.tres")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
var voice: Node
var direction := Vector2.ZERO
var facing := Vector2.DOWN
var idle_elapsed := 0.0
var idle_announced := false
var is_dead := false
var injured := false
var hit_remaining := 0.0
var reaction_sprite: AnimatedSprite2D
var hurtbox: Area2D
var hurtbox_shape: CollisionShape2D
var slow_remaining:=0.0
var root_remaining:=0.0
var dot_remaining:=0.0
var dot_clock:=0.0
var dot_damage:=0.0
var combat_level:=1
var damage_scale:=1.0
var defense_rating:=0.0
var frozen_remaining:=0.0
func scale_enemy(level_value: int) -> void:
	combat_level=level_value
	var growth=preload("res://Characters/progression.gd")
	damage_scale=growth.enemy_attack_scale(combat_level)
	max_health*=growth.enemy_health_scale(combat_level,str(definition.character_id) if definition!=null else "")
	health=max_health
	defense_rating=(20.0 if character_type==CharacterType.BOSS else 6.0)*growth.defense_scale(combat_level)
	if ultimate!=null:
		ultimate=ultimate.duplicate()
		ultimate.damage*=damage_scale

func outgoing(base: float) -> float:
	return base*damage_scale*(.65 if Time.get_ticks_msec()<int(get_meta("music_weakened_until",0)) else 1.0)

func apply_status(slow: float, root_time:=0.0, damage_over_time:=0.0, duration:=4.0) -> void:
	if is_dead or character_type==CharacterType.NPC: return
	slow_remaining=maxf(slow_remaining,slow)
	root_remaining=maxf(root_remaining,root_time)
	if damage_over_time>0:
		dot_remaining=maxf(dot_remaining,duration)
		dot_damage=maxf(dot_damage,damage_over_time)
func movement_factor() -> float:
	return 0.0 if root_remaining>0 else (.5 if slow_remaining>0 else 1.0)

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	if definition != null:
		apply_definition()
	health = max_health
	energy = max_energy
	if ultimate != null:
		ultimate_charges = clampi(ultimate.initial_charges,0,ultimate.max_charges)
	add_to_group("characters")
	configure_hurtbox()
	voice = preload("res://Audio/character_voice.gd").new()
	voice.name = "CharacterVoice"
	voice.profile = voice_profile
	add_child(voice)

func _input(event: InputEvent) -> void:
	if not player_controlled or is_dead:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length()>2):
		note_activity()

func note_activity() -> void:
	idle_elapsed = 0.0
	idle_announced = false

func _physics_process(delta: float) -> void:
	tick_character(delta)
	if is_dead:
		return
	if player_controlled:
		direction = Input.get_vector("left","right","up","down")
	if not direction.is_zero_approx():
		facing = direction
		note_activity()
	velocity = direction * speed * movement_factor()
	hit_remaining = maxf(0,hit_remaining-delta)
	_update_reaction()
	_update_animation()
	move_and_slide()
	_update_idle(delta)

func _update_idle(delta: float) -> void:
	if not idle_voice_enabled or not player_controlled or is_dead or get_tree().paused:
		return
	idle_elapsed += delta
	if idle_elapsed > idle_voice_delay and not idle_announced:
		idle_announced = voice.play_event("idle")

func _update_animation() -> void:
	if animated_sprite.sprite_frames == null or casting_remaining > 0:
		return
	if direction.is_zero_approx():
		if animated_sprite.sprite_frames.has_animation(&"idle"):
			animated_sprite.play(&"idle")
		else:
			animated_sprite.stop()
		return
	var animation: StringName = &"left" if not is_zero_approx(direction.x) else (&"down" if direction.y>0 else &"up")
	animated_sprite.flip_h = direction.x>0 if animation==&"left" else false
	if animation == &"left" and definition != null and definition.faces_right:
		animated_sprite.flip_h = direction.x < 0
	if not animated_sprite.sprite_frames.has_animation(animation):
		animation = &"walk" if animated_sprite.sprite_frames.has_animation(&"walk") else &"default"
	animated_sprite.play(animation)

func begin_death() -> void:
	if is_dead:
		return
	is_dead = true
	if hurtbox != null:
		hurtbox.set_deferred("collision_layer",0)
	casting_remaining = 0
	ultimate_effect_pending = false
	if cast_sprite != null:
		cast_sprite.hide()
	velocity = Vector2.ZERO
	animated_sprite.stop()
	animated_sprite.modulate = Color(.6,.6,.65,.55)
	play_reaction(&"death")
	voice.play_event("death")
	died.emit()

func configure_reactions(frames: SpriteFrames, sprite_scale: Vector2, offset: Vector2) -> void:
	if reaction_sprite == null:
		reaction_sprite = AnimatedSprite2D.new()
		reaction_sprite.name = "ReactionSprite"
		reaction_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(reaction_sprite)
	reaction_sprite.sprite_frames = frames
	reaction_sprite.scale = sprite_scale
	reaction_sprite.position = offset
	reset_reaction()

func play_reaction(animation: StringName) -> void:
	if casting_remaining > 0 and animation != &"death":
		return
	if reaction_sprite == null or reaction_sprite.sprite_frames == null or not reaction_sprite.sprite_frames.has_animation(animation):
		return
	animated_sprite.hide()
	reaction_sprite.show()
	reaction_sprite.flip_h = facing.x > 0
	reaction_sprite.play(animation)
	if animation in [&"hit",&"death"]:
		reaction_sprite.set_frame_and_progress(0,0)
	if animation == &"hit":
		hit_remaining = .4

func reset_reaction() -> void:
	hit_remaining = 0
	if reaction_sprite != null:
		reaction_sprite.stop()
		reaction_sprite.hide()
	animated_sprite.show()

func _update_reaction() -> void:
	if reaction_sprite == null or is_dead or hit_remaining > 0 or casting_remaining > 0:
		return
	if injured and direction.is_zero_approx():
		play_reaction(&"hurt")
	else:
		reaction_sprite.hide()
		animated_sprite.show()

func apply_definition() -> void:
	slow_remaining=0
	root_remaining=0
	dot_remaining=0
	dot_clock=0
	dot_damage=0
	character_type = definition.character_type
	player_controlled = character_type == CharacterType.PLAYER
	max_health = definition.max_health
	max_energy = definition.max_energy
	speed = definition.movement_speed
	default_weapon = definition.default_weapon
	ultimate = definition.ultimate
	if hurtbox != null:
		configure_hurtbox()
	if definition.animations != null:
		animated_sprite.sprite_frames = definition.animations
		animated_sprite.scale = definition.sprite_scale
		animated_sprite.position = definition.sprite_offset
	voice_profile = definition.voice_profile
	if voice != null:
		voice.profile = voice_profile
	if definition.reaction_animations != null:
		configure_reactions(definition.reaction_animations,definition.reaction_scale,definition.reaction_offset)
	if definition.ultimate_animations != null:
		if cast_sprite == null:
			cast_sprite = AnimatedSprite2D.new()
			cast_sprite.name = "UltimateAnimation"
			cast_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(cast_sprite)
		cast_sprite.sprite_frames = definition.ultimate_animations
		cast_sprite.scale = definition.ultimate_scale
		cast_sprite.position = definition.ultimate_offset
		cast_sprite.hide()
	for sprite in [animated_sprite,reaction_sprite,cast_sprite]:
		if sprite!=null: sprite.material=definition.sprite_material

func can_receive_damage() -> bool:
	return character_type != CharacterType.NPC and not is_dead and invulnerable <= 0

func configure_hurtbox() -> void:
	if use_scene_collision_shapes:
		hurtbox = get_node("Hurtbox")
		hurtbox_shape = get_node("Hurtbox/CollisionShape2D")
		hurtbox.actor = self
		return
	if hurtbox == null:
		hurtbox = preload("res://Combat/hurtbox.gd").new()
		hurtbox.name = "Hurtbox"
		hurtbox.actor = self
		hurtbox.monitoring = false
		hurtbox.collision_mask = 0
		hurtbox_shape = CollisionShape2D.new()
		hurtbox.add_child(hurtbox_shape)
		add_child(hurtbox)
	hurtbox.collision_layer = 0 if character_type==CharacterType.NPC else (16 if character_type==CharacterType.PLAYER else 8)
	var shape := RectangleShape2D.new()
	shape.size = definition.hurtbox_size if definition!=null else Vector2(22,22)
	hurtbox_shape.shape = shape
	hurtbox.position = definition.hurtbox_offset if definition!=null else Vector2(0,-9)

func combat_center() -> Vector2:
	return hurtbox_shape.global_position if hurtbox_shape!=null else global_position

func combat_radius() -> float:
	return hurtbox_shape.shape.get_rect().size.x*absf(hurtbox_shape.global_scale.x)*.5 if hurtbox_shape!=null else 8.0

func damage_rids() -> Array[RID]:
	var ids: Array[RID] = [get_rid()]
	if hurtbox!=null:
		ids.append(hurtbox.get_rid())
	return ids

func take_damage(amount: float, _type: String = "physical") -> void:
	if not can_receive_damage() or amount <= 0:
		return
	health = maxf(0,health-amount)
	injured = health <= max_health*.25
	if health == 0:
		begin_death()
	else:
		play_reaction(&"hit")
	stats_changed.emit()

func tick_character(delta: float) -> void:
	slow_remaining=maxf(0,slow_remaining-delta)
	root_remaining=maxf(0,root_remaining-delta)
	if dot_remaining>0 and not is_dead:
		dot_remaining-=delta
		dot_clock-=delta
		if dot_clock<=0:
			dot_clock=1.0
			take_damage(dot_damage,"magic")
	invulnerable = maxf(0,invulnerable-delta)
	ultimate_cooldown = maxf(0,ultimate_cooldown-delta)
	if casting_remaining > 0:
		casting_remaining = maxf(0,casting_remaining-delta)
		if casting_remaining == 0:
			if ultimate_effect_pending and not is_dead:
				ultimate_effect_pending = false
				preload("res://Combat/ultimate_effect.gd").release(self,ultimate,ultimate_direction)
			if cast_sprite != null:
				cast_sprite.hide()
			if not is_dead:
				animated_sprite.show()

func trigger_ultimate(aim: Vector2 = Vector2.RIGHT) -> bool:
	if is_dead or ultimate == null or ultimate_charges <= 0 or ultimate_cooldown > 0 or casting_remaining > 0:
		return false
	ultimate_charges -= 1
	ultimate_cooldown = ultimate.cooldown
	casting_remaining = maxf(.05,ultimate.windup)
	ultimate_direction = aim.normalized() if not aim.is_zero_approx() else facing
	ultimate_effect_pending = true
	if cast_sprite != null:
		animated_sprite.hide()
		if reaction_sprite != null:
			reaction_sprite.hide()
		cast_sprite.show()
		cast_sprite.flip_h = ultimate_direction.x < 0
		cast_sprite.play(&"ultimate")
		cast_sprite.set_frame_and_progress(0,0)
	elif animated_sprite.sprite_frames.has_animation(&"ultimate"):
		animated_sprite.play(&"ultimate")
	preload("res://Combat/ultimate_effect.gd").telegraph(self,ultimate)
	voice.play_event("ultimate")
	ultimate_started.emit()
	stats_changed.emit()
	return true

func add_ultimate_charge(count: int = 1) -> void:
	if ultimate != null:
		ultimate_charges = clampi(ultimate_charges+count,0,ultimate.max_charges)
		stats_changed.emit()
