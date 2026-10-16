extends "res://Scence/Chapter3/dash.gd"
## Shared by the full penguin boss and Gugu's inherited H ability.
var original_position:=Vector2.ZERO
var original_weapon_visible:=true
var mount: Node2D
@onready var leg: Node2D=$Leg

func _ready() -> void:
	super._ready()
	add_to_group("flying_kicks")
	z_index=9
	original_position=actor.animated_sprite.position
	mount=actor.get("weapon_mount")
	if mount!=null:
		original_weapon_visible=mount.visible
		mount.hide()
	actor.reset_reaction()
	if actor.animated_sprite.sprite_frames.has_animation("attack"):
		actor.animated_sprite.play("attack")
	actor.voice.play_event("ultimate")
	_pose()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_instance_valid(actor) and not actor.is_dead and not is_queued_for_deletion(): _pose()

func _pose() -> void:
	var charging:=elapsed<windup
	var progress:=clampf(elapsed/windup,0,1)
	var side:=1.0 if aim.x>=0 else -1.0
	actor.animated_sprite.rotation=side*(-.18*progress if charging else .65)
	actor.animated_sprite.scale=original_scale*Vector2(1.0,.9 if charging else 1.0)
	actor.animated_sprite.position=original_position+Vector2(0,3*progress if charging else -9)
	leg.position=actor.combat_center()-global_position+Vector2(0,10)
	leg.rotation=aim.angle()
	var size:=clampf(actor.combat_radius()/22.0,1.0,2.1)
	leg.scale=Vector2(size*(.35+.65*progress if charging else 1.0),size)
	leg.modulate.a=.65 if charging else 1.0
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor): return
	var center: Vector2=actor.combat_center()-global_position
	var perpendicular:=aim.orthogonal()
	if elapsed<windup:
		var end:=center+aim*travel_range
		draw_colored_polygon(PackedVector2Array([center-perpendicular*hit_radius,end-perpendicular*hit_radius,end+perpendicular*hit_radius,center+perpendicular*hit_radius]),Color(1,.32,.12,.15))
		draw_line(center,end,Color(1,.65,.25,.85),3)
		draw_arc(center,22+elapsed*18,0,TAU,32,Color("ffe0a0"),3)
	else:
		for i in 5:
			var offset:=perpendicular*(i-2)*10
			draw_line(center+offset-aim*(90-abs(i-2)*14),center+offset,Color(1,.76,.3,.65),3)
		draw_arc(center+aim*30,34,aim.angle()-1.2,aim.angle()+1.2,24,Color("fff1bd"),5)

func _exit_tree() -> void:
	if is_instance_valid(actor) and actor.definition==original_definition:
		actor.animated_sprite.position=original_position
		if is_instance_valid(mount): mount.visible=original_weapon_visible and not actor.is_dead
	super._exit_tree()
