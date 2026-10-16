extends Node
## Context-driven feedback. Emotions are gameplay events, never a character interaction menu.
var actor: Node2D
var elapsed := 0.0
var next_line := 1.0
var recent_hits: Array[float] = []
var attack_count := 0
var kills := 0
var visited: Dictionary = {}
var pending := ""
var scan_timer := 0.0

func _ready() -> void:
	actor = get_parent()

func _process(delta: float) -> void:
	if actor.is_dead or get_tree().paused:
		return
	elapsed += delta
	scan_timer -= delta
	if not pending.is_empty() and elapsed >= next_line:
		if actor.voice.play_event(pending):
			pending = ""
			next_line = elapsed + (6.0 if actor.current_character=="phoebe" else 10.0)
	if scan_timer > 0:
		return
	scan_timer = .7
	var close := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_dead and enemy.global_position.distance_to(actor.global_position)<170:
			close += 1
			if enemy.character_type==3:
				enter_area("boss_%s" % enemy.get_instance_id(),true)
	if close>=3 and elapsed>next_line:
		request("afraid")

func request(event: String) -> void:
	if actor.is_dead:
		return
	if pending.is_empty() or int(actor.voice.PRIORITIES.get(event,0))>int(actor.voice.PRIORITIES.get(pending,0)):
		pending = event

func enter_area(id: String, boss := false) -> void:
	if visited.has(id):
		return
	visited[id] = true
	request("terrified" if boss else "afraid")

func attacked() -> void:
	attack_count += 1
	if attack_count%4==0 and elapsed>=next_line:
		request("battle")

func hurt() -> void:
	recent_hits.append(elapsed)
	while not recent_hits.is_empty() and elapsed-recent_hits[0]>6:
		recent_hits.pop_front()
	if recent_hits.size()>=3:
		recent_hits.clear()
		pending = "angry"
		next_line = minf(next_line,elapsed+.2)
	elif actor.health<=actor.max_health*.25:
		request("afraid")
	else:
		request("hurt")

func defeated_enemy() -> void:
	kills += 1
	if kills%2==0:
		request("proud")

func reset_character() -> void:
	pending = ""
	recent_hits.clear()
	attack_count = 0
	next_line = elapsed+2
