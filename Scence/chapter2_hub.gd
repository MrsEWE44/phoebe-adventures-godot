extends Node2D
signal portal_entered(portal_id: StringName, body: Node2D)
signal portal_exited(portal_id: StringName, body: Node2D)
signal transition_requested(portal_id: StringName, target_scene: String, target_spawn_id: StringName, body: Node2D)
const Catalog = preload("res://Scence/Levels/catalog.gd")
@export_enum("land","ocean","sky") var biome := "ocean"
@export var allow_ultimates := true
@export var allow_home_bonuses := true
var interaction_hint := ""
var nearest_interaction: Node2D
var return_inside := false
@onready var player: CharacterBody2D = $Player
@onready var background: Sprite2D = $Background
@onready var geometry: Node2D = $Navigation

func _ready() -> void:
	Campaign.scene_ready()
	if Campaign.active_level > 0 and Campaign.active_level not in Campaign.completed:
		Campaign.resume_level.call_deferred()
		return
	Campaign.active_level = 0
	Campaign.hub_chapter = 2
	geometry.build($Terrain,$Spawn.position,background.texture.get_size())
	player.position = geometry.nearest($Spawn.position)
	var returning := not Campaign.return_portal.is_empty()
	var preferred: Vector2 = $Spawn.position
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(2,2)
	camera.limit_right = background.texture.get_width()
	camera.limit_bottom = background.texture.get_height()
	for portal in $Portals.get_children():
		portal.portal_entered.connect(portal_entered.emit)
		portal.portal_exited.connect(portal_exited.emit)
		portal.transition_requested.connect(transition_requested.emit)
		var index: int = Catalog.portal_level(portal.portal_id)
		var unlocked := Campaign.is_unlocked(index)
		portal.enabled = unlocked
		portal.get_node("Barrier/CollisionShape2D").set_deferred("disabled",unlocked)
		portal.get_node("Label").text = Catalog.label(index)+(" · 已通关" if index in Campaign.completed else (" · 进入" if unlocked else " · 封印"))
		portal.transition_requested.connect(func(_id: StringName,_path: String,_spawn: StringName,_body: Node2D): Campaign.enter_level.call_deferred(index))
		if Campaign.return_portal == portal.portal_id:
			var shape: CollisionShape2D = portal.get_node("CollisionShape2D")
			preferred = portal.position+shape.position+Vector2(0,shape.shape.get_rect().size.y*.5+24)
	Campaign.return_portal = &""
	if returning:
		player.set_physics_process(false)
		_place_after_return.call_deferred(preferred)
	$ReturnPortal.body_entered.connect(func(body: Node2D):
		if body==player: return_inside=true)
	$ReturnPortal.body_exited.connect(func(body: Node2D):
		if body==player: return_inside=false)
	var hud := preload("res://UI/game_hud.gd").new()
	hud.world = self
	add_child(hud)
	Campaign.save_progress()

func _place_after_return(preferred: Vector2) -> void:
	await get_tree().physics_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	var point: Vector2 = geometry.safe_spawn(preferred,player)
	if point.is_finite():
		player.position = point
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		player.set_physics_process(true)
	else:
		Campaign.message.emit("主地图没有安全落点，请检查出生点附近的地形碰撞。")

func _process(_delta: float) -> void:
	nearest_interaction = null
	interaction_hint = "E · 返回遗迹海岸" if return_inside else ""
	var distance := 48.0
	for npc in get_tree().get_nodes_in_group("fixed_npcs"):
		var d := player.global_position.distance_to(npc.global_position)
		if d < distance:
			distance = d
			nearest_interaction = npc
			interaction_hint = "E · "+npc.display_name

func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead or Dialogue.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			if is_instance_valid(nearest_interaction):
				nearest_interaction.interact()
			elif return_inside:
				Campaign.travel_to_hub.call_deferred(1)
		if event.physical_keycode == KEY_F3:
			geometry.debug_overlay = not geometry.debug_overlay
			geometry.queue_redraw()
			get_tree().debug_collisions_hint = geometry.debug_overlay
