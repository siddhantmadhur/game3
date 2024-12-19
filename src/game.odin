package main

import "base:runtime"
import "core:fmt"


import "core:math"
import "core:math/linalg"


draw_game :: proc "c" () {
	context = runtime.default_context()

	// SET PROJECTION AND/OR CAMERA ZOOM
	draw_frame.projection = linalg.matrix_ortho3d_f32((auto_cast global_settings.window_w) * -0.5,  (auto_cast global_settings.window_w) * 0.5, auto_cast global_settings.window_h * -0.5, (auto_cast global_settings.window_h) * 0.5, -1, 1)
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