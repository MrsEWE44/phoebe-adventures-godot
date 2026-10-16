extends RefCounted
const IDS=["leek_wave","crescent_scythe"]
static func play(actor: Node2D, aim: Vector2, ultimate:=false) -> void:
	var miku: bool=actor.current_character=="miku"
	var radius: float=300 if ultimate else (250 if miku else 170)
	var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
	wave.position=actor.combat_center()
	wave.radius=radius
	wave.tint=Color("81ffad") if miku else Color("ff7b9e")
	actor.get_parent().add_child(wave)
	for enemy in actor.get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead or enemy.global_position.distance_to(actor.global_position)>radius: continue
		var damage: float=actor.attack_damage(actor.normal_weapon.damage,ultimate and miku)*(3.0 if ultimate else 1.0)
		if miku: enemy.apply_status(2.0,1.0 if enemy.character_type==3 else 2.2,actor.attack_damage(18),5.0)
		elif enemy.definition.character_id.begins_with("naiwa") and not enemy.definition.character_id.ends_with("full"): damage=maxf(damage,enemy.health)
		preload("res://Combat/player_damage.gd").hit(actor,enemy,damage,"magic" if miku else "true")
	actor.play_chapter3_cast(aim)
	actor.get_node("/root/Global").play_sfx("shot")
