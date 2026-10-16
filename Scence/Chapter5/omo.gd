extends "res://Scence/Chapter4/ally.gd"
var spin_clock:=0.0
func _ready() -> void:
	role="omo"
	super._ready()
	animated_sprite.sprite_frames=preload("res://Art/Chapter5/omo_spin.tres")
	animated_sprite.play("spin")
func take_damage(_amount: float,_type: String="physical") -> void: pass
func _physics_process(delta: float) -> void:
	if level.state.finished or level.state.get("battle_done",false): return
	var targets: Array=level.living()
	if targets.is_empty(): return
	var target: Node2D=targets[0]
	path_clock-=delta
	if path_clock<=0: path=level.geometry.path(position,target.position);path_clock=.4
	while not path.is_empty() and position.distance_to(path[0])<12: path.remove_at(0)
	direction=position.direction_to(path[0]) if not path.is_empty() else Vector2.ZERO
	velocity=direction*310
	move_and_slide()
	animated_sprite.play("spin")
	spin_clock-=delta
	if spin_clock<=0:
		spin_clock=.45
		for enemy in targets:
			if enemy.position.distance_to(position)<200: enemy.take_damage(enemy.max_health*2,"true")
		var wave=preload("res://Scence/Chapter4/sound_wave.gd").new()
		wave.position=position
		wave.radius=200
		wave.tint=Color("96ddff")
		level.add_child(wave)
