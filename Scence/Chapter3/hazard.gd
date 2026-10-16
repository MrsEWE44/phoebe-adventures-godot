extends Node2D
var source_actor: WeakRef
## Telegraph -> impact -> lingering field. Neutral NPCs are never targets.
var radius:=90.0
var damage:=100.0
var tick_damage:=0.0
var warmup:=1.2
var duration:=0.35
var elapsed:=0.0
var tick_clock:=0.0
var fired:=false
var friendly_fire:=false
var hostile:=true
var slow:=0.0
var bind_time:=0.0
var dot:=0.0
var tint:=Color("ff8844")
var visual:="meteor"
func _ready() -> void:
	add_to_group("arena_hazards")
	z_index=1
func targets() -> Array:
	return get_tree().get_nodes_in_group("characters") if friendly_fire else (preload("res://Combat/teams.gd").friendly_targets(get_tree()) if hostile else get_tree().get_nodes_in_group("enemies"))
func strike(amount: float) -> void:
	for target in targets():
		if target.is_dead or target.character_type==target.CharacterType.NPC: continue
		var center: Vector2=target.combat_center()
		if center.distance_to(global_position)>radius: continue
		if visual!="sonic" and not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,center,2)).is_empty(): continue
		preload("res://Combat/player_damage.gd").hit(source_actor.get_ref() if source_actor!=null else null,target,amount,"magic")
		if slow>0 or bind_time>0 or dot>0: target.apply_status(slow,bind_time,dot,4.0)
func _physics_process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=warmup and not fired:
		fired=true
		strike(damage)
		Global.play_sfx("impact")
		tick_clock=1.0
	if fired:
		tick_clock-=delta
		if tick_damage>0 and tick_clock<=0:
			tick_clock=1.0
			strike(tick_damage)
		if elapsed>=warmup+duration: queue_free()
	queue_redraw()
func _draw() -> void:
	if not fired:
		draw_circle(Vector2.ZERO,radius,Color(tint,.09))
		draw_arc(Vector2.ZERO,radius,0,TAU,50,tint,2)
		draw_arc(Vector2.ZERO,radius*.82,-PI/2,-PI/2+TAU*minf(1,elapsed/warmup),40,Color.WHITE,2)
	else:
		draw_circle(Vector2.ZERO,radius,Color(tint,.24 if tick_damage>0 else .15))
		for i in 3: draw_arc(Vector2.ZERO,radius*fmod((elapsed-warmup)*2+i*.3,1),0,TAU,40,tint,2)
	if visual=="meteor" and elapsed>warmup-.35 and elapsed<warmup+.4:
		var texture: Texture2D=preload("res://Weapons/chapter3_art.gd").texture(6)
		draw_texture_rect(texture,Rect2(Vector2(-35,-35-maxf(0,warmup-elapsed)*500),Vector2(70,70)),false)
	if visual=="flower" and fired:
		var texture: Texture2D=preload("res://Weapons/chapter3_art.gd").texture(4)
		draw_texture_rect(texture,Rect2(Vector2(-25,-25),Vector2(50,50)),false)
