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
UI_DIVIDER_1 :: f32(1)
WIZARD_PAD :: 5
GAME_OVER_DELAY_DUR :: 90

enter_main :: proc()
{
	game_state = .main
	reset_game()

	// top UI bar
	grid_top := GRID_PADDING * GAME_GRID_SIZE_Y + 0.3
	topbar_rect_height := INTERNAL_RES.y - grid_top
	add_rectangle({
		tf = tf({0, grid_top}, 0, {INTERNAL_RES.x, topbar_rect_height}),
		color = {0,0,0,1},
		anchor = .bottom_left,
		z = 1
	})
	add_rectangle({
		tf = tf({0, grid_top}, 0, {INTERNAL_RES.x, UI_DIVIDER_1}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 2
	})

	// right-side UI bar
	grid_right := GRID_PADDING * GAME_GRID_SIZE_X
	rightbar_rect_width := INTERNAL_RES.x - grid_right
	add_rectangle({
		tf = tf({grid_right, 0}, 0, {rightbar_rect_width, INTERNAL_RES.y}),
		color = {0,0,0,1},
		anchor = .bottom_left,
		z = 1
	})
	add_rectangle({
		tf = tf({grid_right, 0}, 0, {UI_DIVIDER_1, grid_top}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 1
	})

	// right hand text
	id := add_text_item("Testing some text")
	text_item := &text_items[id]
	text_item.pos = fit_res_vec2({grid_right + 6, grid_top - 4}, resolution)
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


