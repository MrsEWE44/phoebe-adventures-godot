extends "res://Scence/Chapter4/hub.gd"
func _ready() -> void:
	Campaign.scene_ready()
	if Campaign.unfinished_attempt():
		Campaign.resume_level.call_deferred()
		return
	Campaign.active_level=0
	Campaign.hub_chapter=5
	Campaign.ensure_character_allowed()
	biome="hell"
	geometry.build($Terrain,$Spawn.position,background.texture.get_size())
	var preferred: Vector2=$Spawn.position
	for gate in $Portals.get_children():
		if gate.portal_id==Campaign.return_portal: preferred=gate.position+Vector2(0,18)
	preferred=outside_portals(preferred)
	Campaign.return_portal=&""
	player.position=geometry.nearest(preferred)
	player.refresh_environment()
	var camera: Camera2D=player.get_node("Camera2D")
	camera.zoom=Vector2(1.4,1.4)
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=background.texture.get_width()
	camera.limit_bottom=background.texture.get_height()
	player.set_physics_process(false)
	_place.call_deferred(preferred)
	var hud=preload("res://UI/game_hud.gd").new()
	hud.world=self
	add_child(hud)
	for i in 2:
		var npc=preload("res://Scence/Chapter5/camp_npc.gd").new()
		npc.service_role="guide" if i==0 else "merchant"
		npc.position=geometry.nearest(Vector2(672+i*156,962))
		$NPCs.add_child(npc)
	Global.set_boss_music("victory3" if 47 in Campaign.completed else "badapple" if 40 in Campaign.completed else "sakura" if 39 in Campaign.completed else "memory4")
	interaction_hint="5-1 从底部红门开始 · 十个门逐关解封 · 传送卷轴可返回旧章节"
	Campaign.save_progress()
func objective_text() -> String:
	return "第五章 · 余烬中的约定 · Lv.50 · "+("友谊之力生效" if Campaign.friendship_active() else "救援进行中")
func outside_portals(preferred: Vector2) -> Vector2:
	# Narrow landings may push a downward offset back into the portal trigger.
	var best: Vector2=$Spawn.position
	var distance:=INF
	for cell in geometry.base_free:
		var point: Vector2=geometry.nav.get_point_position(cell)
		if $Portals.get_children().any(func(gate):return point.distance_to(gate.position)<52): continue
		var score:=point.distance_squared_to(preferred)
		if score<distance: best=point;distance=score
	return best
