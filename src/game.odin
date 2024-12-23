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

g := &global

// :GAME STATE
game: struct {
	fps:              FPS,
	debug:            bool,
	screen:           Screens,
	player_health:    f32, // 0.0 -> 1.0
	mouse_pos_screen: v2,
	mouse_pos:        v2,
	camera_pos:       v2,
	camera_zoom:      f32,
	world:            [GRID_W][GRID_W]TileId,
	spawn_point:      GridPos,
	finish_point:     GridPos,
	enemies:          [128]Entity,
	enemies_n:        int,
	enemy_last_added: f64,
}


TileId :: enum {
	none,
	path,
	spawn,
	finish,
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

	game.world = [GRID_W][GRID_H]TileId {
		{.none, .spawn, .none, .none, .none, .none, .none, .none},
		{.none, .path, .none, .none, .none, .none, .none, .none},
		{.none, .path, .none, .none, .none, .none, .none, .none},
		{.none, .path, .path, .path, .path, .none, .none, .none},
		{.none, .none, .none, .none, .path, .none, .none, .none},
		{.none, .none, .none, .none, .path, .none, .none, .none},
		{.none, .none, .none, .none, .path, .none, .none, .none},
		{.none, .none, .none, .none, .finish, .none, .none, .none},
	}

	game.enemies_n = 0
	game.enemy_last_added = elapsed_t

	game.spawn_point = gp{0, 1}
	game.finish_point = gp{7, 4}

	game.player_health = 1.0

}

GridPos :: [2]int

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

	return gp{int(math.floor(x)) + 2, int(math.floor(y) - 2)}
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


Entity :: struct {
	image_id:         Image_Id,
	position:         Vector2,
	travel_map:       [GRID_W][GRID_H]bool,
	next_destination: Vector2,
	speed:            f32,
	health:           f32,
	max_health:       f32,
}

find_next :: proc(
	grid: GridPos,
	travel_map: [GRID_W][GRID_H]bool,
	tile_id: TileId,
) -> (
	GridPos,
	bool,
) {
	dest := gp{0, 0}
	found := false
	if grid.x < GRID_W - 1 &&
	   travel_map[grid.x + 1][grid.y] == false &&
	   game.world[grid.x + 1][grid.y] == tile_id {
		dest = gp{grid.x + 1, grid.y}
		found = true
	} else if grid.x > 0 &&
	   travel_map[grid.x - 1][grid.y] == false &&
	   game.world[grid.x - 1][grid.y] == tile_id {
		dest = gp{grid.x - 1, grid.y}
		found = true
	} else if grid.y < GRID_H - 1 &&
	   travel_map[grid.x][grid.y + 1] == false &&
	   game.world[grid.x][grid.y + 1] == tile_id {
		dest = gp{grid.x, grid.y + 1}
		found = true
	} else if grid.y > 0 &&
	   travel_map[grid.x][grid.y - 1] == false &&
	   game.world[grid.x][grid.y - 1] == tile_id {
		dest = gp{grid.x, grid.y - 1}
		found = true
	}
	return dest, found

}

