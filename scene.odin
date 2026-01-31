package main

import "core:math/rand"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

player: Wizard

Game_State :: enum {
	main
}

enter_main :: proc()
{
	game_state = .main

	for x in 0..<40 {
		for y in 0..<22 {
			if rand.int31_max(5) >= 4 {
				spr_i := add_sprite("fire.png", pos = cell_pos(x,y), anchor = .bottom_left)
				spr := &sprites[spr_i]
			}
		}
	}

	grid_size_x := 40
	grid_size_y := 22
	wizard_pad := 5
	cell := [2]int { 
		wizard_pad + rand.int_max(grid_size_x - 2 * wizard_pad), 
		wizard_pad + rand.int_max(grid_size_y - 2 * wizard_pad)
	}
	spr_i := add_sprite("wiz.png", pos = cell_pos(cell.x, cell.y), anchor = .bottom_left)
	spr := &sprites[spr_i]
	player = Wizard { sprite = spr, cell = cell}
}

exit_main :: proc()
{
}

