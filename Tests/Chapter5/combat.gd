extends SceneTree
var checks:=0
var failures:=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=root.get_node("Campaign")
	c.saving_enabled=false
	root.get_node("Story").automatic_enabled=false
	c.reset_state(60)
	c.hub_chapter=5
	c.active_level=40
	c.profile.miku_unlocked=true
	c.profile.reimu_unlocked=true
	var w=load(c.Catalog.scene_path(40)).instantiate()
	w.spawn_enemies=false
	root.add_child(w)
	w.set_process(false)
	w.player.set_physics_process(false)
	await physics_frame
	await process_frame
	var p=w.player
	p.position=w.geometry.nearest(w.get_node("ArenaCenter").position)
	var e=w.spawn_kind("naiwa_red_full",false,p.position+Vector2(35,0))
	e.set_physics_process(false)
	e.health=1000000
	e.max_health=1000000
	c.select_character("miku")
	ck(p.voice.profile==null,"new character never borrows previous voice")
	preload("res://Scence/Chapter5/abilities.gd").play(p,Vector2.RIGHT)
	ck(e.root_remaining>0 and e.dot_remaining>0,"Miku roots and applies damage over time")
	var old_hp: float=e.health
	e.tick_character(1.01)
	ck(e.health<old_hp,"Miku damage over time actually reduces health")
	p.tick_character(2)
	ck(c.select_character("reimu"),"select Reimu after casting ends")
	var small=w.spawn_kind("naiwa_green_mini",false,p.position+Vector2(40,0))
	small.set_physics_process(false)
	e.health=1000000
	e.dot_remaining=0
	preload("res://Scence/Chapter5/abilities.gd").play(p,Vector2.RIGHT)
	ck(small.is_dead,"scythe kills armored mid-stage Naiwa")
	old_hp=e.health
	var expected: float=p.attack_damage(p.normal_weapon.damage)*3
	preload("res://Scence/Chapter5/abilities.gd").play(p,Vector2.RIGHT,true)
	ck(is_equal_approx(old_hp-e.health,expected),"Reimu ultimate hits for triple current attack damage")
	for id in ["phoebe","nuonuo","doro","gugu"]:
		c.profile[id+"_unlocked"]=true
		c.profile.party_health[id]=100
	for i in [28,43,44,45,47]: c.completed.append(i)
	p.tick_character(2)
	ck(c.select_character("phoebe"),"select rescued Phoebe after casting ends")
	e.health=e.max_health
	preload("res://Combat/player_damage.gd").hit(p,e,1,"physical")
	ck(is_equal_approx(e.health,e.max_health*.3),"friendship removes 70 percent full Naiwa health")
	c.profile.party_health.doro=0
	e.health=e.max_health
	preload("res://Combat/player_damage.gd").hit(p,e,1,"physical")
	ck(e.health>e.max_health*.99,"fallen friend disables friendship strike")
	c.select_character("miku")
	ck(p.voice.profile==null,"switching from Phoebe clears voice")
	for boss in range(1,7):
		var b=w.spawn_kind("hell_boss_%d"%boss,true,p.position+Vector2(100,0))
		b.set_physics_process(false)
		b.combat_target=p
		b.target_point=p.position
		for action in ["meteor","summon","curse","leap"]: b.execute(action)
		ck(b.skill_rank==4,"boss skill rank "+str(boss))
	w.queue_free()
	await process_frame
	await process_frame
	print("CHAPTER5 COMBAT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
