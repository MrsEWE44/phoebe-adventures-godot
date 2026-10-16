extends Area2D

@export var config: Dictionary
var level: Node2D
var time := 0.0
var active := false
var disabled := false
var size := Vector2.ZERO
var floor_texture: Texture2D
var floor_sample := Vector2.ZERO
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	level = get_parent().get_parent()
	var data: Dictionary = preload("res://Scence/Levels/catalog.gd").load_level(level.level_index)
	floor_texture = load(preload("res://Scence/Levels/catalog.gd").map_path(level.level_index))
	floor_sample = Vector2(data.floor_sample[0],data.floor_sample[1])
	time = float(str(config.id).hash() % 100) / 70.0

func _physics_process(delta: float) -> void:
	time += delta
	disabled = str(config.get("disabled_by", "")) in Campaign.level_state(level.level_index).switches
	active = not disabled and fmod(time, float(config.period)) < float(config.active_time)
	if active and is_instance_valid(level.player) and overlaps_body(level.player):
		level.player.take_damage(12, "magic" if config.type == "flame" else "physical")
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(collision) or collision.shape == null:
		return
	var bounds := collision.shape.get_rect()
	size = bounds.size
	draw_set_transform_matrix(collision.transform * Transform2D(0, bounds.position))
	for x in range(0,int(size.x),32):
		for y in range(0,int(size.y),32):
			var tile_size := Vector2(minf(32,size.x-x),minf(32,size.y-y))
			draw_texture_rect_region(floor_texture,Rect2(Vector2(x,y),tile_size),Rect2(floor_sample,tile_size))
	draw_rect(Rect2(Vector2.ZERO,size), Color(0.12,.13,.12,.35))
	var warning := not disabled and fmod(time,float(config.period)) > float(config.period)-.65
	var color := Color("73d5b9") if disabled else (Color("ff7060") if active else Color("afaaa0"))
	draw_rect(Rect2(Vector2.ZERO,size), Color("ffcc66") if warning else color, false, 1)
	for x in range(6,int(size.x),12):
		for y in range(6,int(size.y),12):
			var p := Vector2(x,y)
			if not active:
				draw_circle(p,2,color)
			elif config.type == "spikes":
				draw_colored_polygon(PackedVector2Array([p+Vector2(-4,4),p+Vector2(0,-8),p+Vector2(4,4)]),color)
			elif config.type == "arrows":
				p.x += sin(time*12)*3
				draw_line(p+Vector2(-5,0),p+Vector2(4,0),color,2)
				draw_line(p+Vector2(4,0),p+Vector2(0,-3),color,2)
			else:
				draw_circle(p+Vector2(0,-3),3+sin(time*16+x),Color("ffc66b"))
