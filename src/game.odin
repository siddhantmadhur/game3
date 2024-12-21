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
	display_stats: bool,
	screen: Screens,
}



// Runs once
tower_game_init :: proc() {
	game.screen = .main_menu
	game.fps.value = 0
	game.fps.last_updated = elapsed_t
	when ODIN_DEBUG {
		game.display_stats = true
	} else {
		game.display_stats = false
	}

}


// Runs every frame
tower_game_render :: proc "c" () {
	context = runtime.default_context()


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
	//draw_frame.camera_xform *= 0.1

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
		case .game:
	}


	// Render debug stats
	if game.display_stats {
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
			game.display_stats = !game.display_stats
		}

	}

}
