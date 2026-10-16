extends Area2D
## Authored Area2D with an editor-visible footprint and a clearly telegraphed cycle.
@export var disabled_by := "rune_1"
@export var period := 4.0
var age := 0.0
var level: Node2D
var disabled := false
var active := false

func _ready() -> void:
	level = get_parent().get_parent()

func _physics_process(delta: float) -> void:
	age += delta
	disabled = disabled_by in Campaign.level_state(level.level_index).switches
	active = not disabled and fmod(age,period) > period-.75
	if active and is_instance_valid(level.player) and overlaps_body(level.player):
		level.player.take_damage(12,"magic")
	queue_redraw()

func _draw() -> void:
	var warning := not disabled and fmod(age,period)>period-1.5
	var color := Color("68dab0") if disabled else (Color("ffad69") if warning else Color("6fbbdc"))
	draw_rect(Rect2(-12,-11,24,22),Color(color,.2))
	draw_arc(Vector2.ZERO,12,0,TAU,20,color,1.5)
	for i in 5:
		var y := -fposmod(age*(45 if active else 10)+i*9,45)
		draw_arc(Vector2(sin(i*3+age)*8,y),2+i%2,0,TAU,10,Color(color,.8 if active else .3),1)
