extends "res://Characters/character_base.gd"
@export_enum("doro","gugu") var role:="doro"
var level: Node2D
var record: Dictionary={}
var speech_clock:=8.0
var released:=false
var hurt_chain:=0
var hurt_chain_clock:=0.0
func _ready() -> void:
	level=get_parent()
	definition=Campaign.character_definition(role)
	super._ready()
	player_controlled=false
	idle_voice_enabled=false
	character_type=CharacterType.NPC
	configure_hurtbox()
	max_health=Campaign.Growth.stats(Campaign.encounter_level(level.level_index),definition.max_health).health
	health=max_health
	is_dead=false
	$Cage.visible=true
	collision_layer=32
	if level.state.finished: release()
	elif is_dead:
		hurtbox.collision_layer=0
		animated_sprite.modulate=Color(.5,.5,.5,.5)
	else: voice.play_event("afraid")
	sync_record()
func _physics_process(delta: float) -> void:
	if is_dead or level.state.get("failed",false): return
	tick_character(delta)
	if is_dead: return
	hurt_chain_clock=maxf(0,hurt_chain_clock-delta)
	if hurt_chain_clock<=0: hurt_chain=0
	hit_remaining=maxf(0,hit_remaining-delta)
	_update_reaction()
	speech_clock-=delta
	if speech_clock<=0:
		voice.play_event(battle_voice_event())
		speech_clock=randf_range(8,13)
	direction=Vector2.ZERO
	_update_animation()
func take_damage(_amount: float, _type: String="physical") -> void:
	# Captives are neutral; survival and clearing enemies determine liberation.
	return
func sync_record() -> void:
	record.health=health
	record.dead=is_dead
	record.position=[position.x,position.y]
func battle_voice_event() -> String:
	if released: return "victory"
	if health<max_health*.3: return "exhausted"
	var nearby: Array=level.living().filter(func(e): return position.distance_to(e.position)<240)
	if nearby.any(func(e): return e.character_type==CharacterType.BOSS): return "terrified"
	if nearby.size()>=4: return "afraid"
	if not nearby.is_empty(): return "afraid"
	return "dialogue"
func release() -> void:
	released=true
	$Cage.opened=true
	collision_layer=0
	hurtbox.collision_layer=0
	voice.play_event("victory")
	queue_redraw()
func interact() -> void:
	if Dialogue.active: return
	voice.play_event("afraid" if not released else "victory")
	Dialogue.open(definition.display_name+" · 菲比的好友",["Doro：doro……\n她看见朋友们，靠近了栏杆。坚持四分钟并清场即可救出她。" if role=="doro" and not released else ("咕嘎用翅膀敲了敲栏杆：他听见你们来了。击败全部必需首领才能打开牢笼。" if not released else "朋友终于团聚，出口已经开放。")],[{"id":"care","text":"温柔回应：我们在这里"},{"id":"brave","text":"自信回应：交给我们"}],self,_reply_friend)
func _reply_friend(id: String) -> void:
	Story.play_emotion(role,"dialogue" if id=="care" else "proud")
	Dialogue.reply(("Doro 轻声回应：doro……" if role=="doro" else "咕嘎轻轻点头，表示听见了。") if id=="care" else ("Doro 高兴地叫了一声：欧润及！" if role=="doro" else "咕嘎展开翅膀，为朋友鼓劲。"))
func _draw() -> void:
	if definition==null: return
	var title: String=definition.display_name
	if not released: title+=" · 被囚禁"
	var caption_y: float=26
	draw_rect(Rect2(-54,caption_y-13,110,18),Color(.025,.045,.075,.85))
	draw_string(ThemeDB.fallback_font,Vector2(-50,caption_y),title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("a1f6d3"))
