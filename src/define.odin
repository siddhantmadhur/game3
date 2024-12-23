package main



Image_Id :: enum {
	nil,
	housemd,
	wilsonmd,
	brick,
	tile,
	enemy,
	heart,
	turret_small,
}

// Change this to whatever example needs to be rendered
bg_color :: tower_defense_bg_color
game_init :: tower_game_init
game_render :: tower_game_render


// General game variables
GRID_W :: 8
GRID_H :: 8
GRID_TILE :: v2{128, 64}
