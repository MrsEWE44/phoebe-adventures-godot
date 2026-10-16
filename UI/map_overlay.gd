extends Control

var world: Node2D
var texture: Texture2D

func _ready() -> void:
	if world.get("config") != null:
		texture = world.get_node("Background").texture
	else:
		texture = world.background.texture
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	if not visible or texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.04,.065,.98))
	var map_size := texture.get_size()
	var scale_factor := minf((size.x-70)/map_size.x,(size.y-110)/map_size.y)
	var origin := (size-map_size*scale_factor)*.5
	draw_texture_rect(texture,Rect2(origin,map_size*scale_factor),false)
	# Highlight only the spawn-connected floor. Empty space behind the authored
	# boundary walls is not a playable route even though it contains no collider.
	draw_rect(Rect2(origin,map_size*scale_factor),Color(.015,.025,.04,.65))
	if world.get("geometry")!=null:
		for bounds: Rect2 in world.geometry.floor_rects:
			draw_texture_rect_region(texture,Rect2(origin+bounds.position*scale_factor,bounds.size*scale_factor),bounds)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,30),"遗迹地图 · M/Esc 关闭   金：机关  青：已开门  红：敌人  蓝：NPC  橙：宝箱  白：玩家",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
	if world.get("level_index") != null:
		draw_arc(origin+world.get_node("Spawn").position*scale_factor,world.spawn_safe_radius*scale_factor,0,TAU,48,Color("8acfff"),2)
		for bridge: Dictionary in world.config.get("bridges",[]):
			var r: Array = bridge.rect
			draw_rect(Rect2(origin+Vector2(r[0],r[1])*scale_factor,Vector2(r[2],r[3])*scale_factor),Color("bfb38b"))
		for mechanism in world.switches:
			var p: Vector2 = origin+mechanism.position*scale_factor
			var color := Color("71e5c9") if mechanism.activated else Color("ffd078")
			draw_circle(p,5,color)
			draw_string(font,p+Vector2(7,-4),str(mechanism.config.label),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		for door in world.doors:
			var p: Vector2 = origin+door.position*scale_factor
			draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),Color("71e5c9") if door.activated else Color("d986cf"))
		if world.level_index>=18:
			for gate in world.get_node("Portals").get_children():
				var point: Vector2=origin+gate.position*scale_factor
				draw_circle(point,6,Color("ff8295") if gate.locked else Color("71e5c9"))
				draw_string(font,point+Vector2(9,0),"入口封锁" if gate.target_chapter==-2 else ("出口封锁" if gate.locked else "下一关 / 主图"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		draw_circle(origin+world.player.position*scale_factor,5,Color.WHITE)
		for group in ["enemies","fixed_npcs","chests"]:
			var color: Color = {"enemies":Color("ff7777"),"fixed_npcs":Color("7caeff"),"chests":Color("ffc26b")}[group]
			for actor in get_tree().get_nodes_in_group(group):
				draw_circle(origin+actor.position*scale_factor,3.5,color)
	else:
		var portals: Node = world.get_node("Portals") if world.has_node("Portals") else world.get_node("Level/Level1/Environment/Portals")
		for portal in portals.get_children():
			if portal.get("target_chapter")!=null and portal.target_chapter!=0: continue
			var index: int = preload("res://Scence/Levels/catalog.gd").portal_level(portal.portal_id)
			var p: Vector2 = origin+portal.position*scale_factor
			draw_circle(p,6,Color("71e5c9") if Campaign.is_unlocked(index) else Color("d986cf"))
			draw_string(font,p+Vector2(10,0),preload("res://Scence/Levels/catalog.gd").label(index),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		var actor: Node2D = world.get_node("Player") if world.has_node("Player") else world.get_node("菲比")
		draw_circle(origin+actor.position*scale_factor,5,Color.WHITE)
		for npc in get_tree().get_nodes_in_group("fixed_npcs"):
			draw_circle(origin+npc.position*scale_factor,4,Color("7caeff"))
