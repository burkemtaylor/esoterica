package iso

import rl "vendor:raylib"

grid_to_iso :: proc(x_grid: f32, y_grid: f32, tile_width: int) -> rl.Vector2 {
	return {(x_grid - y_grid) * f32(tile_width) / 2, (x_grid + y_grid) * f32(tile_width) / 4}
}

iso_to_grid :: proc(x_iso: f32, y_iso: f32, tile_width: int) -> rl.Vector2 {
	y_grid := (y_iso * 4 / f32(tile_width) - x_iso * 2 / f32(tile_width)) / 2
	x_grid := y_grid + x_iso * 2 / f32(tile_width)

	// Offsets because { 0, 0 } is by default the center of the tile 
	// rather than the top left of each tile
	return {x_grid - 0.5, y_grid + 0.5}
}
