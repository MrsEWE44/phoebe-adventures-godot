extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var report := {}
	for file in DirAccess.get_files_at("res://Characters/Definitions"):
		if not file.ends_with(".tres"): continue
		var spec = load("res://Characters/Definitions/"+file)
		if spec.character_type not in [1,3]: continue
		var rects := []
		var merged := Rect2()
		for anim in [&"idle",&"walk",&"default"]:
			if not spec.animations.has_animation(anim): continue
			for i in spec.animations.get_frame_count(anim):
				var texture: Texture2D = spec.animations.get_frame_texture(anim,i)
				var used := visible_rect(texture)
				var local := Rect2((used.position-texture.get_size()*.5)*spec.sprite_scale+spec.sprite_offset,used.size*spec.sprite_scale)
				merged = local if rects.is_empty() else merged.merge(local)
				rects.append([str(anim),i,str(local)])
		report[spec.character_id] = {"bounds":str(merged),"frames":rects}
	var chest: SpriteFrames = load("res://Art/Props/chest_frames.tres")
	var boxes := []
	for i in 4:
		var tex := chest.get_frame_texture(&"open",i)
		boxes.append(str(visible_rect(tex)))
	report["chest"] = boxes
	var out := FileAccess.open("res://.godot/actor_bounds.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()

func visible_rect(texture: Texture2D) -> Rect2:
	var img := texture.get_image()
	var lo := Vector2i(img.get_width(),img.get_height())
	var hi := Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x,y).a < .2: continue
			lo = lo.min(Vector2i(x,y))
			hi = hi.max(Vector2i(x+1,y+1))
	return Rect2(Vector2(lo),Vector2(hi-lo))
