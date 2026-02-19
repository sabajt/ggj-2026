package main

import "core:math"
import "core:math/rand"
import "core:fmt"

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int
player_dir_indicator_shape_i: int

Game_State :: enum {
	main
}

GAME_GRID_SIZE_X :: 30
GAME_GRID_SIZE_Y :: 21
UI_DIVIDER_1 :: f32(1)
WIZARD_PAD :: 5
GAME_OVER_DELAY_DUR :: 90

grid_right := GRID_PADDING * GAME_GRID_SIZE_X
grid_top := GRID_PADDING * GAME_GRID_SIZE_Y + 0.3 // TODO: WHY

enter_main :: proc()
{
	game_state = .main
	reset_game() // careful this needs to be called first to clear colletions

	// top UI bar
	topbar_rect_height := INTERNAL_RES.y - grid_top
	add_shape({
		type = .Rectangle,
		tf = tf({0, grid_top}, 0, {INTERNAL_RES.x, topbar_rect_height}),
		color = {0,0,0,1},
		anchor = .bottom_left,
		z = 1,
		visible = true
	})
	add_shape({
		type = .Rectangle,
		tf = tf({0, grid_top}, 0, {INTERNAL_RES.x, UI_DIVIDER_1}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 2,
		visible = true
	}) 

	// right-side UI bar

	rightbar_rect_width := INTERNAL_RES.x - grid_right
	add_shape({
		type = .Rectangle,
		tf = tf({grid_right, 0}, 0, {rightbar_rect_width, INTERNAL_RES.y}),
		color = {0,0,0,1},
		anchor = .bottom_left,
		z = 1,
		visible = true
	})
	add_shape({
		type = .Rectangle,
		tf = tf({grid_right, 0}, 0, {UI_DIVIDER_1, grid_top}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 1,
		visible = true
	})

	init_mask_boxes()

	// // right hand text
	// id := add_text_item("Testing some text")
	// text_item := &text_items[id]
	// text_item.pos = fit_res_vec2({grid_right + 6, grid_top - 4}, resolution)

	// player direction arrow (pos updated on stick / player move)
	player_dir_indicator_shape_i = add_shape({
		type = .Triangle,
		color = COL_GRAY_0,
		anchor = .center,
		z = 1,
		visible = false
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
	clear(&masks)

	// add player masks
	mask := Mask {
		image_name = "mask_1.png",
		color = COL_LEMON_LIME,
		move_type = .step,
		spell_type = .fire  
	}
	add_mask(mask)

	// add player
	cell := [2]int { 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_X - 2 * WIZARD_PAD), 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_Y - 2 * WIZARD_PAD)
	}
	player_pos := cell_pos(cell)
	spr_i := add_sprite(mask.image_name, pos = player_pos, col = mask.color, anchor = .bottom_left)
	player = Wizard { sprite = spr_i, pos = player_pos}

	// add enemy
	add_enemy({GAME_GRID_SIZE_X - cell.x, GAME_GRID_SIZE_Y - cell.y})

	// TESTING mask add
	add_mask({
		image_name = "mask_2.png",
		color = COL_BLUE_RASP,
		move_type = .step,
		spell_type = .orb  
	})

	// TESTING mask add
	add_mask({
		image_name = "mask_3.png",
		color = COL_FRESH_ORANGE,
		move_type = .step,
		spell_type = .fire  
	})
}

