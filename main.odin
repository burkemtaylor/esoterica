package esoterica

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

PixelWindowHeight :: 1080
PlayerSpeed :: 200

TileHeight :: 128
TileWidth :: 256

DebugAllowed :: true
Debugging := true

grid_to_iso :: proc(x_grid: f32, y_grid: f32) -> rl.Vector2 {
	return {(x_grid - y_grid) * TileWidth / 2, (x_grid + y_grid) * TileHeight / 3}
}

iso_to_grid :: proc(x_iso: f32, y_iso: f32) -> rl.Vector2 {
	y_grid := (y_iso * 3 / TileHeight - x_iso * 2 / TileWidth) / 2
	x_grid := y_grid + x_iso * 2 / TileWidth
	return {x_grid, y_grid}
}

in_bounds :: proc(player_world_pos: rl.Vector2) -> bool {
	grid_position := iso_to_grid(player_world_pos.x, player_world_pos.y)

	return(
		grid_position.x >= 0.5 &&
		grid_position.x <= 8.5 &&
		grid_position.y >= -0.5 &&
		grid_position.y <= 7.5 \
	)
}

draw_tile :: proc(tile_id: int, x: int, y: int) {
	if tile_id <= 0 {
		return
	}

	texture := load_tile(cast(Tile)tile_id, TilePath[cast(Tile)tile_id])

	x_screen := i32(x - y) * texture.width / 2
	y_screen := i32(x + y) * texture.height / 3

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
		{0, 0},
		0,
		rl.WHITE,
	)
}

draw_map :: proc(level: Level) {
	for i in 0 ..< len(level.tile_map) {
		for j in 0 ..< len(level.tile_map[i]) {
			draw_tile(level.tile_map[i][j], i, j)
		}
	}
}

draw_player :: proc(pos: rl.Vector2) {
	rl.DrawCircleV(pos, 10, rl.RED)
}

main :: proc() {
	{ 	// Set up memory tracking
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			for _, entry in track.allocation_map {
				fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
			}

			for entry in track.bad_free_array {
				fmt.eprintf("Bad free at %v\n", entry.location)
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

	player_pos: rl.Vector2
	player_vel: rl.Vector2

	rl.InitWindow(1280, 720, "esoterica")
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTargetFPS(500)

	background := rl.LoadTexture("assets/DarkAbstractBackgrounds_016.png")

	level: Level

	if level_data, ok := os.read_entire_file(
		"levels/level.json",
		allocator = context.temp_allocator,
	); ok {
		if json.unmarshal(level_data, &level) != nil {
			fmt.eprintf("Failed to unmarshal level data\n")
			return
		}
	}

	player_pos = grid_to_iso(level.player_pos.x, level.player_pos.y)

	defer {
		for i in 0 ..< len(level.tile_map) {
			delete(level.tile_map[i])
		}
		delete(level.tile_map)
	}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		rl.DrawTexture(background, 0, 0, {15, 15, 15, 240})

		if rl.IsKeyPressed(.F1) {
			Debugging = !Debugging
		}

		{ 	// Player Movement 
			// X-axis movement
			if rl.IsKeyDown(.A) && !rl.IsKeyDown(.D) {
				player_vel.x = -PlayerSpeed
			} else if rl.IsKeyDown(.D) && !rl.IsKeyDown(.A) {
				player_vel.x = PlayerSpeed
			} else {
				player_vel.x = 0
			}

			// Y-axis movement
			if rl.IsKeyDown(.W) && !rl.IsKeyDown(.S) {
				player_vel.y = -PlayerSpeed
			} else if rl.IsKeyDown(.S) && !rl.IsKeyDown(.W) {
				player_vel.y = PlayerSpeed
			} else {
				player_vel.y = 0
			}

			// Update player position
			temp_player_pos := player_pos + player_vel * rl.GetFrameTime()

			if in_bounds(temp_player_pos) {
				player_pos = temp_player_pos
			}

		}

		screen_height := f32(rl.GetScreenHeight())

		camera := rl.Camera2D {
			offset = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2},
			target = player_pos,
			zoom   = screen_height / PixelWindowHeight,
		}

		rl.BeginMode2D(camera)

		draw_map(level)

		if (rl.IsKeyPressed(.P) && Debugging) {
			fmt.printf("Player pos: %v\n", player_pos)
			fmt.printf("Player grid pos: %v\n", iso_to_grid(player_pos.x, player_pos.y))

		}

		draw_player(player_pos)


		rl.EndDrawing()
	}

	rl.CloseWindow()

	free_all(context.temp_allocator)

	unload_tiles()
}
