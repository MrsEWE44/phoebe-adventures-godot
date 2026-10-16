extends SceneTree

var MAIN_SCENE: PackedScene
const PortalArea = preload("res://Scence/portal.gd")

var _player: CharacterBody2D
var _entered: Array[StringName] = []
var _exited: Array[StringName] = []
var _requests: Array[Dictionary] = []
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	MAIN_SCENE = load("res://Scence/Main.tscn")
	var audio_global := root.get_node_or_null("Global")
	if audio_global != null:
		for child in audio_global.get_children():
			if child is AudioStreamPlayer:
				child.stop()
	var main := MAIN_SCENE.instantiate() as Node2D
	main.campaign_enabled = false
	main.portal_entered.connect(func(id: StringName, _body: Node2D): _entered.append(id))
	main.portal_exited.connect(func(id: StringName, _body: Node2D): _exited.append(id))
	main.transition_requested.connect(_on_request)
	root.add_child(main)
	_player = main.get_node("菲比") as CharacterBody2D
	var portals := main.get_node("Level/Level1/Environment/Portals")
	_check(portals.get_child_count() == 7, "All seven stone doorways have portal areas")
	var ids: Array[StringName] = []
	await _step(3)

	_check(not _blocked(Vector2(245, 310), Vector2(-80, 0)), "West arch can be reached through the gap above the lower ruins")
	for portal: PortalArea in portals.get_children():
		_check(not portal.portal_id.is_empty() and not ids.has(portal.portal_id), "Portal ID is unique: " + str(portal.portal_id))
		ids.append(portal.portal_id)
		var collision: CollisionShape2D = portal.get_node("CollisionShape2D")
		var doorway := collision.global_position+Vector2(0,collision.shape.get_rect().size.y*.5)
		var approach := portal.global_position + Vector2(0,60)
		if portal.portal_id == &"west_arch":
			approach = Vector2(165,310)
		elif portal.portal_id == &"north_west_ruins":
			approach = Vector2(254,200)
		_player.global_position = approach
		await _step(3)
		_entered.clear()
		_exited.clear()
		_requests.clear()
		_check(not portal.overlaps_body(_player), "Approach is outside trigger: " + str(portal.portal_id))
		_check(not _blocked(approach, Vector2(approach.x,doorway.y+4) - approach), "Player-sized doorway is open: " + str(portal.portal_id))
		Input.action_press(&"up")
		await _step(65)
		Input.action_release(&"up")
		await _step(3)
		_check(_entered == [portal.portal_id], "Walking into doorway emits one entered signal: " + str(portal.portal_id))
		_check(_requests.size() == 1 and _requests[0].get("id") == portal.portal_id and _requests[0].get("body") == _player, "Main relays the correct transition request: " + str(portal.portal_id))
		_check(portal.overlaps_body(_player) and _exited.is_empty(), "Back wall keeps player inside portal instead of crossing behind the building: " + str(portal.portal_id))
		await _step(5)
		_check(_requests.size() == 1, "Standing in doorway does not repeat requests: " + str(portal.portal_id))
		_player.global_position = approach
		await _step(3)
		_check(_exited == [portal.portal_id], "Leaving doorway emits the matching exit: " + str(portal.portal_id))

	Input.action_release(&"up")
	main.queue_free()
	await create_timer(0.2).timeout
	if audio_global != null:
		audio_global.queue_free()
	await _step(2)
	print("Portal map smoke test: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _on_request(id: StringName, scene_path: String, spawn_id: StringName, body: Node2D) -> void:
	_requests.append({"id": id, "scene": scene_path, "spawn": spawn_id, "body": body})


func _blocked(from: Vector2, motion: Vector2) -> bool:
	var start := _player.global_transform
	start.origin = from
	return _player.test_move(start, motion)


func _step(frames: int) -> void:
	for _frame in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
