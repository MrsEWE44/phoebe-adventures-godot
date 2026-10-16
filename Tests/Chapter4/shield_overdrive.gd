extends SceneTree
const Battle=preload("res://Scence/Chapter4/final_battle.gd")
const Damage=preload("res://Combat/player_damage.gd")
var checks:=0
var failures:=0
var c: Node
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for tick in 3:
		await physics_frame
		await process_frame
func freeze(w: Node) -> void:
	w.spawn_enemies=false
	w.set_process(false)
	w.player.set_physics_process(false)
	for a in w.living()+w.music_allies: a.set_physics_process(false)
func run() -> void:
	c=root.get_node("Campaign")
	c.saving_enabled=false
	c.set_process(false)
	root.get_node("Story").automatic_enabled=false
	c.reset_state(40)
	ck(c.item_count("battle_overdrive")==0 and not c.consume_item("battle_overdrive"),"locked before 4-5")
	for index in range(28,37):
		c.level_state(index).arena={"finished":true}
		c.complete_arena(index)
	ck(c.item_count("battle_overdrive")==1,"4-5 clear permanently grants item")
	ck(not c.consume_item("battle_overdrive"),"cannot waste item in hub")
	c.active_level=37
	c.hub_chapter=4
	change_scene_to_file(c.Catalog.scene_path(37))
	await scene_changed
	await settle()
	var w=current_scene
	freeze(w)
	ck(c.select_character("soyo"),"select conductor")
	w.conduct(w.player)
	var performer=w.music_allies[0]
	ck(not performer.shield_active(),"shield waits for full deployment")
	w.conduct(w.player)
	w.conduct(w.player)
	await settle()
	freeze(w)
	for ally in w.music_allies:
		ck(ally.shield_active(),"deployed musician shield enabled")
		for type in ["physical","magic","true"]:
			ally.invulnerable=0
			var hp: float=ally.health
			ally.take_damage(100,type)
			ck(is_equal_approx(hp-ally.health,2.0),"shield absorbs 98 percent of "+type)
	var origin:=Vector2.ZERO
	for ally in w.music_allies: origin+=ally.combat_center()/3.0
	var recruits: Array=[]
	for species in ["naiwa_minion","naiwa_mini","naiwa_full","naiwa_full","naiwa_mini","naiwa_minion"]:
		var enemy=w.spawn_kind(species,false,origin+Vector2(70,0))
		enemy.position=origin+Vector2(70,0)
		enemy.set_physics_process(false)
		recruits.append(enemy.record)
	Battle.pulse(w)
	ck(w.music_allies.size()==9,"all six Naiwa recruited beyond ordinary ally cap")
	for record in recruits: ck(record.get("assimilated",false) and record.dead and record.ally.hp>0,"all Naiwa forms converted alive")
	await settle()
	freeze(w)
	var friendly=w.music_allies[3]
	var enemy=w.spawn_kind("weiro_full",false,friendly.position+Vector2(60,0))
	enemy.position=friendly.position+Vector2(60,0)
	enemy.set_physics_process(false)
	enemy.max_health=10000
	enemy.health=10000
	enemy.record.max_hp=10000
	enemy.record.hp=10000
	friendly.fire_clock=0
	friendly._physics_process(.01)
	ck(enemy.health<10000,"converted Naiwa autonomously attacks hostile enemy")
	# Exercise inventory action and visible quick-use button, not only the data API.
	var bag=load("res://UI/inventory.gd").new()
	root.add_child(bag)
	bag.open()
	bag.category=0
	bag.selected="battle_overdrive"
	bag.refresh()
	var entries: Array=bag.entries.filter(func(e):return e.id=="battle_overdrive")
	ck(entries.size()==1 and entries[0].icon!=null and entries[0].enabled,"inventory item icon and action")
	paused=true
	bag.activate_selected()
	ck(is_equal_approx(c.overdrive_remaining(),30),"inventory button starts 30 seconds")
	c._process(10)
	ck(is_equal_approx(c.overdrive_remaining(),30),"pause freezes duration")
	paused=false
	ck(not c.consume_item("battle_overdrive"),"second use rejected")
	c._process(1)
	ck(is_equal_approx(c.overdrive_remaining(),29),"combat decrements duration")
	var quick=load("res://UI/consumable_bar.gd").new()
	root.add_child(quick)
	quick.refresh()
	ck(quick.buttons.battle_overdrive.visible and quick.buttons.battle_overdrive.disabled and quick.buttons.battle_overdrive.text.contains("29 秒"),"quick bar displays timer and disables reuse")
	enemy.invulnerable=0
	var hp: float=enemy.health
	Damage.hit(w.player,enemy,1,"physical")
	ck(is_equal_approx(hp-enemy.health,999),"low-damage hit becomes exactly 999 true damage")
	var shot=load("res://Scence/Chapter3/abilities.gd").shot(w.player,Vector2.RIGHT,10,0)
	shot.set_physics_process(false)
	shot._hit(enemy.hurtbox)
	ck(is_equal_approx(hp-enemy.health,1998),"real player projectile inherits buff at impact")
	var blast=preload("res://Combat/projectile.gd").new()
	blast.source_actor=weakref(w.player)
	blast.position=enemy.combat_center()
	blast.explosion_radius=100
	blast.damage=3
	w.add_child(blast)
	blast.set_physics_process(false)
	hp=enemy.health
	blast._hit(enemy.hurtbox)
	ck(is_equal_approx(hp-enemy.health,999),"explosion resolves true damage once")
	var hazard=load("res://Scence/Chapter3/hazard.gd").new()
	hazard.source_actor=weakref(w.player)
	hazard.hostile=false
	hazard.visual="sonic"
	hazard.position=enemy.combat_center()
	w.add_child(hazard)
	hazard.set_physics_process(false)
	hp=enemy.health
	hazard.strike(1)
	ck(is_equal_approx(hp-enemy.health,999),"player area skill receives buff")
	hazard.queue_free()
	hp=friendly.health
	Damage.hit(w.player,friendly,100,"true")
	ck(is_equal_approx(hp-friendly.health,45),"buff does not amplify friendly fire")
	hp=enemy.health
	Damage.hit(friendly,enemy,100,"physical")
	ck(hp-enemy.health<100,"ally attacks do not inherit player buff")
	c._process(29)
	ck(c.overdrive_remaining()==0 and not c.consume_item("battle_overdrive"),"expiry does not restore use")
	hp=enemy.health
	Damage.hit(w.player,enemy,100,"physical")
	ck(hp-enemy.health<100,"armor applies again after expiry")
	# Save current attempt and restore without touching the user's save.
	c.level_state(37).overdrive_remaining=12
	w.snapshot()
	c.save_path="res://.godot/shield-overdrive-test.json"
	c.saving_enabled=true
	c.save_progress()
	c.saving_enabled=false
	bag.queue_free()
	quick.queue_free()
	w.queue_free()
	await settle()
	c.reset_state(1)
	ck(c.load_progress(),"isolated save loads")
	c.saving_enabled=false
	ck(c.item_count("battle_overdrive")==1 and is_equal_approx(c.overdrive_remaining(),12) and not c.can_consume_item("battle_overdrive"),"unlock timer and used flag survive reload")
	change_scene_to_file(c.Catalog.scene_path(37))
	await scene_changed
	await settle()
	w=current_scene
	freeze(w)
	ck(w.music_allies.size()==9,"converted allies and musicians restore once")
	ck(w.music_allies.filter(func(a):return a.shield_active()).size()==3,"restored band keeps shield")
	ck(c.return_to_hub(),"leave unfinished level")
	await scene_changed
	await settle()
	ck(c.overdrive_remaining()==0 and c.level_state(37).overdrive_used,"leaving cancels effect but preserves used flag")
	ck(c.enter_level(37),"reenter same attempt")
	await scene_changed
	await settle()
	w=current_scene
	freeze(w)
	ck(not c.consume_item("battle_overdrive"),"hub round-trip cannot refill use")
	ck(c.retry_current_level(),"retry current attempt")
	await scene_changed
	await settle()
	freeze(current_scene)
	ck(c.consume_item("battle_overdrive"),"retry restores single use")
	c.active_level=36
	c.states.erase("36")
	ck(c.consume_item("battle_overdrive"),"another stage has separate use")
	c.mark_character_dead()
	ck(c.overdrive_remaining()==0 and c.level_state(36).overdrive_used,"death ends buff without restoring use")
	c.reset_state(1)
	ck(c.item_count("battle_overdrive")==0,"new save removes unlock")
	current_scene.queue_free()
	await settle()
	print("SHIELD AND OVERDRIVE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
