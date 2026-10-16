extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report := {}
	var paths: Array[String] = ["res://Scence/Chapter2.tscn"]
	for i in range(1,18): paths.append("res://Scence/Levels/level_%02d.tscn" % i)
	for path in paths:
		var authored: Node2D=load(path).instantiate()
		var stage := Node2D.new()
		root.add_child(stage)
		var terrain: Node2D=authored.get_node("Terrain")
		authored.remove_child(terrain)
		terrain.owner = null
		stage.add_child(terrain)
		var geometry=load("res://Scence/Levels/geometry.gd").new()
		stage.add_child(geometry)
		var start := Time.get_ticks_usec()
		geometry.build(terrain,authored.get_node("Spawn").position,authored.get_node("Background").texture.get_size())
		var cells := []
		for cell in geometry.base_free: cells.append([cell.x,cell.y])
		report[path]={"cells":cells,"grid":[geometry.grid.x,geometry.grid.y],"ms":(Time.get_ticks_usec()-start)/1000.0,"count":terrain.get_child_count()}
		print(path,": ",report[path].ms," ms / ",report[path].count," shapes")
		authored.free()
		stage.free()
	var file=FileAccess.open("res://.godot/navigation_after.json" if OS.get_cmdline_user_args().has("--after") else "res://.godot/navigation_baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	quit()
