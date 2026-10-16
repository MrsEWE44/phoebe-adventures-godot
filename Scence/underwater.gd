extends Node2D
## Lightweight ambient bubbles; no terrain or collision is generated here.
var age := 0.0

func _ready() -> void:
	z_index = 8
	show_behind_parent = false

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	for i in 32:
		var x := fmod(i*179.3,1650.0)+sin(age*.5+i)*7
		var y := fposmod(i*97.0-age*(8+i%4),941.0)
		draw_arc(Vector2(x,y),1.5+i%3,0,TAU,12,Color(.55,.9,1,.18),.7)
