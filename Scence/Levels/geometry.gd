extends Node2D
## Read-only navigation from scene collisions; never creates physical nodes.
const CELL := 8
var grid := Vector2i.ZERO
var floor_cells: Dictionary = {}
var nav := AStarGrid2D.new()
var wall_count := 0
var debug_overlay := false
var base_free: Array[Vector2i] = []
var foot := RectangleShape2D.new()

var build_ms := 0.0
var floor_rects: Array[Rect2] = []

func build(terrain: Node2D, spawn: Vector2, map_size: Vector2) -> void:
	var started := Time.get_ticks_usec()
	grid = Vector2i(ceil(map_size.x / CELL), ceil(map_size.y / CELL))
	foot.size = Vector2(18, 12)
	var shapes: Array[Dictionary] = []
	_collect_shapes(terrain, shapes)
	wall_count = terrain.get_child_count()
	nav.region = Rect2i(Vector2i.ZERO, grid)
	nav.cell_size = Vector2(CELL, CELL)
	nav.offset = Vector2(4, 4)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	nav.fill_solid_region(nav.region, true)
	floor_cells.clear()
	base_free.clear()
	var blocked := PackedByteArray()
	blocked.resize(grid.x*grid.y)
	# Rasterize only the cells touched by each collider's expanded bounds.
	# The old all-cells x all-shapes loop cost over a second on larger maps.
	for record in shapes:
		var bounds: Rect2 = record.bounds.grow_individual(9,6,9,6)
		var first := cell_at(bounds.position)
		var last := cell_at(bounds.end)
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var index := y*grid.x+x
				if blocked[index] == 0 and foot.collide(Transform2D(0,nav.get_point_position(Vector2i(x,y))),record.shape,record.transform):
					blocked[index] = 1
	var seed := cell_at(spawn)
	if blocked[seed.y*grid.x+seed.x] != 0:
		var distance := INF
		for y in grid.y:
			for x in grid.x:
				if blocked[y*grid.x+x] != 0: continue
				var cell := Vector2i(x,y)
				var d := nav.get_point_position(cell).distance_squared_to(spawn)
				if d < distance:
					distance = d
					seed = cell
	if blocked[seed.y*grid.x+seed.x] == 0:
		base_free.append(seed)
		blocked[seed.y*grid.x+seed.x] = 1
	var cursor := 0
	while cursor < base_free.size():
		var cell := base_free[cursor]
		cursor += 1
		floor_cells[cell] = true
		nav.set_point_solid(cell, false)
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not nav.region.has_point(next): continue
			var index := next.y*grid.x+next.x
			if blocked[index] == 0:
				blocked[index] = 1
				base_free.append(next)
	_rebuild_floor_rects()
	build_ms = (Time.get_ticks_usec()-started)/1000.0
	queue_redraw()

func _collect_shapes(node: Node, records: Array[Dictionary], include_disabled := false) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		if (node.disabled and not include_disabled) or not node.get_parent() is CollisionObject2D:
			return
		if (node.get_parent().collision_layer & 2) == 0:
			return
		var xform: Transform2D = get_parent().global_transform.affine_inverse() * node.global_transform
		if node is CollisionShape2D and node.shape != null:
			_record(node.shape, xform, records)
		elif node is CollisionPolygon2D and node.polygon.size() >= 3:
			if node.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
				for points in Geometry2D.decompose_polygon_in_convex(node.polygon):
					var shape := ConvexPolygonShape2D.new()
					shape.points = points
					_record(shape, xform, records)
			else:
				for i in node.polygon.size():
					var shape := SegmentShape2D.new()
					shape.a = node.polygon[i]
					shape.b = node.polygon[(i+1) % node.polygon.size()]
					_record(shape, xform, records)
	for child in node.get_children():
		_collect_shapes(child, records, include_disabled)

func _record(shape: Shape2D, xform: Transform2D, records: Array[Dictionary]) -> void:
	records.append({"shape": shape, "transform": xform, "bounds": xform * shape.get_rect()})

func _blocked(p: Vector2, records: Array[Dictionary]) -> bool:
	var bounds := Rect2(p-foot.size*.5, foot.size)
	for record in records:
		if bounds.intersects(record.bounds, true) and foot.collide(Transform2D(0,p),record.shape,record.transform):
			return true
	return false

func update_doors(doors: Array[Node2D]) -> void:
	var shapes: Array[Dictionary] = []
	for door in doors:
		if not door.activated:
			_collect_shapes(door, shapes, true)
	for cell in base_free:
		nav.set_point_solid(cell, _blocked(nav.get_point_position(cell), shapes))
	_rebuild_floor_rects()
	queue_redraw()

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / CELL),0,grid.x-1),clampi(floori(p.y / CELL),0,grid.y-1))

func nearest(p: Vector2) -> Vector2:
	var c := cell_at(p)
	if not nav.is_point_solid(c):
		return nav.get_point_position(c)
	var best := p
	var distance := INF
	for cell in base_free:
		if not nav.is_point_solid(cell):
			var v := nav.get_point_position(cell)
			if v.distance_squared_to(p) < distance:
				distance = v.distance_squared_to(p)
				best = v
	return best

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if base_free.is_empty():
		return PackedVector2Array()
	return nav.get_point_path(cell_at(nearest(from)),cell_at(nearest(to)))

func reachable_cells(from: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [cell_at(nearest(from))]
	var seen := {cells[0]:true}
	var cursor := 0
	while cursor<cells.size():
		var cell := cells[cursor]
		cursor+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if nav.region.has_point(next) and not seen.has(next) and not nav.is_point_solid(next):
				seen[next]=true
				cells.append(next)
	return cells

func safe_spawn(preferred: Vector2, actor: CharacterBody2D) -> Vector2:
	# Candidates must belong to the spawn-connected floor, not merely empty space.
	var candidates := base_free.duplicate()
	candidates.sort_custom(func(a: Vector2i,b: Vector2i):
		return nav.get_point_position(a).distance_squared_to(preferred)<nav.get_point_position(b).distance_squared_to(preferred))
	var collision: CollisionShape2D = actor.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = 38
	query.collide_with_areas = true
	query.exclude = [actor.get_rid()]
	var xform := actor.transform
	for cell in candidates:
		if nav.is_point_solid(cell): continue
		var point := nav.get_point_position(cell)
		xform.origin = point
		query.transform = get_parent().global_transform*xform*collision.transform
		if get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			return point
	return Vector2.INF

func _rebuild_floor_rects() -> void:
	floor_rects.clear()
	for y in grid.y:
		var start := -1
		for x in range(grid.x+1):
			var free := x < grid.x and not nav.is_point_solid(Vector2i(x,y))
			if free and start < 0: start = x
			if not free and start >= 0:
				floor_rects.append(Rect2(start*CELL,y*CELL,(x-start)*CELL,CELL))
				start = -1

func _draw() -> void:
	if debug_overlay:
		for rect in floor_rects:
			draw_rect(rect,Color(0,1,0,.2))
