extends Node2D
## A short-lived readable ring/beam; hit application happens exactly once.
var radius:=220.0
var direction:=Vector2.RIGHT
var line:=false
var tint:=Color("ffa9da")
var clock:=0.0
func _ready() -> void:
	z_index=15
func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()
	if clock>.65: queue_free()
func _draw() -> void:
	var color:=Color(tint,1.0-clock/.65)
	if line:
		draw_line(Vector2.ZERO,direction*radius,Color(color,.13),56)
		for i in 4:
			var p:=direction*fmod(clock*700+i*radius/4,radius)
			draw_arc(p,20,direction.angle()-1.3,direction.angle()+1.3,18,color,3)
	else:
		for i in 3:
			var size:=fmod(clock*radius*1.5+i*radius/3,radius)
			draw_arc(Vector2.ZERO,size,0,TAU,48,color,3)
