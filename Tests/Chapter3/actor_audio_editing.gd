extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	var level=load("res://Scence/Levels/level_20.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	var actors: Array=[]
	for family in ["naiwa","penguin"]:
		for stage in ["minion","mini","full"]:
			var actor=load("res://Characters/Actors/%s_%s.tscn"%[family,stage]).instantiate()
			check(actor.has_node("AnimatedSprite2D") and actor.get_node("AnimatedSprite2D").sprite_frames!=null,"sprite preview without executing game: "+family+stage)
			check(actor.has_node("FootCollision") and actor.has_node("Hurtbox/CollisionShape2D"),"both collision shapes authored: "+family+stage)
			var foot=actor.get_node("FootCollision")
			var body=actor.get_node("Hurtbox/CollisionShape2D")
			foot.shape.size=Vector2(21,9)
			foot.position=Vector2(3,-4)
			body.shape.size=Vector2(39,64)
			body.position=Vector2(2,-3)
			actor.get_node("Hurtbox").position=Vector2(-1,-30)
			actor.level=level
			actor.position=Vector2(400+actors.size()*100,500)
			level.add_child(actor)
			actor.set_physics_process(false)
			actor.apply_definition()
			check(foot.shape.size==Vector2(21,9) and foot.position==Vector2(3,-4),"editor foot edits survive initialization: "+family+stage)
			check(body.shape.size==Vector2(39,64) and body.position==Vector2(2,-3) and actor.hurtbox.position==Vector2(-1,-30),"editor body edits survive definition refresh: "+family+stage)
			check(actor.combat_center()==body.global_position,"aim uses edited shape center")
			var hp: float=actor.health
			actor.hurtbox.take_damage(1,"true")
			check(actor.health==hp-1,"authored hurtbox routes damage")
			check(actor.ability_allowed("sonic" if family=="naiwa" else "meteor")== (stage=="full"),"full-stage ability restriction preserved")
			actors.append(actor)
	for actor in actors:
		actor.voice.stop()
		actor.voice.last_event=""
		actor.voice.cooldowns.clear()
		actor.voice.elapsed=10
	var global=root.get_node("Global")
	global.set_boss_music("naiwa")
	var music_bus:=AudioServer.get_bus_index("Music")
	var voice_bus:=AudioServer.get_bus_index("Voice")
	var music_volume:=AudioServer.get_bus_volume_db(music_bus)
	check(actors[0].voice.play_event("battle") and actors[1].voice.play_event("battle") and actors[3].voice.play_event("battle"),"same-family and other-family actors may speak simultaneously")
	check(actors[0].voice.player!=actors[1].voice.player and actors[0].voice.player.playing and actors[1].voice.player.playing,"each actor owns a playing voice component")
	await create_timer(.15).timeout
	check(global.boss_player.playing and not global.boss_player.stream_paused and AudioServer.get_bus_volume_db(music_bus)==music_volume,"voice never pauses or ducks BGM")
	actors[1].voice.play_event("death")
	check(actors[0].voice.player.playing and actors[3].voice.player.playing,"death only interrupts its own actor")
	actors[1].voice.stop()
	check(actors[0].voice.player.playing and global.boss_player.playing,"stopping one voice leaves other voices and BGM playing")
	AudioServer.set_bus_mute(voice_bus,true)
	check(not AudioServer.is_bus_mute(music_bus) and global.boss_player.bus==&"Music" and actors[0].voice.player.bus==&"EnemyVoice","separate enemy voice and BGM buses")
	AudioServer.set_bus_mute(voice_bus,false)
	var q=load("res://Characters/Voices/q_penguin.tres")
	check(q.death[0]==q.angry[0],"Q death uses the angry recording")
	check(campaign.character_definition("q_penguin").ultimate.cooldown==15,"Q authored skill cooldown is 15 seconds")
	var doro=load("res://Characters/Voices/doro.tres")
	for event in ["idle","battle","hurt","death","angry","afraid","terrified","proud","skill","ultimate","victory","exhausted","dialogue"]:
		var text: String=doro.event_text[event][0]
		var stripped:=text.replace("doro","").replace("欧润及","").replace("，","").replace("。","").replace("！","").replace("？","").replace("…","")
		check(stripped.is_empty() and doro.get(event)[0].get_length()>0,"Doro regenerated phonetic line: "+event)
	level.queue_free()
	await process_frame
	print("Editable actors / independent audio: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
