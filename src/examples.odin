package main

import "base:runtime"
import "core:fmt"


import "core:math"
import "core:math/linalg"

import sapp "../sokol-odin/sokol/app"


// EXAMPLE - HOUSE
// Test to see multiple images and text rendering


example_house_event :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()

	#partial switch event.type {
		case .KEY_DOWN:
			#partial switch event.key_code {
				case .SPACE: 
					if event.key_repeat {
						fmt.printfln("Continuing Press...")
					} else {
						fmt.printfln("Spacebar just pressed!")
					}
				case .ESCAPE:
					sapp.quit()
			}

	}

}
example_house_init :: proc () {}

example_house_render :: proc "c" () {
	context = runtime.default_context()

	// SET PROJECTION AND/OR CAMERA ZOOM
	draw_frame.projection = linalg.matrix_ortho3d_f32((auto_cast global.window_w) * -0.5,  (auto_cast global.window_w) * 0.5, auto_cast global.window_h * -0.5, (auto_cast global.window_h) * 0.5, -1, 1)
	draw_frame.camera_xform = Matrix4(1)
	//draw_frame.camera_xform *= 0.1

	position := Vector2{-radius, -radius}
	position.x = (auto_cast math.sin(elapsed_t)) * radius
	position.y = auto_cast math.cos(elapsed_t) * radius

	position2 := Vector2{-radius, -radius}
	position2.x = (auto_cast math.sin(elapsed_t-math.PI)) * radius
	position2.y = (auto_cast math.cos(elapsed_t-math.PI)) * radius

	image_height:f32 = 120

	draw_rect(v2{position.x-(image_height / 2.0), position.y+(image_height / 2.0)}, v2{image_height, image_height}, COLOR_RED, img_id=.housemd)
	
	draw_rect(v2{position2.x-(image_height / 2.0), position2.y+(image_height / 2.0)}, v2{image_height, image_height}, COLOR_WHITE, img_id=.wilsonmd)

	draw_text(v2{0, 0}, "Hello, World")

}



// EXAMPLE - PONG
// Test to see game state / character movement

PongPlayer :: struct {
	yaxis: f32 // 0.0 -> 1.0 on the vertical range
}

pong_game : struct {
	player1: PongPlayer
}


example_pong_event :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()

	speed: f32 = 2.0

	#partial switch event.type {
		case .KEY_DOWN:
			if event.key_code == sapp.Keycode.UP {
				pong_game.player1.yaxis += speed * auto_cast delta_t
				if (pong_game.player1.yaxis > 1.0) {
					pong_game.player1.yaxis = 1 
				}
			} else if event.key_code == sapp.Keycode.DOWN {
				pong_game.player1.yaxis -= speed * auto_cast delta_t
				if (pong_game.player1.yaxis < 0.0) {
					pong_game.player1.yaxis = 0 
				}

			}
	}
}

example_pong_init :: proc () {
	//pong_game.player1 = PongPlayer{yaxis=0.5}	
	pong_game.player1.yaxis = 0.5 

}

example_pong_render :: proc "c" () {
	context = runtime.default_context()

	draw_frame.projection = linalg.matrix_ortho3d_f32((auto_cast global.window_w) * -0.5,  (auto_cast global.window_w) * 0.5, auto_cast global.window_h * -0.5, (auto_cast global.window_h) * 0.5, -1, 1)
	draw_frame.camera_xform = Matrix4(1)
	//draw_frame.camera_xform *= 0.1

	draw_rect(v2{-(auto_cast global.window_w / 2) +20, ((pong_game.player1.yaxis - 0.5) * (auto_cast global.window_h - 150)) + 50}, v2{20, 100}, COLOR_WHITE)


}