extends RefCounted
static func apply(target: Node2D, effect: String, power: float, source: Node=null) -> void:
	if effect.is_empty() or not is_instance_valid(target) or not target.has_method("apply_status") or target.is_dead: return
	var boss: bool=target.character_type==3
	match effect:
		"silence":
			if target.has_method("silence_sonic"): target.silence_sonic(2.5)
		"frost": target.apply_status(4.0,.25 if boss else .85)
		"burn": target.apply_status(0,0,power*.22,4.0)
		"shock":
			target.apply_status(1.4,.12 if boss else .35)
			var candidates: Array=target.get_tree().get_nodes_in_group("enemies")
			candidates.sort_custom(func(a,b): return a.global_position.distance_squared_to(target.global_position)<b.global_position.distance_squared_to(target.global_position))
			var count:=0
			for other in candidates:
				if other==target or other.is_dead or other.global_position.distance_to(target.global_position)>95: continue
				if not target.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(target.combat_center(),other.combat_center(),2)).is_empty(): continue
				preload("res://Combat/player_damage.gd").hit(source,other,power*.45,"magic")
				var arc:=Line2D.new()
				arc.points=PackedVector2Array([target.combat_center(),other.combat_center()])
				arc.width=2
				arc.default_color=Color("89ddff")
				target.get_parent().add_child(arc)
				var tween:=arc.create_tween()
				tween.tween_property(arc,"modulate:a",0.0,.2)
				tween.tween_callback(arc.queue_free)
				count+=1
				if count==2: break
