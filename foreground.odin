package esoterica

import rl "vendor:raylib"

@(private = "file")
fg_map: [Foreground]rl.Texture2D = #partial {
	.Empty = {id = 0},
}

Foreground :: enum u8 {
	Empty,
	Bush1,
	Bush2,
}

ForegroundPath := [Foreground]cstring {
	.Empty = "",
	.Bush1 = "textures/bush1.png",
	.Bush2 = "textures/bush2.png",
}

/**
 * Load a tile from a file path.
 */
load_fg :: proc(fg_name: Foreground, file_path: cstring) -> rl.Texture2D {
	if fg_map[fg_name].id <= 0 {
		fg_map[fg_name] = rl.LoadTexture(file_path)
	}

	return fg_map[fg_name]
}

unload_fg :: proc(fg_name: Foreground) {
	if fg_map[fg_name].id > 0 {
		rl.UnloadTexture(fg_map[fg_name])
		fg_map[fg_name] = {
			id = 0,
		}
	}
}

unload_all_fg :: proc() {
	for k, i in fg_map {
		if k.id > 0 {
			rl.UnloadTexture(k)
			fg_map[i] = {
				id = 0,
			}
		}
	}
}
