package esoterica

import rl "vendor:raylib"

Animation_Name :: enum {
	Idle,
	Run,
}

Animation :: struct {
	texture:       rl.Texture2D,
	num_frames:    int,
	frame_timer:   f32,
	current_frame: int,
	frame_length:  f32,
	name:          Animation_Name,
}

animation_update :: proc(a: ^Animation) {
	a.frame_timer += rl.GetFrameTime()

	if a.frame_timer > a.frame_length {
		a.current_frame += 1
		a.frame_timer = 0

		if a.current_frame >= a.num_frames {
			a.current_frame = 0
		}
	}
}
