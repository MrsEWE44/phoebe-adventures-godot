extends Area2D
## A doorway trigger. Scene/UI controllers decide what to do with the request.

signal portal_entered(portal_id: StringName, body: Node2D)
signal portal_exited(portal_id: StringName, body: Node2D)
signal transition_requested(portal_id: StringName, target_scene: String, target_spawn_id: StringName, body: Node2D)

@export var portal_id: StringName
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_id: StringName = &""
@export var enabled: bool = true
@export var debug_output: bool = true

var _visitors: Dictionary[int, WeakRef] = {}


func _ready() -> void:
	# Deferred delivery lets a receiver safely open UI or change the scene.
	body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
	body_exited.connect(_on_body_exited, CONNECT_DEFERRED)


func _on_body_entered(body: Variant) -> void:
	# The body can be freed before this deferred call; validate before typing it.
	if not enabled or not is_instance_valid(body) or not body.is_in_group(&"players"):
		return
	if not is_inside_tree() or is_queued_for_deletion() or not overlaps_body(body):
		return
	for visitor_id in _visitors.keys():
		if _visitors[visitor_id].get_ref() == null:
			_visitors.erase(visitor_id)
	var body_id: int = body.get_instance_id()
	if _visitors.has(body_id):
		return
	_visitors[body_id] = weakref(body)
	_log_event("entered", body)
	portal_entered.emit(portal_id, body)
	if not is_inside_tree() or is_queued_for_deletion() or not enabled:
		return
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	_log_event("transition_requested", body)
	transition_requested.emit(portal_id, target_scene, target_spawn_id, body)


func _on_body_exited(body: Variant) -> void:
	# Keep Variant here too, so a freed body does not fail argument conversion.
	if not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	if not _visitors.has(body_id):
		return
	_visitors.erase(body_id)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_log_event("exited", body)
	portal_exited.emit(portal_id, body)


func _log_event(event: String, body: Node2D) -> void:
	if debug_output:
		print("[Portal] ", JSON.stringify({
			"event": event,
			"portal_id": str(portal_id),
			"body": str(body.name),
			"target_scene": target_scene,
			"target_spawn_id": str(target_spawn_id),
		}))
