package main

import "core:math/rand"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

Game_State :: enum {
	main
}

enter_main :: proc()
{
	game_state = .main

	grid_size_x := 40
	grid_size_y := 22
	wizard_pad := 5

	// for x in 0 ..< grid_size_x {
	// 	for y in 0 ..< grid_size_y {
	// 		if rand.int_max(wizard_pad) >= 4 {
	// 			spr_i := add_sprite("fire.png", pos = cell_pos({x, y}), anchor = .bottom_left)
	// 			spr := &sprites[spr_i]
	// 		}
	// 	}
	// }

	// add player
	cell := [2]int { 
		wizard_pad + rand.int_max(grid_size_x - 2 * wizard_pad), 
		wizard_pad + rand.int_max(grid_size_y - 2 * wizard_pad)
	}
	spr_i := add_sprite("mask_1.png", pos = cell_pos(cell), anchor = .bottom_left)
	player = Wizard { sprite = spr_i, cell = cell}

	// add enemy
	cell = {grid_size_x - cell.x, grid_size_y - cell.y}
	spr_i = add_sprite("mask_2.png", pos = cell_pos(cell), anchor = .bottom_left)
	enemy = Wizard {
		sprite = spr_i,
		cell = cell
	}
}

exit_main :: proc()
{
}

