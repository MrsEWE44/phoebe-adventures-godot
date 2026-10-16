extends RefCounted
static func show_page(root: Window, ids: Array) -> CanvasLayer:
	var layer:=CanvasLayer.new()
	layer.layer=100
	root.add_child(layer)
	var bg:=ColorRect.new()
	bg.color=Color("293640")
	bg.size=Vector2(1280,720)
	layer.add_child(bg)
	for index in ids.size():
		var id: String=ids[index]
		var frames: SpriteFrames=load("res://Art/Chapter5/%s.tres"%id)
		var label:=Label.new()
		label.text=id
		label.position=Vector2(15,10+index*176)
		layer.add_child(label)
		for row in 3:
			var animation: StringName=[&"down",&"left",&"up"][row]
			for frame in frames.get_frame_count(animation):
				var sprite:=Sprite2D.new()
				sprite.texture=frames.get_frame_texture(animation,frame)
				sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.scale=Vector2.ONE*52.0/sprite.texture.get_height()
				sprite.position=Vector2(300+frame*220,32+index*176+row*56)
				layer.add_child(sprite)
	return layer
