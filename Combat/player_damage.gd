extends RefCounted
## Resolve the temporary player buff at impact, not at projectile launch.
static func hit(source: Node, target: Node, amount: float, type: String) -> void:
	if not is_instance_valid(target): return
	if is_instance_valid(source) and source.has_method("damage_overdrive_active") and source.damage_overdrive_active() and target.is_in_group("enemies"):
		amount=999.0
		type="true"
	if is_instance_valid(source) and source.is_in_group("players") and target.is_in_group("enemies"):
		var campaign: Node=source.get_node("/root/Campaign")
		if source.current_character in ["phoebe","nuonuo","doro","gugu"] and campaign.friendship_active():
			if target.definition.character_id.begins_with("naiwa") and target.definition.character_id.ends_with("full"):
				amount=maxf(amount,target.max_health*.70)
				type="true"
	target.take_damage(amount,type)
