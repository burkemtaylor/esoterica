package esoterica

import rl "vendor:raylib"

import "iso"

draw_grid_texture :: proc(texture: rl.Texture2D, x: int, y: int) {
	x_screen := i32(x - y) * TileWidth / 2
	y_screen := i32(x + y) * TileWidth / 4

	dest := rl.Rectangle {
		x      = f32(x_screen),
		y      = f32(y_screen),
		width  = f32(texture.width),
		height = f32(texture.height),
	}

	rl.DrawTexturePro(
		texture,
		{0, 0, f32(texture.width), f32(texture.height)},
		dest,
		{0, f32(texture.height - TileWidth)},
		0,
		rl.WHITE,
	)
}

draw_bg :: proc(level: Level) {
	for i in 0 ..< len(level.tile_map) {
		for j in 0 ..< len(level.tile_map[i]) {

			if (level.tile_map[i][j] > 0) {
				texture := load_tile(
					cast(Tile)level.tile_map[i][j],
					TilePath[cast(Tile)level.tile_map[i][j]],
				)
				draw_grid_texture(texture, i, j)
			}
		}
	}
}

draw_fg :: proc(level: Level, player_pos: rl.Vector2) {
	for i in 0 ..< len(level.tile_map) {
		for j in 0 ..< len(level.tile_map[i]) {
			player_grid_pos := iso.iso_to_grid(player_pos.x, player_pos.y, TileWidth)

			if (cast(int)player_grid_pos.x == i && cast(int)player_grid_pos.y == j) {
				draw_player(player_pos)
			}

			if (level.foreground_map[i][j] > 0) {
				texture := load_fg(
					cast(Foreground)level.foreground_map[i][j],
					ForegroundPath[cast(Foreground)level.foreground_map[i][j]],
				)
				draw_grid_texture(texture, i, j)
			}


		}
	}
}

draw_player :: proc(pos: rl.Vector2) {
	rl.DrawCircleV(pos, 10, rl.RED)
}
