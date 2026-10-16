extends Node2D

signal portal_entered(portal_id: StringName, body: Node2D)
signal portal_exited(portal_id: StringName, body: Node2D)
signal transition_requested(portal_id: StringName, target_scene: String, target_spawn_id: StringName, body: Node2D)
const Catalog = preload("res://Scence/Levels/catalog.gd")
@export_range(1,17) var level_index := 1
@export var spawn_enemies := true
@export_enum("land","ocean","sky") var biome := "land"
@export var allow_ultimates := true
@export var allow_home_bonuses := true
@export_range(32,140,1) var spawn_safe_radius := 64.0
var config: Dictionary
var geometry: Node2D
var player: CharacterBody2D
var doors: Array[Node2D] = []
var switches: Array[Node2D] = []
var checkpoint_timer := 0.0
var nearest_interaction: Node2D
var interaction_hint := ""
var npc: CharacterBody2D
var guide: CharacterBody2D
var exit_area: Area2D
var exit_inside := false
var adventure: Node

func _ready() -> void:
	config = Catalog.load_level(level_index)
	config.spawn = [$Spawn.position.x, $Spawn.position.y]
	config.exit = [$ReturnPortal.position.x, $ReturnPortal.position.y]
	if has_node("RescuePosition"):
		config.rescue = [$RescuePosition.position.x, $RescuePosition.position.y]
	config.bridges = []
	for bridge in $Bridges.get_children():
		var size: Vector2 = bridge.get_meta("size", Vector2.ZERO)
		config.bridges.append({"rect": [bridge.position.x, bridge.position.y, size.x, size.y]})
	Campaign.active_level = level_index
	Campaign.hub_chapter = Catalog.chapter(level_index)
	Campaign.scene_ready()
	doors.assign($Doors.get_children())
	switches.assign($Switches.get_children())
	geometry = $Navigation
	geometry.build($Terrain, $Spawn.position, $Background.texture.get_size())
	refresh_doors()
	player = load("res://Player/Nuonuo.tscn" if Campaign.profile.character=="nuonuo" else "res://Player/Phoebe.tscn").instantiate()
	player.use_campaign_character = true
	player.name = "Player"
	player.speed = 135
	var saved: Array = Campaign.level_state(level_index).position
	player.position = geometry.nearest(Catalog.point(saved if saved.size()==2 else config.spawn))
	add_child(player)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(2,2)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int($Background.texture.get_width())
	camera.limit_bottom = int($Background.texture.get_height())
	if level_index in [6,16] and not bool(Campaign.level_state(level_index).get("rescued",false)):
		npc = preload("res://Characters/fixed_npc.gd").new()
		npc.rescue_character = true
		npc.rescue_id = "nuonuo" if level_index==6 else "ikun"
		npc.level = self
		npc.position = geometry.nearest($RescuePosition.position)
		config.rescue = [npc.position.x,npc.position.y]
		add_child(npc)
	guide = preload("res://Story/npc_roster.gd").setup(self)
	if level_index >= 8:
		var atmosphere := preload("res://Scence/underwater.gd").new()
		add_child(atmosphere)
	if spawn_enemies:
		adventure = preload("res://Scence/Levels/adventure.gd").new()
		adventure.name = "Adventure"
		add_child(adventure)
	_build_exit()
	var hud := preload("res://UI/game_hud.gd").new()
	hud.world = self
	add_child(hud)
	Story.enter_world.call_deferred(self)
	Campaign.save_progress()
	queue_redraw()

func refresh_doors() -> void:
	for door in doors:
		door.refresh()
	for mechanism in switches:
		mechanism.refresh()
	geometry.update_doors(doors)
	queue_redraw()

func is_spawn_safe(point: Vector2) -> bool:
	return point.distance_to($Spawn.position) <= spawn_safe_radius

func can_open_door(door: Node2D) -> bool:
	if door.activated: return false
	for id in door.config.requires:
		if id not in Campaign.level_state(level_index).switches: return false
	return adventure == null or adventure.can_open_next_door()

func open_sealed_door(door: Node2D) -> bool:
	if not can_open_door(door):
		Campaign.message.emit("先清除巡游敌人与当前守卫，并完成此门关联的机关。")
		return false
	Campaign.open_door(level_index,str(door.config.id))
	refresh_doors()
	return true

