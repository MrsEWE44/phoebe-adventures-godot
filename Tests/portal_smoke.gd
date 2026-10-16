extends SceneTree

const PortalArea = preload("res://Scence/portal.gd")
var PLAYER_SCENE: PackedScene

const PLAYER_LAYER: int = 1
const TERRAIN_LAYER: int = 2
const PORTAL_LAYER: int = 32
const OUTSIDE_POSITION := Vector2(100.0, 100.0)
const PORTAL_POSITION := Vector2(400.0, 400.0)

var _portal: PortalArea
var _player: CharacterBody2D
var _entered_events: Array[Dictionary] = []
var _exited_events: Array[Dictionary] = []
var _transition_events: Array[Dictionary] = []
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PLAYER_SCENE = load("res://Player/Phoebe.tscn")
	_stop_and_remove_audio_global()
	_create_portal()
	_create_player()
	await _step_frames(3)

	_check(_portal.collision_layer == PORTAL_LAYER, "Portal uses the named portal physics layer")
	_check(_portal.collision_mask == PLAYER_LAYER, "Portal only scans the player physics layer")
	_check(_player.is_in_group(&"players"), "Player scene belongs to the players group")
	_check((_player.collision_layer & PLAYER_LAYER) != 0, "Player scene is visible to the portal mask")

	_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 1, "A real player overlap emits one entered event")
	_check(_transition_events.size() == 1, "A real player overlap emits one transition request")
	_check(_exited_events.is_empty(), "Entering does not emit an exited event")
	_check(_entered_events[0].portal_id == &"test_portal" and _entered_events[0].body == _player, "Entered forwards portal id and player")
	_check(
		_transition_events[0].portal_id == &"test_portal"
		and _transition_events[0].target_scene == "res://Scence/future_room.tscn"
		and _transition_events[0].target_spawn_id == &"north_gate"
		and _transition_events[0].body == _player,
		"Transition request forwards destination scene, spawn id, portal id, and player"
	)

	await _step_frames(8)
	_check(_entered_events.size() == 1 and _transition_events.size() == 1, "Remaining inside never repeats enter or transition")

	_player.global_position = OUTSIDE_POSITION
	await _step_frames(3)
	_check(_exited_events.size() == 1, "Leaving emits one exited event")
	_check(_exited_events[0].portal_id == &"test_portal" and _exited_events[0].body == _player, "Exited forwards portal id and player")

	_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 2 and _transition_events.size() == 2, "Re-entry starts one new portal visit")
	_player.global_position = OUTSIDE_POSITION
	await _step_frames(3)
	_check(_exited_events.size() == 2, "The second visit emits one matching exit")

	var non_player := _create_test_body("SameLayerNonPlayer", PLAYER_LAYER, false)
	non_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 2 and _transition_events.size() == 2, "A same-layer body outside players group is ignored")
	non_player.global_position = OUTSIDE_POSITION
	await _step_frames(2)
	non_player.queue_free()
	await _step_frames(2)
	_check(_exited_events.size() == 2, "An ignored same-layer body cannot emit exit")

	var wrong_layer_player := _create_test_body("WrongLayerPlayer", TERRAIN_LAYER, true)
	wrong_layer_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 2 and _transition_events.size() == 2, "A players-group body on the wrong layer is ignored")
	wrong_layer_player.global_position = OUTSIDE_POSITION
	await _step_frames(2)
	wrong_layer_player.queue_free()
	await _step_frames(2)
	_check(_exited_events.size() == 2, "A wrong-layer player cannot emit exit")

	_portal.enabled = false
	_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 2 and _transition_events.size() == 2, "A disabled portal suppresses enter and transition")
	_player.global_position = OUTSIDE_POSITION
	await _step_frames(3)
	_check(_exited_events.size() == 2, "A visit rejected while disabled cannot emit exit")

	_portal.enabled = true
	_player.global_position = PORTAL_POSITION
	await _step_frames(3)
	_check(_entered_events.size() == 3 and _transition_events.size() == 3, "Re-enabled portal accepts the next real entry")
	_player.global_position = OUTSIDE_POSITION
	await _step_frames(3)
	_check(_exited_events.size() == 3, "Re-enabled portal closes the accepted visit once")

	_player.queue_free()
	_portal.queue_free()
	await _step_frames(2)
	print("Portal smoke test: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _create_portal() -> void:
	_portal = PortalArea.new()
	_portal.name = "TestPortal"
	_portal.position = PORTAL_POSITION
	_portal.collision_layer = PORTAL_LAYER
	_portal.collision_mask = PLAYER_LAYER
	_portal.portal_id = &"test_portal"
	_portal.target_scene = "res://Scence/future_room.tscn"
	_portal.target_spawn_id = &"north_gate"
	_portal.debug_output = false

	var portal_shape := RectangleShape2D.new()
	portal_shape.size = Vector2(120.0, 120.0)
	var portal_collision := CollisionShape2D.new()
	portal_collision.shape = portal_shape
	_portal.add_child(portal_collision)
	root.add_child(_portal)

	_portal.portal_entered.connect(_on_portal_entered)
	_portal.portal_exited.connect(_on_portal_exited)
	_portal.transition_requested.connect(_on_transition_requested)


func _create_player() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	_player.name = "PortalTestPlayer"
	_player.position = OUTSIDE_POSITION
	(_player.get_node("Camera2D") as Camera2D).enabled = false
	root.add_child(_player)


func _create_test_body(body_name: String, layer: int, joins_players: bool) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = PORTAL_LAYER
	body.position = OUTSIDE_POSITION
	if joins_players:
		body.add_to_group(&"players")

	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(20.0, 20.0)
	var body_collision := CollisionShape2D.new()
	body_collision.shape = body_shape
	body.add_child(body_collision)
	root.add_child(body)
	return body


func _on_portal_entered(portal_id: StringName, body: Node2D) -> void:
	_entered_events.append({"portal_id": portal_id, "body": body})


func _on_portal_exited(portal_id: StringName, body: Node2D) -> void:
	_exited_events.append({"portal_id": portal_id, "body": body})


func _on_transition_requested(portal_id: StringName, target_scene: String, target_spawn_id: StringName, body: Node2D) -> void:
	_transition_events.append({
		"portal_id": portal_id,
		"target_scene": target_scene,
		"target_spawn_id": target_spawn_id,
		"body": body,
	})


func _stop_and_remove_audio_global() -> void:
	var audio_global := root.get_node_or_null("Global")
	if audio_global == null:
		return
	for child in audio_global.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	audio_global.queue_free()


func _step_frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
