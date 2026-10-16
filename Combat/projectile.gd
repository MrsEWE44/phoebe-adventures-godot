extends Area2D
var source_actor: WeakRef
func damage_source() -> Node:
	return source_actor.get_ref() if source_actor!=null else null

var target_multipliers: Dictionary={}

var direction := Vector2.RIGHT
var speed := 300.0
var damage := 20.0
var damage_type := "physical"
var hostile := false
var distance_left := 430.0
var spent := false
var texture: Texture2D
var display_width := 15.0
var explosion_radius := 0.0
var pierce_left := 0
var pierce_all := false
var bounces_left := 0
var aquatic_multiplier := 1.0
var hit_ids: Dictionary = {}
var ignored: Array[RID] = []

var hit_radius := 0.0
var collision_shape: CircleShape2D
var homing:=false
var boss_multiplier:=1.0
var hit_effect:=""
var target_health_ratios: Dictionary={}
var critical_chance:=0.0
var critical_multiplier:=1.8
var critical_hit:=false
var chain_targets:=0
var chain_radius:=175.0

func _ready() -> void:
	add_to_group("projectiles")
	critical_hit=critical_chance>0 and randf()<critical_chance
	collision_layer = 0
	collision_mask = 19 if hostile else 14
	if texture == null:
		texture = preload("res://Weapons/weapon_art.gd").texture(15 if damage_type=="magic" else 12)
	if hit_radius<=0:
		hit_radius = clampf(display_width*texture.get_height()/texture.get_width()*.32,1.5,8)
	var collision := CollisionShape2D.new()
	collision_shape = CircleShape2D.new()
	collision_shape.radius = hit_radius
	collision.shape = collision_shape
	add_child(collision)
	body_entered.connect(_hit)
	area_entered.connect(_hit)
	rotation = direction.angle()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	if spent:
		return
	if homing and not hostile:
		var best: Node2D
		var nearest:=650.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var center: Vector2=enemy.combat_center()
			var distance:=global_position.distance_to(center)
			if distance>=nearest: continue
			if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,center,2)).is_empty(): continue
			nearest=distance
			best=enemy
		if best!=null:
			direction=direction.slerp(global_position.direction_to(best.combat_center()),minf(1,delta*6)).normalized()
			rotation=direction.angle()
	var step := direction * minf(speed*delta,distance_left)
	var start := global_position
	var end := start+step
	var space := get_world_2d().direct_space_state
	# Sweep the actual projectile thickness. Detects body edges and thin walls at high speed.
	for iteration in 12:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = ignored
		query.transform = Transform2D(0,start)
		var hits := space.intersect_shape(query,16)
		if hits.is_empty():
			query.motion = end-start
			var travel := space.cast_motion(query)
			if travel[0]>=1:
				break
			global_position = start+(end-start)*travel[1]+direction*.02
			query.transform = Transform2D(0,global_position)
			query.motion = Vector2.ZERO
			hits = space.intersect_shape(query,16)
		else:
			global_position = start
		if hits.is_empty():
			# Never advance through a collision that the sweep found.
			spent = true
			queue_free()
			return
		# Terrain wins ties, so a target behind the wall cannot absorb the wall contact.
		var collider: Node2D = hits[0].collider
		for hit in hits:
			if hit.collider is CollisionObject2D and (hit.collider.collision_layer & 2)!=0:
				collider = hit.collider
				break
		if collider is CollisionObject2D and (collider.collision_layer & 2) != 0 and bounces_left > 0:
			# Use the swept shape's surface normal, and stop this frame at the impact.
			var probe := PhysicsShapeQueryParameters2D.new()
			probe.shape = collision_shape
			probe.collision_mask = 2
			probe.transform = Transform2D(0,global_position)
			var rest := space.get_rest_info(probe)
			var normal: Vector2 = rest.get("normal",-direction)
			direction = direction.bounce(normal).normalized()
			global_position += normal * (hit_radius+1.0)
			rotation = direction.angle()
			bounces_left -= 1
			distance_left -= maxf(1.0,start.distance_to(global_position))
			return
		_hit(collider)
		if spent:
			return
		start = global_position
	global_position = end
	distance_left -= step.length()
	if distance_left <= 0:
		spent = true
		if explosion_radius > 0:
			_explode()
		queue_free()

