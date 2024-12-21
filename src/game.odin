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
	fps:              FPS,
	debug:            bool,
	screen:           Screens,
	mouse_pos_screen: v2,
	mouse_pos:        v2,
	camera_pos:       v2,
	camera_zoom:      f32,
}


current_event: enum {
	none,
	create_new_game,
}


// Runs once
tower_game_init :: proc() {
	current_event = .none
	game.screen = .main_menu

	when ODIN_DEBUG {
		// TODO: Remove this  
		game.screen = .game
	}

	game.fps.value = 0
	game.fps.last_updated = elapsed_t
	game.debug = ODIN_DEBUG
	game.camera_pos = v2{0, 0}
	game.camera_zoom = 1

}

GridPos :: struct {
	x: int,
	y: int,
}

gp :: GridPos

coord_to_grid :: proc(coord: Vector2) -> GridPos {
	a := coord.x
	b := coord.y
	//a += (GRID_TILE.x / 2.0f);
	//b += (GRID_TILE.y / 2.0f);
	//a = (floor(a / GRID_TILE.x)) * GRID_TILE.x;
	//b = (floor(b / GRID_TILE.y)) * GRID_TILE.y;

	x := (-b / GRID_TILE.y) + (a / GRID_TILE.x) + (GRID_W / 4.0)

	y := ((2 * a) / GRID_TILE.x) + (GRID_W) - x

	return gp{int(math.floor(x))+2, int(math.floor(y ) -2)}
}

grid_to_coord :: proc(grid: GridPos) -> Vector2 {
	x := grid.x
	y := grid.y
	x_coord := f32(GRID_TILE.x / 2.0) * f32(f32(x + y) - f32(GRID_W))
	y_coord := f32(GRID_TILE.y / 2.0) * f32(y - x)

	y_coord -= GRID_TILE.y / 2

	// Check if coord-to-grid works
	//log("x: %d->%f->%d", x, x_coord, coord_to_grid(v2(x_coord, y_coord)).x); 
	//log("y: %d->%f->%d", y, y_coord, coord_to_grid(v2(x_coord, y_coord)).y); 


	// Print out debug coords
	//push_z_layer(Z_LAYER_BENCHMARK_TOOL);
	//draw_text(font, sprint(get_temporary_allocator(), STR("%d, %d"), x, y), font_height, v2(x_coord, y_coord), v2(0.1, 0.1), COLOR_RED);
	//pop_z_layer();
	return v2{x_coord, y_coord}
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
		// Render map

		for i := 0; i < GRID_W; i += 1 {
			for j := 0; j < GRID_H; j += 1 {
				color := hex_to_rgba(0x6a6997FF)
				if (j % 2 == i % 2) {
					color = hex_to_rgba(0x2c2851ff)
				}
				pos := grid_to_coord(gp{i, j})
				draw_rect(pos, GRID_TILE, color, img_id = Image_Id.tile)
			}
		}

		grid := coord_to_grid(game.mouse_pos)

		if grid.x >= 0 && grid.x < GRID_W && grid.y >= 0 && grid.x < GRID_H {
			draw_rect(grid_to_coord(grid), GRID_TILE, COLOR_RED, img_id = Image_Id.tile)
		}
		


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
		camera_offset := game.camera_pos - (v2{f32(global.window_w), f32(global.window_h)} * 0.5)

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
