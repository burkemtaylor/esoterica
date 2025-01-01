package esoterica

import rl "vendor:raylib"

@(private = "file")
tile_map: [Tile]rl.Texture2D = #partial {
	.Empty = {id = 0},
}

Tile :: enum u8 {
	Empty,
	Wood,
	Moss,
	Grass,
}

TilePath := [Tile]cstring {
	.Empty = "",
	.Wood  = "textures/wood1.png",
	.Moss  = "textures/moss1.png",
	.Grass = "Grass",
}

/**
 * Load a tile from a file path.
 */
load_tile :: proc(tile_name: Tile, file_path: cstring) -> rl.Texture2D {
	if tile_map[tile_name].id <= 0 {
		tile_map[tile_name] = rl.LoadTexture(file_path)
	}

	return tile_map[tile_name]
}

unload_tile :: proc(tile_name: Tile) {
	if tile_map[tile_name].id > 0 {
		rl.UnloadTexture(tile_map[tile_name])
		tile_map[tile_name] = {
			id = 0,
		}
	}
}

unload_tiles :: proc() {
	for k, i in tile_map {
		if k.id > 0 {
			rl.UnloadTexture(k)
			tile_map[i] = {
				id = 0,
			}
		}
	}
}
