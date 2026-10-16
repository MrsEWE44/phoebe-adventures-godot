extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.saving_enabled = false
	campaign.reset_state()
	var failures := 0
	for index in range(1,8):
		var level = load("res://Scence/Levels/level_%02d.tscn" % index).instantiate()
		level.spawn_enemies = false
		root.add_child(level)
		# Audit every actual object, not its snapped proxy in a different room.
		var targets: Array[Node2D] = []
		targets.assign(level.switches + level.doors)
		targets.append(level.get_node("ReturnPortal"))
		if level.has_node("RescuePosition"):
			targets.append(level.get_node("RescuePosition"))
		for mechanism in level.switches:
			preload("res://Tests/puzzle_helper.gd").solve(mechanism)
		for target in targets:
			var nearest: Vector2 = level.geometry.nearest(target.position)
			if nearest.distance_to(target.position)>25 or level.geometry.path(level.player.position,nearest).is_empty():
				failures += 1
				print("UNREACHABLE level ",index," ",target.name," ",target.position," nearest ",nearest)
		print("LEVEL ",index," saved shapes ",level.geometry.wall_count," navigation cells ",level.geometry.base_free.size())
		level.queue_free()
		await process_frame
	root.get_node("Global").set_process(false)
	for child in root.get_node("Global").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(.25).timeout
	print("NAVIGATION: ",failures," failures")
	quit(1 if failures else 0)
