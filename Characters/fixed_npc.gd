extends "res://Characters/character_base.gd"

@export var display_name := "遗迹守望者"
var level: Node2D
var rescue_character := false
var rescue_id := "nuonuo"
var rescue_pending := false

func _ready() -> void:
	if not rescue_character and level!=null and level.get("level_index")!=null and not is_in_group("story_guides"):
		if display_name=="遗迹守望者": display_name=Story.npc_name(level.level_index)
	character_type = CharacterType.NPC
	player_controlled = false
	idle_voice_enabled = false
	collision_layer = 0
	collision_mask = 0
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.position.y = -13
	if rescue_character:
		var rescued_spec := Campaign.character_definition(rescue_id)
		display_name = rescued_spec.display_name
		sprite.sprite_frames = rescued_spec.animations
		sprite.scale = rescued_spec.sprite_scale
		sprite.position = rescued_spec.sprite_offset
		sprite.animation = &"down"
		voice_profile = rescued_spec.voice_profile
	else:
		if definition == null:
			definition = preload("res://Characters/Definitions/soldier.tres")
		sprite.sprite_frames = definition.animations
		sprite.scale = definition.sprite_scale
		sprite.position = definition.sprite_offset
		# Hint NPCs use text and a short cue; never play a placeholder music track as speech.
		voice_profile = null
	ultimate = preload("res://Characters/Ultimates/soldier.tres")
	add_child(sprite)
	# The base's @onready field runs before this dynamically created child exists.
	animated_sprite = sprite
	super._ready()
	var label := Label.new()
	label.text = display_name+" · E 对话"
	label.position = Vector2(-43,-46)
	label.add_theme_font_size_override("font_size",11)
	label.add_theme_color_override("font_color",Color("9ce4d3"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y",1)
	add_child(label)
	add_to_group("fixed_npcs")

func _physics_process(_delta: float) -> void:
	tick_character(_delta)
	# Anchored NPCs share animation/voice setup but never read player movement.
	if animated_sprite.sprite_frames.has_animation(&"down"):
		animated_sprite.play(&"down")
	else:
		animated_sprite.play(&"ultimate" if casting_remaining>0 else &"idle")

func interact() -> void:
	if Dialogue.active or level == null:
		return
	level.player.note_activity()
	Story.note_action("talk")
	var text := "这里是 %s「%s」。我是留守此地的守望者。" % [preload("res://Scence/Levels/catalog.gd").label(level.level_index),level.config.name]
	var options: Array = [{"id":"mechanisms","text":"这里的机关怎么开启？"},{"id":"danger","text":"有什么需要小心的？"},{"id":"progress","text":"我们还差几扇门？"}]
	if not rescue_character:
		text=Story.entry(level.level_index).get("clue",text)
		options.push_front({"id":"story","text":"当前旅程与好友线索"})
		options.append({"id":"journal","text":"查看旅程手册 / 操作教学"})
	options.append({"id":"heal","text":"请使用守护祈愿治疗我"})
	if rescue_character:
		text = "你终于来了！封印把我困在这里……请清除守卫、开启此关所有门，再帮我解开封印。我会陪你迎战下一关的强敌。"
		options = [{"id":"rescue","text":"解开封印，救出"+display_name},{"id":"progress","text":"查看封印进度"}]
		text="糯糯：我听见你的声音了。先小心脚下的机关，我们一起回去。\n清场、打开所有门，再解开封印。" if rescue_id=="nuonuo" else "坤坤：先把球传过来。清场并打开所有门，我带你们找出口。"
		options.append({"id":"comfort","text":"安慰同伴，别担心"})
	if Dialogue.open(display_name,[text],options,self,_choose):
		if not voice.play_event("dialogue"):
			Global.play_sfx("potion")

func _choose(id: String) -> void:
	match id:
		"story": Dialogue.reply(Story.entry(level.level_index).get("task","沿着已解封的入口前进。"))
		"journal":
			Dialogue.close()
			Story.open_journal()
		"comfort":
			Dialogue.reply("糯糯轻轻点头：嗯，我等你。" if rescue_id=="nuonuo" else "坤坤抱着球点头：放心，出去以后，我也会帮忙。")
			Story.play_emotion(rescue_id,"dialogue")
		"heal":
			if trigger_ultimate(Vector2.DOWN):
				Dialogue.reply("守护祈愿已准备好，结束对话后为附近的你恢复生命。")
			else:
				Dialogue.reply("祈愿次数已用尽，或尚未冷却。")
		"mechanisms":
			Dialogue.reply(Story.hint(level.level_index))
		"danger":
			Dialogue.reply("每扇新门后都可能有守卫、BOSS、补给或同伴。敌人出现时会短暂显形，BOSS 大招有红色预警。清除守卫才有奖励宝箱；已清理房间不会重复刷新。")
		"progress":
			Dialogue.reply("目前已打开 %d / %d 扇门。%s" % [Campaign.level_state(level.level_index).doors.size(),level.doors.size(),"全部封印解除后，再来救我！" if rescue_character else "即使暂时退出，已开启的机关也会保留。"])
		"rescue":
			if Campaign.rescue_companion(rescue_id):
				rescue_pending = true
				Dialogue.reply("谢谢你救了我！我终于自由了。结束对话后，按 Tab 就可以切换成我，一起继续探险！")
				voice.elapsed = 1.0
				voice.play_event("proud")
				Dialogue.on_closed = _finish_rescue
				level.queue_redraw()
			else:
				Dialogue.reply("封印还没完全解除，必须打开这里的全部门才能救出我。先按 M 找到机关并清场，再按 E 开门。")

func _finish_rescue() -> void:
	if rescue_pending:
		queue_free()
		level.queue_redraw()
