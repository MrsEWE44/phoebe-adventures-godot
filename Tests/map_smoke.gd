extends SceneTree

var MAIN_SCENE: PackedScene

var _checks: int = 0
var _failures: int = 0
var _player: CharacterBody2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	MAIN_SCENE = load("res://Scence/Main.tscn")
	var main := MAIN_SCENE.instantiate() as Node2D
	main.campaign_enabled = false
	# Audio has its own integration check; stop it before the short map test.
	var audio_global := root.get_node_or_null("Global")
	if audio_global != null:
		for child in audio_global.get_children():
			if child is AudioStreamPlayer:
				child.stop()
	root.add_child(main)
	_player = main.get_node("菲比") as CharacterBody2D
	var camera := _player.get_node("Camera2D") as Camera2D
	var background := main.get_node("Level/Level1/Environment/Background") as Sprite2D
	await physics_frame
	await process_frame

	_check(background.texture != null and background.get_rect().size == Vector2(1672, 940), "Map background loads at its native size")
	var spawn_query := PhysicsShapeQueryParameters2D.new()
	spawn_query.shape = (_player.get_node("CollisionShape2D") as CollisionShape2D).shape
	spawn_query.transform = _player.global_transform
	spawn_query.collision_mask = 2
	_check(_player.get_world_2d().direct_space_state.intersect_shape(spawn_query).is_empty(), "Spawn is outside all terrain colliders")
	_check(not _blocked(Vector2(836, 610), Vector2(0, -310)), "Main road from spawn to temple is walkable")
	_check(not _blocked(Vector2(836, 610), Vector2(0, 290)), "Main pier is reachable from the road")
	_check(_blocked(Vector2(836, 850), Vector2(-150, 0)), "West pier rail prevents walking into water")
	_check(_blocked(Vector2(836, 850), Vector2(150, 0)), "East pier rail prevents walking into water")
	_check(_blocked(Vector2(400, 670), Vector2(0, 200)), "West shoreline blocks entry into water")
	_check(_blocked(Vector2(1000, 670), Vector2(0, 200)), "East shoreline blocks entry into water")
	_check(not _blocked(Vector2(1304, 665), Vector2(0, 65)), "Short east pier has a player-sized entrance")
	_check(_blocked(Vector2(1304, 730), Vector2(0, 80)), "Short east pier ends before the water")
	_check(_blocked(Vector2(836, 300), Vector2(0, -200)), "Temple back wall prevents walking beyond the portal recess")
	_check(_blocked(Vector2(836, 900), Vector2(0, 150)), "Map bottom prevents leaving the pier")
	_check(_blocked(Vector2(50, 470), Vector2(-150, 0)), "Map west edge is solid")
	_check(_blocked(Vector2(1620, 550), Vector2(150, 0)), "Map east edge is solid")
	_check(camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 1672 and camera.limit_bottom == 940, "Camera limits match the map instead of hard-coded old bounds")
	_check(camera.zoom.is_equal_approx(Vector2(2, 2)), "Default camera shows a wider playable area")

	var original_size := root.size
	for window_size in [Vector2i(4000, 720), Vector2i(720, 4000)]:
		root.size = window_size
		await process_frame
		main._update_camera_bounds()
		var visible_size := main.get_viewport_rect().size / camera.zoom
		_check(visible_size.x <= 1672.1 and visible_size.y <= 940.1, "Camera stays within map for viewport %s" % window_size)
	root.size = original_size

	main.queue_free()
	if audio_global != null:
		# Let the audio mixer release its playback before shutting down Godot.
		await create_timer(0.2).timeout
		audio_global.queue_free()
	await process_frame
	await process_frame
	print("Map smoke test: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _blocked(from: Vector2, motion: Vector2) -> bool:
	var start := _player.global_transform
	start.origin = from
	return _player.test_move(start, motion)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
