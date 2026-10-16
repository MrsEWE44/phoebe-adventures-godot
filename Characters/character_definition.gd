class_name CharacterDefinition
extends Resource
## All differences between playable characters live in data, not movement code.
@export var character_id := "new_character"
@export var display_name := "新角色"
@export_enum("玩家", "敌人", "NPC（中立）", "BOSS") var character_type := 0
@export_range(1,100000) var max_health := 100
@export_range(0,1000) var max_energy := 200
@export var movement_speed := 135.0
## Innate character damage bonus, independent of weapon upgrades and home terrain.
@export_range(0.1,10.0,.05) var damage_multiplier := 1.0
@export var hurtbox_size := Vector2(22,32)
@export var hurtbox_offset := Vector2(0,-15)
## Authored rectangles per animation frame, in character-local coordinates.
@export var hurtbox_frames: Dictionary = {}
@export var foot_size := Vector2(14,8)
@export var foot_offset := Vector2(0,-2)
@export_enum("land","ocean","sky","snow","swamp","hell") var home_biome := "land"
@export var home_damage_multiplier := 1.20
@export var home_skill_multiplier := 1.30
@export var home_speed_multiplier := 1.12
@export var home_attack_speed_multiplier := 1.12
@export var home_defense := 2
@export_enum("melee","ranged","charger","orbit") var behavior := "melee"
@export_range(1,5) var attack_projectiles := 1
@export var body_tint := Color.WHITE
@export var default_weapon := "fists"
## Empty permits every weapon; otherwise only these IDs may be used.
@export var allowed_weapons: Array[String] = []
@export var allowed_chapters: Array[int] = []
@export var ranged_attack := false
@export var aquatic := false
@export var faces_right := false
@export var skill_weapon := ""
@export var ultimate: Resource
@export var ultimate_animations: SpriteFrames
@export var ultimate_scale := Vector2(.12,.12)
@export var ultimate_offset := Vector2(0,-23)
@export var animations: SpriteFrames
@export var reaction_animations: SpriteFrames
@export var reaction_scale := Vector2(.12,.12)
@export var reaction_offset := Vector2(0,-20)
@export var voice_profile: Resource
@export var sprite_material: Material
@export var sprite_scale := Vector2(.15498155,.15498155)
@export var sprite_offset := Vector2(-1,-12)
@export_range(1,12) var skill_projectiles := 3
