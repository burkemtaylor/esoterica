package esoterica

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

import "iso"

// TODO: isometric movement

PixelWindowHeight :: 1080
PlayerSpeed :: 250


TileWidth :: 256

DebugAllowed :: true
Debugging := true

out_of_bounds :: proc(player_grid_pos: rl.Vector2, level_width: int) -> bool {
	return(
		!(player_grid_pos.x >= 0 &&
			player_grid_pos.x <= f32(level_width) &&
			player_grid_pos.y >= 0 &&
			player_grid_pos.y <= f32(level_width)) \
	)
}

tile_collision :: proc(player_grid_pos: rl.Vector2, level: Level) -> bool {
	return level.collision_map[cast(int)player_grid_pos.x][cast(int)player_grid_pos.y]
}

generate_collision_map :: proc(level: ^Level) {
	x := make([dynamic][dynamic]bool, len(level.tile_map[0]), context.allocator)
	for _, i in x {
		x[i] = make([dynamic]bool, len(level.tile_map), context.allocator)
	}
	level.collision_map = x


	for i in 0 ..< len(level.tile_map) {
		for j in 0 ..< len(level.tile_map[i]) {
			level.collision_map[i][j] = level.tile_map[i][j] <= 0 || level.foreground_map[i][j] > 0
		}
	}
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
	player_grounded: bool
	player_flip: bool

	rl.InitWindow(1280, 720, "esoterica")
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTargetFPS(500)

	player_run := Animation {
		texture      = rl.LoadTexture("textures/run.png"),
		num_frames   = 5,
		frame_length = 0.1,
		name         = .Run,
	}

	player_idle := Animation {
		texture      = rl.LoadTexture("textures/run.png"),
		num_frames   = 5,
		frame_length = 0.1,
		name         = .Run,
	}

	current_anim := player_idle

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

	generate_collision_map(&level)


	player_pos = iso.grid_to_iso(level.player_pos.x, level.player_pos.y, TileWidth)

	defer {
		delete(level.collision_map)
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
			is_moving: bool

			// X-axis movement
			if rl.IsKeyDown(.A) && !rl.IsKeyDown(.D) {
				player_vel.x = -1
				player_flip = true
			} else if rl.IsKeyDown(.D) && !rl.IsKeyDown(.A) {
				player_vel.x = 1
				player_flip = false
			} else {
				player_vel.x = 0
			}

			// Y-axis movement
			if rl.IsKeyDown(.W) && !rl.IsKeyDown(.S) {
				player_vel.y = -1
			} else if rl.IsKeyDown(.S) && !rl.IsKeyDown(.W) {
				player_vel.y = 1
			} else {
				player_vel.y = 0
			}

			is_moving = (abs(player_vel.x) + abs(player_vel.y)) > 0

			if (current_anim.name != .Run && is_moving) {
				current_anim = player_run
			} else if (current_anim.name != .Idle && !is_moving) {
				current_anim = player_idle
			}

			player_vel *= PlayerSpeed / (abs(player_vel.x) + abs(player_vel.y))

			// Update player position
			temp_player_pos := player_pos + player_vel * rl.GetFrameTime()
			grid_position := iso.iso_to_grid(temp_player_pos.x, temp_player_pos.y, TileWidth)


			if !out_of_bounds(grid_position, len(level.tile_map)) &&
			   !tile_collision(grid_position, level) {
				player_pos = temp_player_pos
			}

			animation_update(&current_anim)

		}

		screen_height := f32(rl.GetScreenHeight())

		camera := rl.Camera2D {
			offset = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2},
			target = player_pos,
			zoom   = screen_height / PixelWindowHeight,
		}

		rl.BeginMode2D(camera)

		draw_bg(level)
		draw_fg(level, player_pos, current_anim, player_flip, Debugging)

		// draw_player(player_pos)

		if (rl.IsKeyPressed(.P) && Debugging) {
			fmt.printf("Player pos: %v\n", player_pos)
			fmt.printf(
				"Player grid pos: %v\n",
				iso.iso_to_grid(player_pos.x, player_pos.y, TileWidth),
			)

		}


		rl.EndDrawing()
	}

	rl.CloseWindow()

	free_all(context.temp_allocator)

	unload_tiles()
}
