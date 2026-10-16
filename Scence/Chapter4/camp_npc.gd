extends "res://Characters/character_base.gd"
@export_enum("guide","merchant") var service_role: String="guide"
var display_name: String=""
func service_name() -> String:
	return "营地联络员" if service_role=="guide" else "巡演补给商"
func _ready() -> void:
	display_name=service_name()
	definition=preload("res://Characters/Definitions/soldier.tres")
	super._ready()
	player_controlled=false
	idle_voice_enabled=false
	character_type=CharacterType.NPC
	configure_hurtbox()
	animated_sprite.modulate=Color("c7e9ff") if service_role=="guide" else Color("ffdf9f")
	var label:=Label.new()
	label.text=display_name+" · E"
	label.position=Vector2(-45,-55)
	label.add_theme_font_size_override("font_size",11)
	add_child(label)
func _physics_process(delta: float) -> void:
	tick_character(delta)
	animated_sprite.play("down" if animated_sprite.sprite_frames.has_animation("down") else "idle")
func interact() -> void:
	var options: Array=[{"id":"story","text":"救援顺序与当前队伍"},{"id":"journal","text":"打开旅程手册"}]
	if service_role=="merchant": options=[{"id":"items","text":"购买药品、经验与复苏晶石"},{"id":"weapons","text":"查看商店武器"}]
	Dialogue.open(display_name,["从红门4-1开始，彩门按关卡顺序解封。顶部大绿门前往第五章地狱。" if service_role=="guide" else "离队角色的装备仍保留在背包；音乐角色可使用乐器，坤坤仍固定使用篮球。"],options,self,func(id):
		if id=="story": Dialogue.reply("前三关救出睦子米、soyo狸、爱音；随后取回形态与乐器。Q币企鹅仅第三章。"+("四位旧友暂时离队。" if 28 in Campaign.completed else "四位旧友仍可与坤坤一起出战4-1。")+"最终战需要soyo指挥棒召集三人，再由坤坤保护合奏。")
		else:
			Dialogue.close()
			if id=="journal": Story.open_journal()
			else: preload("res://UI/shop_menu.gd").open(self,id))
