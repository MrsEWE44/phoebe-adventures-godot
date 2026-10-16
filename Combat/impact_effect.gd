extends Node2D
var radius := 40.0
var tint := Color("ffc17b")
var age := 0.0
func _process(delta: float) -> void:
	age += delta
	if age >= .25:
		queue_free()
	queue_redraw()
func _draw() -> void:
	var progress := clampf(age/.25,0,1)
	draw_circle(Vector2.ZERO,radius*progress,Color(tint,.3*(1-progress)))
	draw_arc(Vector2.ZERO,radius*progress,0,TAU,32,Color(tint,1-progress),3)
