extends RefCounted
## Allies share hostile targeting without entering the controllable-player group.
static func friendly_targets(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("players")+tree.get_nodes_in_group("allies")
static func enemy_target(enemy: Node2D, world: Node) -> Node2D:
	var best: Node2D=world.player
	var score:=INF
	for target in friendly_targets(enemy.get_tree()):
		if not is_instance_valid(target) or target.is_dead or target.get_parent()!=world: continue
		var distance:=enemy.global_position.distance_squared_to(target.global_position)
		# Attack the captive when the player does not intercept nearby enemies.
		if target.get("role")=="doro": distance*=.45
		if distance<score: best=target;score=distance
	return best
