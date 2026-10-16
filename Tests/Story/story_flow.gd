extends SceneTree
var checks:=0
var failures:=0
var campaign: Node
var story: Node
var dialogue: Node
const Helper=preload("res://Tests/puzzle_helper.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(n:=3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func close_story() -> void:
	if dialogue.active: dialogue.close()
	await frames()
func scene(index: int) -> Node:
	var level=load("res://Scence/Levels/level_%02d.tscn"%index).instantiate()
	level.spawn_enemies=false
	root.add_child(level)
	level.player.set_physics_process(false)
	level.player.invulnerable=9999
	return level
func run() -> void:
	campaign=root.get_node("Campaign")
	story=root.get_node("Story")
	dialogue=root.get_node("Dialogue")
	campaign.saving_enabled=false
	campaign.reset_state()
	story.automatic_enabled=true
	var level=scene(1)
	await frames()
	check(dialogue.active and story.running.key=="1:intro" and paused,"first entry automatically opens story and pauses gameplay")
	check(campaign.profile.energy_potions==3 and campaign.profile.health_potions==2,"new learner receives single-use supply grant")
	dialogue.select("learn")
	check(story.last_voice_character=="phoebe" and story.last_voice_emotion=="dialogue" and dialogue.content_label.text.contains("WASD"),"tutorial choice plays Phoebe's caring response")
	dialogue.select("continue")
	await frames()
	check(not paused and "1:intro" in story.progress().seen,"closing saves watched scene and restores gameplay")
	var supplies: int=campaign.profile.energy_potions
	story.enter_world(level)
	await frames()
	check(not dialogue.active and campaign.profile.energy_potions==supplies,"repeat visit never repeats intro or farms supplies")
	level.get_node("Service_puzzle").interact()
	check(dialogue.active and dialogue.speaker_label.text=="刻文师·小篆" and "talk" in story.progress().tutorial,"dedicated scholar provides puzzle help")
	dialogue.select("mechanisms")
	var first_hint: String=dialogue.content_label.text
	dialogue.select("mechanisms")
	check(first_hint!=dialogue.content_label.text and dialogue.content_label.text.contains("提示 2/"),"NPC provides progressively clearer hints")
	await close_story()
	var riddle=level.switches[0]
	riddle.interact()
	check(dialogue.choices.size()==5 and riddle.puzzle.mode=="riddle","riddle opens answer buttons and help")
	dialogue.select(str((int(riddle.puzzle.answer)+1)%4))
	check(not riddle.activated and riddle.mistakes==1,"wrong riddle answer cannot unlock seal")
	var before: int=campaign.profile.coins
	dialogue.select("hint")
	check(campaign.profile.coins==before and riddle.hint_step==1,"riddle hint is free and persistent")
	dialogue.select(str(int(riddle.puzzle.answer)))
	check(riddle.activated and dialogue.content_label.text.contains(riddle.puzzle.explanation),"correct riddle unlocks existing switch and explains solution")
	await close_story()
	var cipher=level.switches[1]
	cipher.interact()
	dialogue.select(str(int(cipher.puzzle.sequence[0])))
	check(cipher.sequence_index==1 and not cipher.activated,"cipher accepts first segment without premature unlock")
	await close_story()
	campaign.save_path="res://.godot/story-roundtrip.json"
	campaign.saving_enabled=true
	check(campaign.save_progress(),"story and partial cipher save atomically")
	level.queue_free()
	await frames()
	check(campaign.load_progress(),"story save reloads")
	campaign.saving_enabled=false
	check("1:intro" in story.progress().seen and story.progress().choices.get("1:intro")=="learn" and "talk" in story.progress().tutorial,"choices, seen events and tutorial progress survive reload")
	level=scene(1)
	await frames()
	check(dialogue.active and dialogue.content_label.text.contains("你回来了"),"reentry automatically resumes NPC briefing")
	dialogue.select("begin")
	await frames()
	cipher=level.switches[1]
	check(cipher.sequence_index==1 and level.switches[0].activated and level.switches[0].hint_step==1,"riddle and partial cipher survive reload")
	cipher.interact()
	dialogue.select("reset")
	check(cipher.sequence_index==0,"cipher can reset without cost or lockout")
	for digit in cipher.puzzle.sequence: dialogue.select(str(int(digit)))
	check(cipher.activated,"full correct cipher activates seal")
	await close_story()
	level.player.position=level.geometry.nearest(level.get_node("Spawn").position+Vector2(100,0))
	for cell in level.geometry.reachable_cells(level.player.position):
		var point: Vector2=level.geometry.nav.get_point_position(cell)
		if not level.is_spawn_safe(point): level.player.position=point;break
	await frames()
	check("move" in story.progress().tutorial,"actual movement advances tutorial")
	check(level.player.attack(false,false),"normal attack practice works")
	level.player.attack_timer=0
	check(level.player.attack(true,false),"skill practice works")
	check(campaign.consume_potion(false),"provided potion restores consumed skill energy")
	check(level.player.trigger_ultimate(Vector2.RIGHT),"ultimate practice works")
	var hud: Node
	for child in level.get_children():
		if child.get_script()==load("res://UI/game_hud.gd"): hud=child
	hud.toggle_inventory()
	hud.toggle_inventory()
	campaign.claim_chest(1,"story_practice","health")
	check(story.progress().tutorial.size()==8,"real movement, talk, attack, inventory, skill, potion, ultimate and chest all recorded")
	story.open_journal()
	dialogue.select("tutorial")
	check(not dialogue.portrait.visible and dialogue.content_label.custom_minimum_size.y>=260,"manual gives all training steps enough reading space without empty portrait")
	dialogue.select("home")
	dialogue.select("chapter_3")
	check(dialogue.choices.size()==1,"journal does not expose undiscovered third chapter")
	dialogue.select("home")
	dialogue.select("voice")
	check(not story.progress().voices,"player can disable story voice")
	dialogue.select("voice")
	await close_story()
	story.automatic_enabled=false
	# Every authored choice must render and use the intended speaker even as Nuonuo.
	campaign.profile.nuonuo_unlocked=true
	campaign.select_character("nuonuo")
	for index in range(1,28):
		check(not story.entry(index).goal.is_empty() and not story.entry(index).clue.is_empty(),"authored objective and NPC clue %d"%index)
		for phase in ["intro","outro"]:
			for option in story.entry(index)[phase].choices:
				check(story.play_scene(index,phase),"opens scene %d %s"%[index,phase])
				dialogue.select(option.id)
				var expected: String=option.get("speaker","phoebe")
				check(story.last_voice_character==expected and story.story_voice.profile==campaign.character_definition(expected).voice_profile and story.last_voice_emotion==option.emotion,"button uses authored character and attitude")
				dialogue.select("continue")
				if dialogue.active: dialogue.select("continue")
				check(not paused and not dialogue.active,"choice continuation closes without leaking pause")
	level.queue_free()
	await frames()
	# Final reunion runs before video choice. Rewards remain in Campaign.
	campaign.reset_state()
	story.automatic_enabled=true
	level=scene(27)
	await frames()
	await close_story()
	level.state.boss_started=true
	level.ensure_final_bosses()
	for enemy in level.living(): enemy.take_damage(1000000,"true")
	await frames()
	check(level.state.finished and story.running.key=="27:outro" and get_nodes_in_group("victory_video").is_empty(),"reunion story precedes optional video")
	check(campaign.profile.gugu_unlocked and "penguin_rock" in campaign.profile.weapons,"ending dialogue does not delay or remove fixed rewards")
	dialogue.select("friends")
	check(story.last_voice_character=="gugu","reunion responds with Gugu voice")
	dialogue.select("continue")
	check(dialogue.content_label.text.contains("40级") and dialogue.content_label.text.contains("打完4-1"),"ending points to available fourth chapter and correct departure timing")
	dialogue.select("continue")
	await frames()
	check(get_nodes_in_group("victory_video").size()==1,"optional video choice appears after ending")
	get_nodes_in_group("victory_video")[0].close()
	await frames()
	check(not paused and campaign.character_allowed("gugu"),"friends remain usable in existing chapters")
	# Simulate quitting after rewards were saved but before reading the ending.
	story.progress().seen.erase("27:outro")
	level.queue_free()
	await frames()
	level=scene(27)
	await frames()
	check(dialogue.active and story.running.get("key")=="27:outro","reload of completed final battle resumes unseen reunion")
	dialogue.close()
	await frames()
	check(get_nodes_in_group("victory_video").size()==1,"resumed reunion still leads to video choice")
	get_nodes_in_group("victory_video")[0].close()
	await frames()
	story.enter_world(level)
	await frames()
	check(not dialogue.active and get_nodes_in_group("victory_video").is_empty(),"watched ending never reopens automatically on repeat visit")
	for chapter in [1,2,3]:
		campaign.hub_chapter=chapter
		campaign.active_level=0
		campaign.profile.q_penguin_unlocked=true
		campaign.profile.mercenary_prepaid=false
		campaign.profile.coins=1000
		check(campaign.can_hire_mercenary()==(chapter==3),"temporary Q hiring limited to chapter three")
	level.queue_free()
	await frames()
	campaign.reset_state()
	check(story.progress().seen.is_empty() and story.progress().tutorial.is_empty(),"new game resets story and training")
	print("Story integration: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
