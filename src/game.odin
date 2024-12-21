package main


import "base:runtime"
import "core:fmt"


import "core:math"
import "core:math/linalg"

import sapp "../sokol-odin/sokol/app"


tower_defense_bg_color :: 0xcebdb0ff


color_text :: 0x2C2851FF

FPS :: struct {
	value:        f32,
	last_updated: f64,
}

Screens :: enum {
	main_menu,
	game,
}

game: struct {
	fps:           FPS,
	debug: bool,
	screen: Screens,
	mouse_pos_screen: v2,
	mouse_pos: v2,
	camera_pos: v2,
	camera_zoom: f32,
}


current_event : enum {
	none,
	create_new_game,
}


// Runs once
tower_game_init :: proc() {
	current_event = .none
	game.screen = .main_menu
	game.fps.value = 0
	game.fps.last_updated = elapsed_t
	game.debug = ODIN_DEBUG
	game.camera_pos = v2{0, 0}
	game.camera_zoom = 1

}


// Runs every frame
tower_game_render :: proc "c" () {
	context = runtime.default_context()
	sapp.set_mouse_cursor(.DEFAULT)
	current_event = .none


	// SET PROJECTION AND/OR CAMERA ZOOM
	draw_frame.projection = linalg.matrix_ortho3d_f32(
		(auto_cast global.window_w) * -0.5,
		(auto_cast global.window_w) * 0.5,
		auto_cast global.window_h * -0.5,
		(auto_cast global.window_h) * 0.5,
		-1,
		1,
	)
	draw_frame.camera_xform = Matrix4(1)
	draw_frame.camera_xform *= auto_cast game.camera_zoom 

	// :FPS
	if (elapsed_t - game.fps.last_updated >= 1) {
		game.fps.last_updated = elapsed_t
		game.fps.value = 1 / auto_cast delta_t
	}


	// Render stuff
	switch game.screen {
		case .main_menu:
			cursor := v2{0, auto_cast global.window_h / 2}
			cursor.y -= 100
			draw_text(cursor, "Tower Defense", 2, .top_center, hex_to_rgba(color_text))
			cursor.y -= 200
			size := draw_text(cursor, "New Game", 1.2, .top_center, hex_to_rgba(color_text))

			box := cursor 
			box -= size * scale_from_pivot(.top_center)
			if game.debug {
				draw_rect(box, size, v4{COLOR_RED.x, COLOR_RED.y, COLOR_RED.z, 0.5})
			}

			if is_within_square(game.mouse_pos, box, size) {
				sapp.set_mouse_cursor(.POINTING_HAND)
				current_event = .create_new_game
			}

			//draw_rect(cursor + pivot_offset, pos, v4{COLOR_RED.x, COLOR_RED.y, COLOR_RED.z, 0.5})

		case .game:
			draw_rect(v2{0, 0}, v2{128, 64}, COLOR_WHITE, img_id=Image_Id.tile)
	}


	// Render debug stats
	if game.debug {
		tl := v2{auto_cast global.window_w / -2.0, auto_cast global.window_h / 2.0}
		tl += v2{10, -10}
		draw_text(
			tl,
			fmt.tprintf("FPS: %.0f", game.fps.value),
			pivot = .top_left,
			color = hex_to_rgba(color_text),
		)
	}
}

tower_game_event :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()

	#partial switch event.type {
	case .KEY_DOWN:
		#partial switch event.key_code {
		case .ESCAPE:
			fmt.printfln("Quitting game...")
			sapp.quit()
		case .F3:
			game.debug = !game.debug
		}
		case .MOUSE_MOVE:
			game.mouse_pos_screen = v2{event.mouse_x, event.mouse_y}
			camera_offset := game.camera_pos - (v2{f32(global.window_w), f32(global.window_h)} * 0.5 )

			game.mouse_pos = game.mouse_pos_screen + camera_offset 
			game.mouse_pos.y *= -1

			game.mouse_pos /= game.camera_zoom

		case .MOUSE_DOWN:
			switch current_event {
				case .create_new_game:
					fmt.printfln("Creating new game...")
					game.screen = .game
				case .none:

			}
	}

}
