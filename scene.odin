package main

import "core:math/rand"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

Game_State :: enum {
	main
}

GAME_GRID_SIZE_X :: 40
GAME_GRID_SIZE_Y :: 22
WIZARD_PAD :: 5

enter_main :: proc()
{
	game_state = .main
	reset_game()
}

reset_game :: proc()
{
	clear(&fires)
	clear(&sprites)

	// add player
	cell := [2]int { 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_X - 2 * WIZARD_PAD), 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_Y - 2 * WIZARD_PAD)
	}
	spr_i := add_sprite("mask_1.png", pos = cell_pos(cell), anchor = .bottom_left)
	player = Wizard { sprite = spr_i, cell = cell}

	// add enemy
	add_enemy({GAME_GRID_SIZE_X - cell.x, GAME_GRID_SIZE_Y - cell.y})
}





	// for x in 0 ..< grid_size_x {
	// 	for y in 0 ..< grid_size_y {
	// 		if rand.int_max(wizard_pad) >= 4 {
	// 			spr_i := add_sprite("fire.png", pos = cell_pos({x, y}), anchor = .bottom_left)
	// 			spr := &sprites[spr_i]
	// 		}
	// 	}
	// }