func _hit(body: Node2D) -> void:
	if spent or not is_instance_valid(body):
		return
	var target: Node2D = body.actor if body.get("actor") is Node2D else body
	# Bouncing wall contacts are resolved by the sweep, not overlap callbacks.
	if body is CollisionObject2D and (body.collision_layer & 2) != 0 and bounces_left > 0:
		return
	if hit_ids.has(target.get_instance_id()):
		return
	hit_ids[target.get_instance_id()] = true
	get_node("/root/Global").play_sfx("impact")
	if explosion_radius > 0:
		spent = true
		_explode(target)
	elif target.has_method("take_damage"):
		preload("res://Combat/player_damage.gd").hit(damage_source(),target,_damage_for(target),damage_type)
		preload("res://Combat/weapon_status.gd").apply(target,hit_effect,damage,damage_source())
		if not hostile and chain_targets>0 and target.get("definition")!=null and target.definition.character_type!=2:
			_chain_from(target)
		if (pierce_all or pierce_left > 0) and body is CollisionObject2D:
			if not pierce_all: pierce_left -= 1
			if target.has_method("damage_rids"):
				ignored.append_array(target.damage_rids())
			else:
				ignored.append(body.get_rid())
			return
	spent = true
	queue_free()

func _explode(direct_target: Node2D = null) -> void:
	var targets := get_tree().get_nodes_in_group("players" if hostile else "enemies")
	if hostile: targets=preload("res://Combat/teams.gd").friendly_targets(get_tree())
	for target in targets:
		if not is_instance_valid(target):
			continue
		var center: Vector2 = target.combat_center() if target.has_method("combat_center") else target.global_position
		if center.distance_to(global_position)>explosion_radius:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position,center,2)
		if target==direct_target or get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			preload("res://Combat/player_damage.gd").hit(damage_source(),target,_damage_for(target),damage_type)
			preload("res://Combat/weapon_status.gd").apply(target,hit_effect,damage,damage_source())
	var effect := preload("res://Combat/impact_effect.gd").new()
	effect.position = position
	effect.radius = explosion_radius
	effect.tint = Color("98baff") if damage_type=="magic" else Color("ffc17b")
	get_parent().call_deferred("add_child",effect)

func _damage_for(target: Node2D) -> float:
	var spec: Resource = target.get("definition")
	var amount:=(damage * aquatic_multiplier) if spec != null and spec.aquatic else damage
	if spec!=null and spec.character_type==3: amount=(amount*boss_multiplier)
	if spec!=null: amount*=float(target_multipliers.get(spec.character_id,1.0))
	if spec!=null and target_health_ratios.has(spec.character_id):
		amount=maxf(amount,float(target.max_health)*float(target_health_ratios[spec.character_id]))
	if critical_hit: amount*=critical_multiplier
	return amount

func _chain_from(first: Node2D) -> void:
	var origin: Vector2=first.combat_center()
	var points:=PackedVector2Array([origin])
	for hop in chain_targets:
		var nearest: Node2D
		var distance:=chain_radius
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate.is_dead or hit_ids.has(candidate.get_instance_id()): continue
			var center: Vector2=candidate.combat_center()
			var delta:=origin.distance_to(center)
			if delta>distance: continue
			if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(origin,center,2)).is_empty(): continue
			nearest=candidate
			distance=delta
		if nearest==null: break
		hit_ids[nearest.get_instance_id()]=true
		origin=nearest.combat_center()
		points.append(origin)
		preload("res://Combat/player_damage.gd").hit(damage_source(),nearest,_damage_for(nearest),damage_type)
		preload("res://Combat/weapon_status.gd").apply(nearest,hit_effect,damage,damage_source())
	var effect:=preload("res://Combat/resonance_chain.gd").new()
	effect.points=points
	effect.critical=critical_hit
	get_parent().call_deferred("add_child",effect)

func _draw() -> void:
	if pierce_all: draw_line(Vector2(-38,0),Vector2.ZERO,Color("ffe5a0"),3,true)
	if texture != null:
		var size := texture.get_size() * (display_width/texture.get_width())
		draw_texture_rect(texture,Rect2(-size*.5,size),false,Color("ff8a94") if hostile else (Color("ffe28b") if critical_hit else Color.WHITE))
