extends RefCounted
const IDS=["pink_cello","ivory_cello","voice_wave","music_drums","conductor"]
static func play(actor: Node2D, aim: Vector2, ultimate:=false) -> void:
	var id: String=actor.normal_weapon.weapon_id
	var world: Node=actor.get_parent()
	if ultimate and id=="conductor" and world.has_method("conduct") and world.level_index==37:
		world.conduct(actor)
		return
	var character: String=actor.current_character
	var form: String=actor.definition.character_id
	var line: bool=id=="ivory_cello" or (id=="conductor" and not ultimate)
	var radius:=500.0 if line else (320.0 if ultimate else 200.0)
	if form=="anon_glasses": radius+=65
	if form=="anon_dragon": radius+=120
	if id=="music_drums": radius=350
	var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
	wave.position=actor.combat_center()
	wave.radius=radius
	wave.direction=aim.normalized()
	wave.line=line
	wave.tint=Color("fff1a0") if line else Color("ffa9da")
	world.add_child(wave)
	for enemy in actor.get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead or enemy.get_parent()!=world: continue
		var offset: Vector2=enemy.combat_center()-actor.combat_center()
		var along:=offset.dot(wave.direction)
		if line:
			if along<0 or along>radius or absf(offset.cross(wave.direction))>36: continue
		elif offset.length()>radius: continue
		var species: String=enemy.definition.character_id
		if form=="anon_dragon" and species.begins_with("naiwa") and world.has_method("assimilate"):
			if world.assimilate(enemy): continue
		var damage: float=actor.attack_damage(actor.normal_weapon.damage*(8 if ultimate else 1),ultimate)
		if form=="anon_glasses": damage*=1.45
		if form=="anon_dragon": damage*=2.0
		if character=="anon" and (species.begins_with("tensura") or species.begins_with("weiro")): damage*=4
		if ultimate and ((character=="mutsumi" and species.ends_with("minion")) or (character=="soyo" and not species.ends_with("full"))): damage=maxf(damage,enemy.max_health)
		if character=="anon" or id=="music_drums":
			enemy.apply_status(3)
			enemy.set_meta("music_weakened_until",Time.get_ticks_msec()+3500)
		preload("res://Combat/player_damage.gd").hit(actor,enemy,damage,"true" if ultimate else "magic")
	actor.voice.play_event("ultimate" if ultimate else "skill")
	if ultimate or not actor.normal_weapon.auto_fire: actor.play_chapter3_cast(aim)
	actor.get_node("/root/Global").play_sfx("shot")
