extends RefCounted

const PORTAL_ORDER: Array[StringName] = [
	&"south_west_ruins", &"west_wall", &"west_arch", &"north_west_ruins",
	&"temple", &"east_arch", &"north_east_ruins",
	&"sea_01", &"sea_02", &"sea_03", &"sea_04", &"sea_05",
	&"sea_06", &"sea_07", &"sea_08", &"sea_09", &"sea_10",
	&"ice_01", &"ice_02", &"ice_03", &"ice_04", &"ice_05", &"ice_06", &"ice_07", &"ice_08", &"ice_09", &"ice_10",
	&"music_01", &"music_02", &"music_03", &"music_04", &"music_05", &"music_06", &"music_07", &"music_08", &"music_09", &"music_10",
	&"hell_01", &"hell_02", &"hell_03", &"hell_04", &"hell_05", &"hell_06", &"hell_07", &"hell_08", &"hell_09", &"hell_10",
]

const TOTAL_LEVELS := 47

static func chapter(index: int) -> int:
	if index>=38: return 5
	if index>=28: return 4
	return 3 if index >= 18 else (2 if index >= 8 else 1)

static func number(index: int) -> int:
	if index>=38: return index-37
	if index>=28: return index-27
	return index-17 if index>=18 else (index - 7 if index >= 8 else index)

static func label(index: int) -> String:
	return "%d-%d" % [chapter(index), number(index)]

static func hub_path(chapter_id: int) -> String:
	if chapter_id==5: return "res://Scence/Chapter5.tscn"
	if chapter_id==4: return "res://Scence/Chapter4.tscn"
	if chapter_id==3: return "res://Scence/Chapter3.tscn"
	return "res://Scence/Chapter2.tscn" if chapter_id == 2 else "res://Scence/Main.tscn"

static func map_path(index: int) -> String:
	if index>=28: return "res://"+str(load_level(index).map)
	if index>=18: return "res://Maps/Level3/3-%d.png"%number(index)
	return "res://Maps/Level2/2-%d.png" % number(index) if index >= 8 else "res://Maps/Level1/%s/map.png" % load_level(index).folder


static func load_level(index: int) -> Dictionary:
	var path := "res://Scence/Levels/data/level_%02d.json" % index
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func scene_path(index: int) -> String:
	return "res://Scence/Levels/level_%02d.tscn" % index


static func portal_level(id: StringName) -> int:
	return PORTAL_ORDER.find(id) + 1


static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func all_door_ids(index: int) -> Array[String]:
	var result: Array[String] = []
	var scene: PackedScene = load(scene_path(index))
	if scene == null:
		return result
	var state := scene.get_state()
	for i in state.get_node_count():
		var path := NodePath(str(state.get_node_path(i)).trim_prefix("./"))
		if path.get_name_count() != 2 or path.get_name(0) != &"Doors":
			continue
		for property in state.get_node_property_count(i):
			if state.get_node_property_name(i,property) == &"config":
				var data: Dictionary = state.get_node_property_value(i,property)
				var id := str(data.get("id", ""))
				if not id.is_empty() and id not in result:
					result.append(id)
	return result
