extends "res://Scence/Chapter3/hub.gd"
func _ready() -> void:
	Campaign.scene_ready()
	if Campaign.unfinished_attempt():
		Campaign.resume_level.call_deferred()
		return
	Campaign.active_level=0
	Campaign.hub_chapter=4
	Campaign.ensure_character_allowed()
	biome="swamp"
	geometry.build($Terrain,$Spawn.position,background.texture.get_size())
	var preferred: Vector2=$Spawn.position
	for gate in $Portals.get_children():
		if gate.portal_id==Campaign.return_portal: preferred=gate.position+Vector2(0,22)
	Campaign.return_portal=&""
	player.position=geometry.nearest(preferred)
	player.refresh_environment()
	var camera: Camera2D=player.get_node("Camera2D")
	camera.zoom=Vector2(1.6,1.6)
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
		var npc=preload("res://Scence/Chapter4/camp_npc.gd").new()
		npc.service_role="guide" if i==0 else "merchant"
		npc.position=geometry.nearest(Vector2(889,814) if i==0 else Vector2(910,876))
		$NPCs.add_child(npc)
	Global.set_boss_music("victory4" if 37 in Campaign.completed else "naiwa")
	interaction_hint="红门4-1开始 · 彩门逐关解封 · 顶部大绿门前往第五章 · E使用营地服务"
	Campaign.save_progress()
func objective_text() -> String:
	return "第四章 · 迷失的合奏 · Lv.40 · E 营地服务"
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
