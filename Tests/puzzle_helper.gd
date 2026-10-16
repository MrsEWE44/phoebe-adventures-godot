extends RefCounted
static func clear_enemies(level: Node2D) -> void:
	for enemy in level.get_tree().get_nodes_in_group("enemies"):
		enemy.invulnerable=0
		enemy.take_damage(99999,"magic")
	await level.get_tree().process_frame
	await level.get_tree().physics_frame

static func open_until_final(level: Node2D) -> void:
	level.player.set_physics_process(false)
	level.player.invulnerable=10000
	if level.adventure!=null:
		for cell in level.geometry.reachable_cells(level.player.position):
			var point: Vector2=level.geometry.nav.get_point_position(cell)
			if not level.is_spawn_safe(point):
				level.player.position=point
				break
		level.adventure.start_patrol()
	for door in level.doors:
		if door.activated: continue
		await clear_enemies(level)
		door.interact()
		await level.get_tree().process_frame
		await level.get_tree().physics_frame
		for enemy in level.get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)

static func solve(mechanism: Node2D) -> void:
	if mechanism.activated:
		return
	for id in mechanism.puzzle.get("requires_switches",[]):
		for other in mechanism.level.switches:
			if str(other.config.id)==str(id): solve(other)
	mechanism.cooldown_until=0
	if mechanism.puzzle.get("mode")=="riddle":
		mechanism.choose(str(int(mechanism.puzzle.answer)))
	elif mechanism.puzzle.get("mode")=="hold":
		var player = mechanism.level.player
		var before: Vector2 = player.position
		player.position = mechanism.position
		player.velocity=Vector2.ZERO
		mechanism._process(float(mechanism.puzzle.seconds)+.1)
		player.position = before
	elif mechanism.puzzle.get("mode")=="direction":
		while mechanism.turns!=int(mechanism.puzzle.target):
			mechanism.choose("right")
		mechanism.choose("confirm")
	elif mechanism.puzzle.get("mode")=="circuit":
		var total: int=mechanism.circuit.size()
		for bits in (1<<total):
			var values: Array=mechanism.circuit.duplicate()
			for i in total:
				if bits&(1<<i):
					for offset in [-1,0,1]: values[posmod(i+offset,total)]=1-int(values[posmod(i+offset,total)])
			if mechanism.circuit_matches(values,mechanism.puzzle.target):
				for i in total:
					if bits&(1<<i): mechanism.choose(str(i))
				break
	elif mechanism.puzzle.get("mode")=="balance":
		for a in 4:
			for b in 4:
				for c in 4:
					if a+2*b+3*c!=int(mechanism.puzzle.target): continue
					var values := [a,b,c]
					for i in 3:
						while int(mechanism.valves[i])!=values[i]: mechanism.choose(str(i))
					mechanism.choose("confirm")
					return
	else:
		for digit in mechanism.puzzle.sequence:
			mechanism.choose(str(int(digit)))
