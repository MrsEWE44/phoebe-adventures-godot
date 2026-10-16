extends SceneTree
const Helper=preload("res://Tests/puzzle_helper.gd")
const Catalog=preload("res://Scence/Levels/catalog.gd")
var checks:=0
var failures:=0
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",text)
func frames(n:=2) -> void:
	for i in n:
		await process_frame
		await physics_frame
func kill_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.invulnerable=0
		enemy.take_damage(enemy.max_health*2,"true")
func run() -> void:
	campaign=root.get_node("Campaign")
	campaign.saving_enabled=false
	campaign.reset_state()
	for index in range(1,18):
		campaign.level_state(index).seed=13579+index
		var level=load(Catalog.scene_path(index)).instantiate()
		root.add_child(level)
		level.player.set_physics_process(false)
		level.player.invulnerable=10000
		await frames()
		check(get_nodes_in_group("enemies").is_empty(),"safe circle postpones patrol %d"%index)
		check(not level.player.attack() and not level.player.trigger_ultimate(),"safe circle blocks attack and ultimate %d"%index)
		var hp: float=level.player.health
		level.player.invulnerable=0
		level.player.take_damage(9999)
		check(level.player.health==hp,"safe circle protects player %d"%index)
		for cell in level.geometry.base_free:
			var p: Vector2=level.geometry.nav.get_point_position(cell)
			if p.distance_to(level.get_node("Spawn").position)>110:
				level.player.position=p
				break
		level.adventure._process(.1)
		check(get_nodes_in_group("enemies").size()>=int(level.config.adventure.patrol_count),"increased patrol density %d"%index)
		for enemy in get_nodes_in_group("enemies"):
			enemy.set_physics_process(false)
			check(not level.is_spawn_safe(enemy.position),"patrol outside protected circle")
			check(not level.geometry.path(level.player.position,enemy.position).is_empty(),"patrol reachable before doors open")
		for mechanism in level.switches:
			Helper.solve(mechanism)
			check(mechanism.activated,"complex puzzle solved %d/%s"%[index,mechanism.name])
		level.doors[0].interact()
		check(campaign.level_state(index).doors.is_empty(),"live patrol prevents opening a door %d"%index)
		kill_enemies()
		await frames()
		for door in level.doors:
			check(level.can_open_door(door),"clear combat enables manual opening %d/%s"%[index,door.name])
			door.interact()
			await frames()
			if not campaign.level_state(index).encounters.has(str(door.config.id)):
				check(false,"door must create a persistent encounter")
				quit(1)
				return
			var room: Dictionary=campaign.level_state(index).encounters[str(door.config.id)]
			check(str(door.config.id) in campaign.level_state(index).doors,"E opens prepared door")
			if not room.cleared:
				check(not level.adventure.can_open_next_door(),"door monsters block next door")
				check(not room.actors.is_empty(),"combat room has living enemies")
				var minimum: int=int(level.config.adventure.boss_pack if room.kind=="boss" else level.config.adventure.min_pack)
				check(room.actors.size()>=minimum,"door encounter reaches increased pack size %d/%s"%[index,door.name])
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
				if enemy.encounter_id==str(door.config.id):
					check(enemy.position.distance_to(door.position)<190,"encounter emerges beside opened door")
					check(not level.is_spawn_safe(enemy.position),"door enemy stays outside safety circle")
					check(not level.geometry.path(level.player.position,enemy.position).is_empty(),"door enemy reachable")
			kill_enemies()
			await frames()
		if index in [6,16]:
			check(index not in campaign.completed,"rescue required on penultimate level")
			check(campaign.rescue_companion("nuonuo" if index==6 else "ikun"),"penultimate companion rescued")
		check(index in campaign.completed,"full expedition completes %d"%index)
		if index==6: check(campaign.profile.nuonuo_unlocked and 7 not in campaign.completed,"Nuonuo available before first finale")
		if index==16: check(campaign.profile.ikun_unlocked and 17 not in campaign.completed,"Ikun available before underwater finale")
		check(level.adventure.remaining_enemies()==0,"all encounter records cleared")
		print("Expedition verified ",Catalog.label(index))
		level.queue_free()
		await frames()
	print("Expedition checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
