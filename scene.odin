package main

import "core:math/rand"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

Game_State :: enum {
	main
}

GAME_GRID_SIZE_X :: 30
GAME_GRID_SIZE_Y :: 21
WIZARD_PAD :: 5
GAME_OVER_DELAY_DUR :: 90

enter_main :: proc()
{
	game_state = .main
	reset_game()

	id := add_text_item("Testing some text")
	text_item := &text_items[id]
	text_item.pos = {resolution.x - 460, resolution.y - 100}

	add_rectangle({
		position = {resolution.x / 2, resolution.y - 200},
		size = {resolution.x, 143},
		color = {0,0,1,1},
		z = 0
	})

	add_rectangle({
		position = {resolution.x / 2, resolution.y - 100},
		size = {resolution.x/2, 143},
		color = {1,0,0,1},
		z = 1
	})

	add_rectangle({
		position = {resolution.x / 2, resolution.y - 50},
		size = {200, 143},
		color = {1,1,0,1},
		z = 2
	})
}

reset_game :: proc()
{
	is_game_over = false
	game_over_delay = GAME_OVER_DELAY_DUR
	killed_by = nil

	clear(&fires)
	clear(&orbs)
	clear(&sprites)
	clear(&actions)

	// add player
	cell := [2]int { 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_X - 2 * WIZARD_PAD), 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_Y - 2 * WIZARD_PAD)
	}
	player_pos := cell_pos(cell)
	spr_i := add_sprite("mask_1.png", pos = player_pos, col = COL_LEMON_LIME, anchor = .bottom_left)
	player = Wizard { sprite = spr_i, pos = player_pos}

	// add enemy
	add_enemy({GAME_GRID_SIZE_X - cell.x, GAME_GRID_SIZE_Y - cell.y})
}


