extends Node2D
var points:=PackedVector2Array()
var critical:=false
var age:=0.0
func _ready() -> void:
	z_index=8
func _process(delta: float) -> void:
	age+=delta
	if age>=.4: queue_free()
	queue_redraw()
func _draw() -> void:
	var tint:=Color("ffe28b") if critical else Color("8aefff")
	tint.a=1-age/.4
	for i in points.size():
		var point:=to_local(points[i])
		draw_arc(point,12+age*35,0,TAU,24,tint,2)
		if i>0:
			var previous:=to_local(points[i-1])
			var middle: Vector2=(previous+point)*.5+(point-previous).orthogonal().normalized()*8
			draw_polyline(PackedVector2Array([previous,middle,point]),tint,3,true)
	if critical and not points.is_empty():
		draw_string(ThemeDB.fallback_font,to_local(points[0])+Vector2(-25,-25-age*25),"暴击·真伤",HORIZONTAL_ALIGNMENT_LEFT,-1,16,tint)
