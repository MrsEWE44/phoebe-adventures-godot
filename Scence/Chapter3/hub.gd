extends Node2D
@export var biome:="snow"
@export var allow_ultimates:=true
@export var allow_home_bonuses:=true
var interaction_hint:="走近彩色门进入关卡；Lv.40可通过冰蓝顶门进入第四章。"
@onready var player: CharacterBody2D=$Player
@onready var background: Sprite2D=$Background
@onready var geometry: Node2D=$Navigation
func _ready() -> void:
	Campaign.scene_ready()
	if Campaign.unfinished_attempt():
		Campaign.resume_level.call_deferred()
		return
	Campaign.active_level=0
	Campaign.hub_chapter=3
	Global.set_boss_music("victory3" if 27 in Campaign.completed else "")
	geometry.build($Terrain,$Spawn.position,background.texture.get_size())
	var preferred: Vector2=$Spawn.position
	for gate in $Portals.get_children():
		if gate.portal_id==Campaign.return_portal: preferred=gate.position+Vector2(0,35)
	Campaign.return_portal=&""
	player.position=geometry.nearest(preferred)
	player.refresh_environment()
	var camera: Camera2D=player.get_node("Camera2D")
	camera.zoom=Vector2(2,2)
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=int(background.texture.get_width())
	camera.limit_bottom=int(background.texture.get_height())
	player.set_physics_process(false)
	_place.call_deferred(preferred)
	var hud=preload("res://UI/game_hud.gd").new()
	hud.world=self
	add_child(hud)
	Campaign.save_progress()
func _place(preferred: Vector2) -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(player) or not player.is_inside_tree(): return
	var point: Vector2=geometry.safe_spawn(preferred,player)
	if point.is_finite(): player.position=point
	player.set_physics_process(true)
func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.active: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		for npc in $NPCs.get_children():
			if player.position.distance_to(npc.position)<65:
				npc.interact()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F3:
		geometry.debug_overlay=not geometry.debug_overlay
		geometry.queue_redraw()
		get_tree().debug_collisions_hint=geometry.debug_overlay
