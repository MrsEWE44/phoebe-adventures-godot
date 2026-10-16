extends SceneTree

var PLAYER_SCENE: PackedScene
const ACTIONS: Array[StringName] = [&"left", &"right", &"up", &"down"]

var _player: CharacterBody2D
var _sprite: AnimatedSprite2D
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PLAYER_SCENE = load("res://Player/Phoebe.tscn")
	# This test exercises the player in isolation, without background audio.
	var audio_global := root.get_node_or_null("Global")
	if audio_global != null:
		audio_global.queue_free()

	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	_player.get_node("Camera2D").enabled = false
	root.add_child(_player)
	_sprite = _player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	await _hold([], 2)

	_check(_sprite.animation == &"down", "Initial facing is down")
	_check(not _sprite.is_playing() and _sprite.frame == 0, "Initial animation is stopped at frame zero")
	_check(_player.velocity.is_zero_approx(), "Initial velocity is zero")
	_check(_player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Player uses top-down floating motion")

	var start_position := _player.position
	await _hold([&"right"], 18)
	_check(_player.position.x > start_position.x and is_equal_approx(_player.position.y, start_position.y), "Right input moves the player right")
	_check(_sprite.is_playing() and _sprite.animation == &"left" and _sprite.flip_h, "Right movement starts the mirrored side animation")
	_check(_sprite.frame > 0, "Walking animation advances beyond the idle frame")

	await _hold([], 2)
	_check(_player.velocity.is_zero_approx(), "Releasing movement stops velocity")
	_check(not _sprite.is_playing() and _sprite.frame == 0, "Releasing movement stops animation at frame zero")
	_check(_sprite.animation == &"left" and _sprite.flip_h, "Stopping preserves right-facing direction")
	start_position = _player.position
	await _step_frames(18)
	_check(_player.position.is_equal_approx(start_position) and not _sprite.is_playing() and _sprite.frame == 0, "Idle remains stationary without restarting animation")

	await _hold([&"left"], 2)
	_check(_player.position.x < start_position.x and _sprite.is_playing() and not _sprite.flip_h, "Left movement resumes animation without mirroring")
	await _hold([&"right"], 2)
	await _hold([&"up"], 2)
	_check(_player.velocity.y < 0.0 and _sprite.animation == &"up" and not _sprite.flip_h, "Up movement clears horizontal mirroring")
	await _hold([&"down"], 2)
	_check(_player.velocity.y > 0.0 and _sprite.animation == &"down" and not _sprite.flip_h, "Down movement selects the forward animation")

	await _hold([&"right", &"down"], 12)
	var movement_speed: float = _player.get("speed")
	_check(is_equal_approx(_player.velocity.length(), movement_speed), "Diagonal movement has the same speed as cardinal movement")
	_check(is_equal_approx(_player.velocity.x, _player.velocity.y), "Diagonal input applies equal horizontal and vertical velocity")
	start_position = _player.position
	await _hold([&"left", &"right", &"up", &"down"], 2)
	_check(_player.velocity.is_zero_approx() and _player.position.is_equal_approx(start_position), "Opposite movement keys cancel each other")
	_check(not _sprite.is_playing() and _sprite.frame == 0, "Cancelled movement returns to idle")

	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 1
	wall.position = Vector2(150.0, 150.0)
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(20.0, 600.0)
	var wall_collision := CollisionShape2D.new()
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	root.add_child(wall)
	_player.position = Vector2(100.0, 100.0)
	await _hold([], 2)
	await _hold([&"right", &"down"], 60)
	_check(_player.position.x > 130.0 and _player.position.x <= 132.2, "16px foot collider stops at the wall without penetration")
	_check(_player.position.y > 140.0, "Diagonal movement continues sliding along the wall")
	_check(_player.is_on_wall() and not _player.is_on_floor(), "Top-down collision is treated as a wall rather than a floor")

	_release_actions()
	_player.queue_free()
	wall.queue_free()
	await _step_frames(2)
	print("Player smoke test: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _hold(actions: Array[StringName], frames: int) -> void:
	_release_actions()
	for action in actions:
		Input.action_press(action)
	await _step_frames(frames)


func _release_actions() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _step_frames(count: int) -> void:
	for _index in count:
		await physics_frame
		# physics_frame precedes node callbacks; inspect state after they finish.
		await process_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
