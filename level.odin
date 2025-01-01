package esoterica

import rl "vendor:raylib"

Level :: struct {
	player_pos:     rl.Vector2,
	tile_map:       [][]int,
	foreground_map: [][]int,
	collision_map:  [dynamic][dynamic]bool,
}
