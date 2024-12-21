package main

import "base:runtime"
import "core:fmt"


import "core:math"
import "core:math/linalg"

import sapp "../sokol-odin/sokol/app"


// EXAMPLE - HOUSE
// Test to see multiple images and text rendering

example_house_bg_color :: 0x443355FF


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
				fmt.printfln("Quitting game...")
					sapp.quit()
			}
		case .MOUSE_MOVE:
			fmt.printfln("Mouse move: (%.01f, %.01f)", event.mouse_x, event.mouse_y)

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

PongBall :: struct {
	position: Vector2,
	direction: Vector2,
	speed: f32,
}

pong_state : struct {
	player1: PongPlayer,
	ball: PongBall,
}

example_pong_bg_color :: 0x0

example_pong_event :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()

	speed: f32 = 2.0

	#partial switch event.type {
		case .KEY_DOWN:
			if event.key_code == sapp.Keycode.UP {
				pong_state.player1.yaxis += speed * auto_cast delta_t
				if (pong_state.player1.yaxis > 1.0) {
					pong_state.player1.yaxis = 1 
				}
			} else if event.key_code == sapp.Keycode.DOWN {
				pong_state.player1.yaxis -= speed * auto_cast delta_t
				if (pong_state.player1.yaxis < 0.0) {
					pong_state.player1.yaxis = 0 
				}

			}
	}
}

example_pong_init :: proc () {
	//pong_state.player1 = PongPlayer{yaxis=0.5}	
	pong_state.player1.yaxis = 0.5 

	pong_state.ball.position = v2 {0, 0}
	pong_state.ball.direction = v2 {-1, 0.2}
	pong_state.ball.speed = 1.0 

}

example_pong_render :: proc "c" () {
	context = runtime.default_context()

	draw_frame.projection = linalg.matrix_ortho3d_f32((auto_cast global.window_w) * -0.5,  (auto_cast global.window_w) * 0.5, auto_cast global.window_h * -0.5, (auto_cast global.window_h) * 0.5, -1, 1)
	draw_frame.camera_xform = Matrix4(1)
	//draw_frame.camera_xform *= 0.1

	// :Player movement

	player_position := v2{-(auto_cast global.window_w / 2) +20, ((pong_state.player1.yaxis - 0.5) * (auto_cast global.window_h - 150)) + 50}

	// :Ball movement
	pong_state.ball.position = pong_state.ball.position + pong_state.ball.direction


	// :FPS
	fps := 1 / delta_t 
	tl := v2{auto_cast global.window_w / -2.0, auto_cast global.window_h / 2}
	tl.x += 10
	tl.y -= 10



	// :Render
	draw_text(tl, fmt.tprintf("FPS: %0.0f", fps), 1.0, .top_left)

	draw_rect(player_position, v2{20, 100}, COLOR_WHITE)

	draw_rect(pong_state.ball.position, v2{20, 20})

}