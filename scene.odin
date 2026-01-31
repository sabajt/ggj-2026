package main

import "core:math/rand"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

Game_State :: enum {
	main
}

cell_pos :: proc(x: int, y: int) -> [2]f32
{
	return { f32(x) * GRID_PADDING, f32(y) * GRID_PADDING } 
}

enter_main :: proc()
{
	game_state = .main

	for x in 0..<40 {
		for y in 0..<22 {
			if rand.int31_max(5) >= 4 {
				spr_i := add_sprite("wiz.png", pos = cell_pos(x,y), anchor = .bottom_left)
				spr := &sprites[spr_i]
			}
		}
	}
}

exit_main :: proc()
{
}

