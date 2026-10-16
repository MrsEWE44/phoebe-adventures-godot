extends Node2D

signal portal_entered(portal_id: StringName, body: Node2D)
signal portal_exited(portal_id: StringName, body: Node2D)
signal transition_requested(portal_id: StringName, target_scene: String, target_spawn_id: StringName, body: Node2D)

const PortalArea = preload("res://Scence/portal.gd")

@export_range(1.0, 4.0, 0.25) var camera_zoom: float = 2.0
@export var campaign_enabled := true
@export_enum("land","ocean","sky") var biome := "land"
@export var allow_ultimates := true
@export var allow_home_bonuses := true
var interaction_hint := ""
var geometry: Node2D

@onready var background: Sprite2D = $Level/Level1/Environment/Background
@onready var camera: Camera2D = $菲比/Camera2D


func _ready() -> void:
	for portal: PortalArea in $Level/Level1/Environment/Portals.get_children():
		portal.portal_entered.connect(portal_entered.emit)
		portal.portal_exited.connect(portal_exited.emit)
		portal.transition_requested.connect(transition_requested.emit)
	get_viewport().size_changed.connect(_update_camera_bounds)
	_update_camera_bounds()
	if campaign_enabled:
		Campaign.scene_ready()
		if Campaign.unfinished_attempt():
			Campaign.resume_level.call_deferred()
			return
		if Campaign.hub_chapter >= 2:
			Campaign.travel_to_hub.call_deferred(Campaign.hub_chapter)
			return
		Campaign.active_level = 0
		geometry = preload("res://Scence/Levels/geometry.gd").new()
		geometry.name = "Navigation"
		add_child(geometry)
		geometry.build($Level/Level1/Environment/Terrain,Vector2(836,610),background.texture.get_size())
		transition_requested.connect(_enter_campaign_portal)
		_build_campaign_portals()
		var hud := preload("res://UI/game_hud.gd").new()
		hud.world = self
		add_child(hud)

func _enter_campaign_portal(id: StringName, _target: String, _spawn: StringName, _body: Node2D) -> void:
	Campaign.enter_level.call_deferred(preload("res://Scence/Levels/catalog.gd").portal_level(id))

func _build_campaign_portals() -> void:
	var catalog = preload("res://Scence/Levels/catalog.gd")
	var return_target: Area2D
	for portal: PortalArea in $Level/Level1/Environment/Portals.get_children():
		var index: int = catalog.portal_level(portal.portal_id)
		var unlocked := Campaign.is_unlocked(index)
		portal.enabled = unlocked
		portal.target_scene = catalog.scene_path(index)
		portal.target_spawn_id = &"entry"
		var collision: CollisionShape2D = portal.get_node("CollisionShape2D")
		var label := Label.new()
		label.text = "1-%d %s" % [index,"已通关" if index in Campaign.completed else ("进入" if unlocked else "封印")]
		label.position = collision.position + Vector2(-38,12)
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_color",Color("79e3d4") if unlocked else Color("ecabb4"))
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",2)
		portal.add_child(label)
		if not unlocked:
			var barrier := StaticBody2D.new()
			barrier.collision_layer = 2
			barrier.collision_mask = 0
			barrier.position = collision.position
			var shape := CollisionShape2D.new()
			shape.shape = collision.shape.duplicate()
			barrier.add_child(shape)
			portal.add_child(barrier)
			var rune := Line2D.new()
			rune.points = PackedVector2Array([collision.position+Vector2(-15,-12),collision.position+Vector2(15,12),collision.position+Vector2(15,-12),collision.position+Vector2(-15,12)])
			rune.width = 2
			rune.default_color = Color("d980b2")
			portal.add_child(rune)
		if Campaign.return_portal == portal.portal_id:
			return_target = portal
	Campaign.return_portal = &""
	if return_target != null:
		$菲比.set_physics_process(false)
		_place_after_return.call_deferred(return_target)
	else:
		$菲比.position = geometry.nearest(Vector2(836,610))

func _place_after_return(portal: Area2D) -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var preferred := Vector2(836,610)
	if is_instance_valid(portal):
		var collision: CollisionShape2D = portal.get_node("CollisionShape2D")
		preferred = to_local(collision.global_position)+Vector2(0,collision.shape.get_rect().size.y*.5+24)
	var point: Vector2 = geometry.safe_spawn(preferred,$菲比)
	if point.is_finite():
		$菲比.position = point
		$菲比.velocity = Vector2.ZERO
		camera.reset_smoothing()
		$菲比.set_physics_process(true)
	else:
		Campaign.message.emit("主地图没有安全落点，请检查出生点附近的地形碰撞。")


func _update_camera_bounds() -> void:
	var map_rect := Rect2(
		background.to_global(background.get_rect().position),
		background.get_rect().size * background.global_scale
	)
	camera.limit_left = floori(map_rect.position.x)
	camera.limit_top = floori(map_rect.position.y)
	camera.limit_right = ceili(map_rect.end.x)
	camera.limit_bottom = ceili(map_rect.end.y)

	# Keep the view inside the map even in very wide or tall windows.
	var viewport_size := get_viewport_rect().size
	var minimum_zoom := maxf(viewport_size.x / map_rect.size.x, viewport_size.y / map_rect.size.y)
	camera.zoom = Vector2.ONE * maxf(camera_zoom, minimum_zoom)
	camera.reset_smoothing()