// Runs every frame
tower_game_render :: proc "c" () {
	context = runtime.default_context()
	sapp.set_mouse_cursor(.DEFAULT)

	tower_game_event()
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
	draw_frame.camera_xform =
		draw_frame.camera_xform *
		linalg.matrix4_translate(v3{game.camera_pos.x, game.camera_pos.y, 0})
	draw_frame.camera_xform =
		draw_frame.camera_xform * linalg.matrix4_scale(v3{game.camera_zoom, game.camera_zoom, 1})

	// :FPS
	if (elapsed_t - game.fps.last_updated >= 1) {
		game.fps.last_updated = elapsed_t
		game.fps.value = 1 / auto_cast delta_t()
	}

	// Entity handling

	if (elapsed_t - game.enemy_last_added > 2) { 	// creates new enemy
		game.enemy_last_added = elapsed_t

		spawn := game.spawn_point
		pos := grid_to_coord(spawn)

		pos.x += f32(GRID_TILE.x) / 2.0
		pos.y += f32(GRID_TILE.y) / 2.0
		grid := spawn

		dest_gp, _ := find_next(grid, {}, .path)
		dest := grid_to_coord(dest_gp)
		dest += GRID_TILE / 2.0


		game.enemies[game.enemies_n] = Entity {
			image_id         = .enemy,
			position         = pos,
			health           = 1.0,
			max_health       = 1.0,
			speed            = 0.5,
			next_destination = dest,
		}
		game.enemies_n += 1
	}

	for i := 0; i < game.enemies_n; i += 1 {
		enemy := &game.enemies[i]
		if enemy.image_id == .nil {
			continue
		}
		direction := enemy.next_destination - enemy.position
		grid := coord_to_grid(enemy.position)
		if grid.x < 0 || grid.x >= GRID_W || grid.y < 0 || grid.y >= GRID_H {
			game.enemies[i].image_id = .nil
			game.player_health -= 0.2
			continue
		}
		enemy.travel_map[grid.x][grid.y] = true

		if (abs(direction.x) < 1 && abs(direction.y) < 1) ||
		   is_within_square(enemy.position, enemy.next_destination, v2{20, 20}) {
			dest_gp, path_exists := find_next(grid, enemy.travel_map, .path)
			if !path_exists {
				dest_gp, _ = find_next(grid, enemy.travel_map, .finish)
				dest := grid_to_coord(dest_gp)
				dest += GRID_TILE / 2
				new_direction := dest - enemy.position
				dest += new_direction
				enemy.next_destination = dest
			} else {
				dest := grid_to_coord(dest_gp)
				dest += GRID_TILE / 2
				enemy.next_destination = dest
			}
		}
		v2_normalize(&direction)
		enemy.position += direction * enemy.speed * f32(delta_t()) * 100
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
				tile := game.world[i][j]
				pos := grid_to_coord(gp{i, j})
				switch tile {
				case .none:
					color := hex_to_rgba(0x6a6997FF)
					if (j % 2 == i % 2) {
						color = hex_to_rgba(0x2c2851ff)
					}
					draw_rect(pos, GRID_TILE, color, img_id = Image_Id.tile)
				case .path, .finish, .spawn:
					draw_rect(pos, GRID_TILE, hex_to_rgba(0xac9098ff), img_id = Image_Id.tile)

				}
			}
		}

		grid := coord_to_grid(game.mouse_pos)

		if grid.x >= 0 && grid.x < GRID_W && grid.y >= 0 && grid.y < GRID_H {
			draw_rect(grid_to_coord(grid), GRID_TILE, COLOR_RED, img_id = Image_Id.tile)
		}

		for i := 0; i < game.enemies_n; i += 1 {
			entity := game.enemies[i]
			img := images[entity.image_id]
			size := v2{f32(img.width), f32(img.height)}
			draw_rect(entity.position - (size / 4), size, COLOR_WHITE, img_id = entity.image_id)
		}


		// :UI

		// Heart


		tr := screen_to_world(v2{f32(global.window_w), f32(global.window_h)})
		//tr := v2{f32(global.window_w) / 2.0, f32(global.window_h) / 2.0}
		tr -= v2{10, 10} / game.camera_zoom
		scale: f64 = 1 / f64(game.camera_zoom)

		text_size := draw_text(
			tr,
			fmt.tprintf("%1.0f", game.player_health * 100),
			scale,
			.top_right,
			hex_to_rgba(color_text),
		)
		tr.x -= text_size.x
		tr.x -= 10 * auto_cast scale
		tr.y -= text_size.y / 2

		heart := images[Image_Id.heart]
		size := v2{2, 2} * v2{f32(heart.width), f32(heart.height)} * f32(scale)
		offset_to_render := size * -scale_from_pivot(.center_right)


		draw_rect(tr + offset_to_render, size, img_id = Image_Id.heart)


	}


	// Render debug stats
	if game.debug {
		debug_scale: f64 = 0.75 / f64(game.camera_zoom)
		//debug_color := hex_to_rgba(color_text)
		debug_color := COLOR_RED
		tl := v2{0, auto_cast global.window_h}
		tl = screen_to_world(tl)
		tl += v2{10, -10} / game.camera_zoom
		size := draw_text(
			tl,
			fmt.tprintf("FPS: %.0f", game.fps.value),
			pivot = .top_left,
			color = debug_color,
			scale_d = debug_scale,
		)
		tl.y -= size.y
		size = draw_text(
			tl,
			fmt.tprintf("Time Elapsed: %.0fs", elapsed_t),
			pivot = .top_left,
			color = debug_color,
			scale_d = debug_scale,
		)
		tl.y -= size.y
		size = draw_text(
			tl,
			fmt.tprintf("Entities: %d", game.enemies_n),
			pivot = .top_left,
			color = debug_color,
			scale_d = debug_scale,
		)
		tl.y -= size.y
		size = draw_text(
			tl,
			fmt.tprintf("Mouse [Screen]: %f", game.mouse_pos_screen),
			pivot = .top_left,
			color = debug_color,
			scale_d = debug_scale,
		)
		tl.y -= size.y
		size = draw_text(
			tl,
			fmt.tprintf("Mouse [World]: %f", game.mouse_pos),
			pivot = .top_left,
			color = debug_color,
			scale_d = debug_scale,
		)
	}


}

tower_game_event :: proc "c" () {
	context = runtime.default_context()

	/**
	if g.keyboard.events_n < 255 {
		g.keyboard.events[g.keyboard.events_n] = event
		g.keyboard.events_n += 1
	}
	**/

	if game.screen == .game {
		cam_axis := v2{0, 0}

		if key_down(.W) {
			cam_axis.y -= 1.0
		}
		if key_down(.A) {
			cam_axis.x += 1.0
		}
		if key_down(.S) {
			cam_axis.y += 1.0
		}
		if key_down(.D) {
			cam_axis.x -= 1.0
		}
		v2_normalize(&cam_axis)
		game.camera_pos += cam_axis * f32(delta_t()) * 800 * (1 / game.camera_zoom)

		if key_just_pressed(.SPACE) {
			global.paused = !global.paused
		}
	}

	if key_just_pressed(.F3) {
		game.debug = !game.debug
	}

	if key_just_pressed(.ESCAPE) {
		fmt.printfln("Quitting game...")
		sapp.quit()
	}

	game.mouse_pos_screen = global.input_state.mouse
	game.mouse_pos = screen_to_world(global.input_state.mouse)

	dir := global.input_state.scroll.y
	game.camera_zoom += dir * f32(delta_t()) * 50

	MAX_ZOOM :: 0.5
	MIN_ZOOM :: 2.3

	if game.camera_zoom < MAX_ZOOM {
		game.camera_zoom = MAX_ZOOM
	} else if game.camera_zoom > MIN_ZOOM {
		game.camera_zoom = MIN_ZOOM
	}

	if key_just_pressed(.LEFT) {
		switch current_event {
		case .create_new_game:
			fmt.printfln("Creating new game...")
			game.screen = .game
		case .none:

		}

	}

}
