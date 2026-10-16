@tool
extends Node

# Godot 4.7 helper for level_03_mirror_sanctum / 镜像祭殿
# Creates a TileSetAtlasSource from tileset_32x32.png and places cells in a TileMapLayer.
# It does NOT create Sprite2D proxy tiles.

const TILE_SIZE := 32
const ATLAS_COLS := 40

func build(target: TileMapLayer, atlas_texture: Texture2D, grid: Array) -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = atlas_texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(atlas, 0)

	var used := {}
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var idx: int = int(grid[y][x])
			if idx < 0:
				continue
			if not used.has(idx):
				var ac := Vector2i(idx % ATLAS_COLS, idx / ATLAS_COLS)
				atlas.create_tile(ac)
				used[idx] = true

	target.tile_set = tile_set
	target.clear()
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var idx: int = int(grid[y][x])
			if idx < 0:
				continue
			var ac := Vector2i(idx % ATLAS_COLS, idx / ATLAS_COLS)
			target.set_cell(Vector2i(x, y), 0, ac, 0)
