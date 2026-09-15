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

draw_fg :: proc(level: Level, player_pos: rl.Vector2, a: Animation, flip: bool, debug: bool) {
	for i in 0 ..< len(level.tile_map) {
		for j in 0 ..< len(level.tile_map[i]) {
			player_grid_pos := iso.iso_to_grid(player_pos.x, player_pos.y, TileWidth)

			if (cast(int)player_grid_pos.x == i && cast(int)player_grid_pos.y == j) {
				draw_player(player_pos, a, flip, debug)
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

draw_player :: proc(pos: rl.Vector2, a: Animation, flip: bool, debug: bool) {
	current_anim_width := f32(a.texture.width)
	current_anim_height := f32(a.texture.height)

	player_run_source_frame_x := f32(a.current_frame) * current_anim_width

	source := rl.Rectangle {
		x      = player_run_source_frame_x / f32(a.num_frames),
		y      = 0,
		width  = current_anim_width / f32(a.num_frames),
		height = current_anim_height,
	}

	if flip {
		source.width *= -1
	}

	dest := rl.Rectangle {
		x      = pos.x,
		y      = pos.y,
		width  = current_anim_width / f32(a.num_frames),
		height = current_anim_height,
	}

	rl.DrawTexturePro(a.texture, source, dest, {dest.width / 2, dest.height}, 0, rl.WHITE)

	if debug {
		rl.DrawCircleV(pos, 10, rl.RED)
	}
}
