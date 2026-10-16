@tool
extends Node2D
@export var opened:=false:
	set(value): opened=value;queue_redraw()
@export var cage_size := Vector2(56,64):
	set(value): cage_size=Vector2(maxf(40,value.x),maxf(48,value.y));queue_redraw()
@export var chain_color := Color("9aabb5"):
	set(value): chain_color=value;queue_redraw()
@export var lock_color := Color("d8ad62"):
	set(value): lock_color=value;queue_redraw()
func _draw() -> void:
	var half := cage_size.x*.5
	var top := 8-cage_size.y
	draw_rect(Rect2(-half,top,cage_size.x,cage_size.y),Color(.07,.13,.2,.28))
	draw_rect(Rect2(-half,top,cage_size.x,cage_size.y),Color("283a49"),false,5)
	draw_rect(Rect2(-half,top,cage_size.x,cage_size.y),Color("8093a2"),false,2)
	draw_line(Vector2(-half,top),Vector2(0,top-12),Color("93b3c9"),3)
	draw_line(Vector2(0,top-12),Vector2(half,top),Color("93b3c9"),3)
	for fraction in [-.65,-.22,.22,.65]:
		var x: float=half*fraction
		var offset:=(-23 if x<0 else 23) if opened else 0
		draw_line(Vector2(x+offset,top+2),Vector2(x+offset,7),Color("354958"),4)
		draw_line(Vector2(x+offset-.7,top+2),Vector2(x+offset-.7,7),Color("a3b4bf"),1)
	if not opened:
		# Two interlinked chains cross in front of the bars and fasten to one padlock.
		_draw_chain(Vector2(-half,top+28),Vector2(half,6))
		_draw_chain(Vector2(half,top+28),Vector2(-half,6))
		var center := Vector2(0,(top+34)*.5)
		draw_arc(center+Vector2(1,-2),7,PI,TAU,18,Color("17232d"),5,true)
		draw_arc(center+Vector2(0,-3),6,PI,TAU,18,Color("c9d4d8"),2.5,true)
		draw_rect(Rect2(center+Vector2(-8,-3),Vector2(18,18)),Color("19232b"))
		draw_rect(Rect2(center+Vector2(-8,-5),Vector2(16,17)),lock_color.darkened(.35))
		draw_rect(Rect2(center+Vector2(-7,-5),Vector2(14,14)),lock_color)
		draw_line(center+Vector2(-6,-4),center+Vector2(6,-4),lock_color.lightened(.5),1.5)
		draw_circle(center+Vector2(0,1),2.2,Color("30271d"))
		draw_line(center+Vector2(0,2),center+Vector2(0,6),Color("30271d"),2.5)
		for x in [-5,5]: draw_circle(center+Vector2(x,7),.8,lock_color.lightened(.4))

func _draw_chain(start: Vector2, end: Vector2) -> void:
	var direction := start.direction_to(end)
	var normal := Vector2(-direction.y,direction.x)
	var links := maxi(2,ceili(start.distance_to(end)/5.5))
	for i in links+1:
		var center := start.lerp(end,float(i)/links)
		var radius := 2.8 if i%2==0 else 1.3
		var outline := PackedVector2Array()
		var shadow := PackedVector2Array()
		var shine := PackedVector2Array()
		for step in 17:
			var angle := TAU*float(step)/16
			var point := center+direction*cos(angle)*4.0+normal*sin(angle)*radius
			outline.append(point)
			shadow.append(point+Vector2(.6,1))
			if step<=7: shine.append(point)
		draw_polyline(shadow,Color("12212b"),3.2,true)
		draw_polyline(outline,chain_color.darkened(.15 if i%2==0 else .35),1.7,true)
		draw_polyline(shine,chain_color.lightened(.45),.8,true)
