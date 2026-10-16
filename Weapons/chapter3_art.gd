extends RefCounted
static func texture(index: int) -> Texture2D:
	return load("res://Art/Chapter3/item_%d.tres"%index)
