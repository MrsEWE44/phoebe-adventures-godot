extends Area2D

func _ready() -> void:
	body_entered.connect(_entered)

func _entered(body: Node2D) -> void:
	# Respect the owning map's preview mode even when it is not current_scene.
	var map := get_parent()
	while map != null:
		var enabled = map.get("campaign_enabled")
		if enabled != null:
			if enabled == false:
				return
			break
		map = map.get_parent()
	if body.is_in_group("players") and not body.is_dead and not Campaign.transitioning:
		Campaign.travel_to_hub.call_deferred(2)
