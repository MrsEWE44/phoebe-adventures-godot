extends Node2D
var source_actor: WeakRef
var radius := 110.0
var tint := Color("d6b2ff")
var duration := .55
var age := 0.0
var warning := false
var pulses_left := 0
var pulse_damage := 0.0
var pulse_timer := .45

static func telegraph(actor: Node2D, spec: Resource) -> void:
	var effect = load("res://Combat/ultimate_effect.gd").new()
	effect.radius = spec.radius
	effect.tint = Color("ff645f") if actor.character_type in [1,3] else spec.tint
	effect.duration = spec.windup
	effect.warning = true
	actor.add_child(effect)
	effect.z_index = -1

static func release(actor: Node2D, spec: Resource, direction: Vector2) -> void:
	var hostile: bool = actor.character_type in [1,3]
	if spec.mode == "shot":
		for i in spec.projectile_count:
			var shot = preload("res://Combat/projectile.gd").new()
			shot.source_actor=weakref(actor)
			shot.position = actor.position
			shot.direction = direction.rotated((i-(spec.projectile_count-1)*.5)*.16)
			shot.damage = spec.damage
			shot.damage_type = "magic"
			shot.hostile = hostile
			shot.speed = spec.projectile_speed
			shot.distance_left = spec.projectile_range
			shot.display_width = 30
			shot.pierce_left = spec.pierce
			shot.explosion_radius = spec.impact_radius
			shot.texture = preload("res://Weapons/weapon_art.gd").texture(15)
			if spec.weapon_id == "basketball":
				shot.texture = preload("res://Weapons/chapter2_art.gd").texture(4)
				shot.bounces_left = spec.bounces
				shot.hit_radius = 7
				shot.display_width = 25
			actor.get_parent().add_child(shot)
	else:
		var targets: Array=preload("res://Combat/teams.gd").friendly_targets(actor.get_tree()) if hostile else actor.get_tree().get_nodes_in_group("players" if spec.mode=="support" else "enemies")
		for target in targets:
			if not is_instance_valid(target) or target.global_position.distance_to(actor.global_position)>spec.radius:
				continue
			var ray := PhysicsRayQueryParameters2D.create(actor.global_position,target.global_position,2)
			if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			if spec.mode=="support":
				if target.has_method("restore_health"):
					target.restore_health(target.max_health*minf(1.0,spec.damage/100.0))
			else:
				preload("res://Combat/player_damage.gd").hit(actor,target,spec.damage,"magic")
	var effect = load("res://Combat/ultimate_effect.gd").new()
	effect.source_actor=weakref(actor)
	effect.position = actor.position
	effect.radius = spec.radius
	effect.tint = spec.tint
	effect.duration = .35
	if not hostile and spec.pulse_count>0:
		effect.duration = .5*spec.pulse_count+.2
		effect.pulses_left = spec.pulse_count
		effect.pulse_damage = (spec.damage*.22)
	actor.get_parent().add_child(effect)

func _process(delta: float) -> void:
	age += delta
	if pulses_left>0:
		pulse_timer-=delta
		if pulse_timer<=0:
			pulse_timer=.5
			pulses_left-=1
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(global_position)>radius: continue
				var ray := PhysicsRayQueryParameters2D.create(global_position,enemy.global_position,2)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): preload("res://Combat/player_damage.gd").hit(source_actor.get_ref() if source_actor!=null else null,enemy,pulse_damage,"magic")
	if age>=duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t := clampf(age/maxf(duration,.01),0,1)
	draw_circle(Vector2.ZERO,radius,Color(tint,.08 if warning else .15*(1-t)))
	draw_arc(Vector2.ZERO,radius if warning else radius*t,0,TAU,64,Color(tint,.8*(1-t*.5)),2)
	for i in 8:
		var p := Vector2.from_angle(i*TAU/8+age)*radius*(.85 if warning else t)
		draw_line(p-Vector2(4,0),p+Vector2(4,0),tint,2)
