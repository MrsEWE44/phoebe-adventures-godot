extends Area2D
signal transition_requested(portal_id: StringName, chapter: int, level: int)
@export var portal_id: StringName
@export var level_index:=0
@export var target_chapter:=0
@export var portal_color:=Color.CYAN
@export var visual_offset:=Vector2(0,-18)
@export var visual_radius:=18.0
var locked:=false
var clock:=0.0
func _ready() -> void:
	body_entered.connect(_entered,CONNECT_DEFERRED)
	Campaign.progress_changed.connect(refresh)
	refresh()
func refresh() -> void:
	locked=target_chapter==-2 or (target_chapter==0 and not Campaign.is_unlocked(level_index))
	if target_chapter>0: locked=not Campaign.can_enter_chapter(target_chapter)
	if target_chapter==-1: locked=not bool(Campaign.level_state(level_index).get("arena",{}).get("finished",false))
	if has_node("Barrier/CollisionShape2D"): $Barrier/CollisionShape2D.set_deferred("disabled",not locked)
	queue_redraw()
func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()
func _entered(body: Variant) -> void:
	if not is_instance_valid(body) or not body.is_in_group("players") or body.is_dead: return
	print("[ChapterPortal] ",JSON.stringify({"portal":str(portal_id),"chapter":target_chapter,"level":level_index,"locked":locked}))
	if locked:
		var required:=Campaign.Growth.chapter_requirement(target_chapter if target_chapter>0 else 3)
		Campaign.message.emit("需要 Lv.%d。"%required if Campaign.player_level()<required else "先完成前一关或本场挑战。")
		return
	transition_requested.emit(portal_id,target_chapter,level_index)
	if target_chapter>0: Campaign.travel_to_hub.call_deferred(target_chapter)
	elif target_chapter==0: Campaign.enter_level.call_deferred(level_index)
	elif target_chapter==-1: get_parent().get_parent().show_exit_choices()
func _draw() -> void:
	var p:=visual_offset
	var alpha:=.8 if locked else .95
	draw_circle(p,visual_radius,Color(portal_color,alpha*.25))
	draw_circle(p,visual_radius*.62,Color(portal_color.darkened(.55),alpha*.25))
	for i in 4:
		var angle: float=clock+i*TAU/4
		draw_circle(p+Vector2.from_angle(angle)*(visual_radius+3),1.8,Color(portal_color,alpha))
	draw_arc(p,visual_radius+3,clock,clock+TAU*.8,30,Color(portal_color,alpha),2)
	var label: String=Campaign.Catalog.label(level_index)
	if target_chapter>0: label="前往第 %d 章"%target_chapter
	elif target_chapter==-1: label="封锁 · 完成挑战" if locked else "下一关 / 返回主地图"
	elif target_chapter==-2: label="入口封锁"
	elif locked: label+=" · 未解锁"
	if target_chapter>0 and locked: label+=" · Lv.%d"%Campaign.Growth.chapter_requirement(target_chapter)
	draw_string(ThemeDB.fallback_font,Vector2(-40,22),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
