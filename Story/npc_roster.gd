extends RefCounted
## Place nonblocking services on reachable floor; never change authored terrain.
static func setup(world: Node2D) -> Node:
	var roles: Array[String]=["guide","puzzle" if world.level_index<18 else "tactics","merchant"]
	if world.level_index in [1,6,16,24,26,27]: roles.append("medic")
	elif world.level_index>=28: roles.append("medic" if world.level_index%2==0 else "smith")
	elif world.level_index in [5,15,23,25]: roles.append("smith")
	var origin: Vector2=world.get_node("Spawn").position
	var points: Array[Vector2]=[]
	for cell in world.geometry.reachable_cells(origin): points.append(world.geometry.nav.get_point_position(cell))
	var occupied: Array[Vector2]=[origin]
	for field in ["captive","mercenary"]:
		var actor: Node2D=world.get(field)
		if is_instance_valid(actor): occupied.append(actor.position)
	for actor in world.get_tree().get_nodes_in_group("fixed_npcs"):
		if actor.get_parent()==world: occupied.append(actor.position)
	var chests: Array[Vector2]=[]
	for chest in world.get_tree().get_nodes_in_group("chests"):
		if world.is_ancestor_of(chest): chests.append(world.to_local(chest.global_position))
	for nodes in [world.doors,world.switches]:
		for node in nodes: occupied.append(node.position)
	for path in ["ReturnPortal","Portals/Exit","RescuePosition"]:
		if world.has_node(path): occupied.append(world.get_node(path).position)
	var offsets: Array[Vector2]=[Vector2(35,-40),Vector2(-75,-55),Vector2(75,-110),Vector2(-35,-135)]
	var guide: Node
	for i in roles.size():
		var preferred: Vector2=origin+offsets[i]
		points.sort_custom(func(a,b): return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
		var position:=Vector2.INF
		for point in points:
			if occupied.any(func(other): return point.distance_to(other)<36): continue
			if chests.any(func(other): return point.distance_to(other)<48): continue
			position=point
			break
		if not position.is_finite(): push_warning("No reachable NPC placement for "+roles[i]);continue
		var npc=load("res://Story/story_guide.tscn").instantiate()
		npc.name="Service_"+roles[i]
		npc.service_role=roles[i]
		npc.position=position
		world.add_child(npc)
		occupied.append(position)
		if roles[i]=="guide": guide=npc
	return guide
