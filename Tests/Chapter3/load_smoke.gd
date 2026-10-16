extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	for path in ["res://Scence/Chapter3.tscn","res://Scence/Levels/level_18.tscn"]:
		var scene=load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await physics_frame
		if scene.get("geometry")!=null: print(path," floor=",scene.geometry.base_free.size()," build_ms=",scene.geometry.build_ms)
		if scene.has_method("spawn_kind"):
			for species in ["naiwa_mini","naiwa_full","penguin_mini","penguin_full"]: scene.spawn_kind(species)
			await create_timer(.1).timeout
		scene.queue_free()
		await process_frame
	quit()
