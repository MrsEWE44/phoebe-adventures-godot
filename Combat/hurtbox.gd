extends Area2D
## Projectile target separate from the small foot collider used to navigate the map.
var actor: CharacterBody2D
func take_damage(amount: float, type: String = "physical") -> void:
	if is_instance_valid(actor):
		actor.take_damage(amount,type)
