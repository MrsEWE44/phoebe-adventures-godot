extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var layouts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Chapter5/frame_layout.json"))
	for id in layouts:
		var entry: Dictionary=layouts[id]
		var frames: SpriteFrames=load("res://Art/Chapter5/%s.tres"%id)
		ck(frames.get_frame_count("idle")==1,id+" idle is still")
		for animation in ["down","left","up"]:
			ck(frames.get_frame_count(animation)==4,id+" walking cadence")
			for i in frames.get_frame_count(animation):
				var tex: AtlasTexture=frames.get_frame_texture(animation,i)
				ck(tex.get_size()==Vector2(entry.canvas[0],entry.canvas[1]),id+" constant frame canvas")
				ck(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),id+" frame inside source")
				ck(is_equal_approx(tex.margin.position.y+tex.region.size.y,entry.canvas[1]-4.0),id+" consistent foot baseline")
				ck(absf(tex.margin.position.x+tex.region.size.x*.5-entry.canvas[0]*.5)<=.5,id+" horizontal centre")
		if id=="omo_spin": continue
		var key: String=id if id in ["miku","reimu","omo"] else id+"_mini"
		var spec: Resource=load("res://Characters/Definitions/%s.tres"%key)
		ck(spec.faces_right==(id!="miku"),id+" direction matches source")
		ck(absf(spec.sprite_offset.y+(entry.canvas[1]*.5-4)*spec.sprite_scale.y)<.01,id+" foot at actor origin")
		if id in ["miku","reimu","omo"]: ck(spec.sprite_material==null,id+" keeps opaque clothing")
	ck(layouts.fatkangaroo_green.rows.all(func(row):return row.size()==3),"exclude clipped fourth green rabbit")
	ck(layouts.fatkangaroo_red.rows.all(func(row):return row.size()==3),"three complete red rabbit poses")
	ck(layouts.mouse_red.rows[0].size()==3 and layouts.mouse_red.rows[1].size()==4,"mouse rows have independent counts")
	print("CHAPTER5 SPRITE FRAMES: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
