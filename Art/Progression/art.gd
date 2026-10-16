extends RefCounted
static func icon(index: int) -> Texture2D:
	return load("res://Art/Progression/item_%d.tres"%index)