func _build_exit() -> void:
	exit_area = $ReturnPortal
	exit_area.body_entered.connect(func(body: Node2D):
		if body == player:
			exit_inside = true
			portal_entered.emit(&"return",body))
	exit_area.body_exited.connect(func(body: Node2D):
		if body == player:
			exit_inside = false
			portal_exited.emit(&"return",body))

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	checkpoint_timer += delta
	if checkpoint_timer > 2:
		checkpoint_timer = 0
		if adventure != null:
			adventure.snapshot()
		Campaign.checkpoint(level_index,player.position)
	nearest_interaction = null
	interaction_hint = ""
	var distance := 38.0
	for mechanism in switches:
		var d: float = player.position.distance_to(mechanism.position)
		if d < distance:
			distance = d
			nearest_interaction = mechanism
			interaction_hint = mechanism.hint()
	for door in doors:
		var d: float=door.interaction_distance(player.position)
		if not door.activated and d<maxf(distance,44) and (nearest_interaction==null or d<distance):
			distance=d
			nearest_interaction=door
			interaction_hint=door.hint()
	for chest in get_tree().get_nodes_in_group("chests"):
		var d: float = chest.interaction_distance(player)
		if d<distance:
			distance = d
			nearest_interaction = chest
			interaction_hint = chest.hint()
	for actor in get_tree().get_nodes_in_group("fixed_npcs"):
		var d: float = player.position.distance_to(actor.position)
		if d < minf(distance,45):
			distance = d
			nearest_interaction = actor
			interaction_hint = "E · 与%s对话" % actor.display_name
	if nearest_interaction==null:
		if exit_inside and level_index in Campaign.completed:
				interaction_hint = "E · 下一关 / 返回主地图"
		elif is_spawn_safe(player.position):
			interaction_hint = "复活圈 · 安全整理背包（B）；离圈后出现巡游敌人"
		elif exit_inside:
			interaction_hint = "解除全部封印并清除守卫后返回"

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or player.is_dead or Dialogue.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			player.note_activity()
			if is_instance_valid(nearest_interaction):
				nearest_interaction.interact()
			elif exit_inside:
				open_exit_menu()
		if event.physical_keycode == KEY_F3:
			geometry.debug_overlay = not geometry.debug_overlay
			geometry.queue_redraw()
			get_tree().debug_collisions_hint = geometry.debug_overlay

func open_exit_menu() -> void:
	if Dialogue.active or player.is_dead: return
	var complete:=level_index in Campaign.completed
	var options: Array=[]
	if complete and level_index not in [7,17]:
		options.append({"id":"next_level","text":"前往 "+Catalog.label(level_index+1),"disabled":not Campaign.is_unlocked(level_index+1)})
	options.append({"id":"return_hub","text":"保存进度，返回本章主场景"})
	var text:="本关的封印与救援进展已保存。可以继续旅程，或回主场景整备。" if complete else "封印尚未全部解除。可以保留进度返回整备，下次继续探索。"
	if complete and level_index in [7,17]: text+="\n下一章需要 Lv.%d；返回主图后沿%s前进。"%[20 if level_index==7 else 30,"南侧蓝色海洋" if level_index==7 else "右下角通道"]
	Dialogue.open("旅程出口",[text],options,self,func(id: String):
		if id=="next_level" and level_index in Campaign.completed and level_index not in [7,17] and Campaign.is_unlocked(level_index+1):
			Dialogue.close()
			transition_requested.emit(&"next",Catalog.scene_path(level_index+1),&"entry",player)
			Campaign.enter_level.call_deferred(level_index+1)
		elif id=="return_hub":
			Dialogue.close()
			transition_requested.emit(&"return",Catalog.hub_path(Catalog.chapter(level_index)),&"hub",player)
			Campaign.return_to_hub.call_deferred())

func respawn_player() -> void:
	player.position = geometry.nearest(Catalog.point(config.spawn))
	Campaign.checkpoint(level_index,player.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
		if adventure != null:
			adventure.snapshot()
		Campaign.checkpoint(level_index,player.position)

func _draw() -> void:
	if config.is_empty() or Engine.is_editor_hint():
		return
	draw_arc($Spawn.position,spawn_safe_radius,0,TAU,64,Color(.4,.9,1,.65),2)
	draw_circle($Spawn.position,spawn_safe_radius,Color(.3,.7,1,.045))
	var portal_shape: CollisionShape2D = $ReturnPortal/CollisionShape2D
	var color := Color("72e5da") if level_index in Campaign.completed else Color("8e879d")
	draw_set_transform_matrix(global_transform.affine_inverse() * portal_shape.global_transform)
	if portal_shape.shape is CircleShape2D:
		draw_arc(Vector2.ZERO,portal_shape.shape.radius,0,TAU,40,color,2)
	else:
		draw_rect(portal_shape.shape.get_rect(),color,false,2)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if is_instance_valid(npc):
		var center := Catalog.point(config.rescue)
		var all_open: bool = Campaign.level_state(level_index).doors.size() == doors.size()
		if not all_open:
			for x in range(-20,21,8):
				draw_line(center+Vector2(x,-36),center+Vector2(x,8),Color("ce87eb"),2)
