extends Node2D
## Common aim, orbit, depth ordering, recoil, muzzle and swing presentation.
var hero: CharacterBody2D
var definition: Resource
var sprite: Sprite2D
var aim := Vector2.RIGHT
var recoil_left := 0.0
var swing_left := 0.0
var flash_left := 0.0
var aim_at_mouse := true
var grip_offset := Vector2(0,-7)

func _ready() -> void:
	hero = get_parent()
	name = "WeaponMount"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "WeaponSprite"
	add_child(sprite)
	equip(preload("res://Weapons/weapon_registry.gd").get_weapon("fists"))

func equip(weapon: Resource) -> void:
	if weapon == definition:
		return
	definition = weapon
	sprite.texture = definition.texture
	recoil_left = 0
	swing_left = 0
	flash_left = 0
	if sprite.texture != null:
		sprite.scale = Vector2.ONE * definition.display_width / sprite.texture.get_width()
		sprite.position = Vector2(definition.display_width*.3,0)

func _process(delta: float) -> void:
	recoil_left = maxf(0,recoil_left-delta)
	swing_left = maxf(0,swing_left-delta)
	flash_left = maxf(0,flash_left-delta)
	update_aim(hero.global_position.direction_to(get_global_mouse_position()) if aim_at_mouse else hero.facing)
	queue_redraw()

func update_aim(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		aim = direction.normalized()
	visible = not hero.is_dead and definition.texture != null and not is_instance_valid(hero.get("basketball_skill"))
	position = grip_offset+aim*(definition.orbit_radius-definition.recoil*recoil_left/.12)
	rotation = aim.angle()
	if swing_left > 0:
		rotation += lerpf(-1.05,1.05,1-swing_left/.18)
	sprite.flip_v = aim.x < 0
	# Keep the entire held weapon readable, including when aiming above the head.
	z_index = 3

func fire(direction: Vector2, melee: bool) -> void:
	recoil_left = .12
	swing_left = .18 if melee else 0.0
	flash_left = 0.0 if melee else .07
	update_aim(direction)

func muzzle_position() -> Vector2:
	return to_global(Vector2(definition.display_width*.8,0))

func _draw() -> void:
	if flash_left > 0 and visible:
		var p := Vector2(definition.display_width*.8,0)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-2,-4),p+Vector2(9,0),p+Vector2(-2,4),p]),Color("fff0ad"))
