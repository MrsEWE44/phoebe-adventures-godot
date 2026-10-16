extends Node2D

var item_id := "health"
var age := 0.0
var claimed := false
var icon: Texture2D
var pickup_delay := .4
var dropped_by: Node2D
var owner_has_left := false

func _ready() -> void:
	add_to_group("loot")
	icon = preload("res://Combat/items.gd").item(item_id).get("texture")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var label := Label.new()
	label.text = str(preload("res://Combat/items.gd").item(item_id).name)
	label.position = Vector2(-35,-28)
	label.add_theme_font_size_override("font_size",10)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	add_child(label)

func _physics_process(delta: float) -> void:
	age += delta
	if not is_instance_valid(dropped_by) or dropped_by.global_position.distance_to(global_position)>36:
		owner_has_left = true
	if not claimed and age > pickup_delay:
		for player in get_tree().get_nodes_in_group("players"):
			if player.is_dead or (player==dropped_by and not owner_has_left):
				continue
			if player.global_position.distance_to(global_position) < 24:
				claimed = true
				Campaign.grant_drop(item_id,false)
				queue_free()
				break
	queue_redraw()

func _draw() -> void:
	var p := Vector2(0,sin(age*4)*2)
	var color := Color("ffd888")
	if item_id == "health":
		color = Color("fb777e")
	elif item_id == "energy":
		color = Color("80c9ff")
	elif item_id == "ultimate":
		color = Color("d698ff")
	draw_circle(p,8,Color("303b48"))
	draw_arc(p,9,0,TAU,20,color,1)
	if item_id in ["health","energy","ultimate"]:
		draw_rect(Rect2(p-Vector2(3,4),Vector2(6,9)),color)
		draw_rect(Rect2(p-Vector2(2,6),Vector2(4,2)),Color.WHITE)
	elif item_id in ["armor","amulet"]:
		draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-5),p+Vector2(5,-5),p+Vector2(4,3),p+Vector2(0,7),p+Vector2(-4,3)]),color)
	else:
		if icon != null:
			var size := icon.get_size() * (24.0/icon.get_width())
			draw_texture_rect(icon,Rect2(p-size*.5,size),false)
