package esoterica

import rl "vendor:raylib"

Level :: struct {
	player_pos: rl.Vector2,
	tile_map:   [][]int,
}
