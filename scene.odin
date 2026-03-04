package main

import "core:math"
import "core:math/rand"
import "core:fmt"

session_t: int
game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int
player_dir_indicator_shape_i: int
rhs_menu_spell_icon_sprite_i: int
rhs_menu_spell_title_text_i: int
rhs_menu_spell_cooldown_text_i: int
rhs_menu_hp_text_i: int

Game_State :: enum {
	main
}

GAME_GRID_SIZE_X :: 28
GAME_GRID_SIZE_Y :: 20
UI_DIVIDER_1 :: f32(1)
UI_PAD :: f32(2)
WIZARD_PAD :: 5
GAME_OVER_DELAY_DUR :: 90

grid_right := GRID_PADDING * GAME_GRID_SIZE_X

enter_main :: proc()
{
	game_state = .main
	reset_game() // careful this needs to be called first to clear colletions
}

reset_game :: proc()
{
	is_game_over = false
	game_over_delay = 0
	killed_by = nil
	session_t = 0
	boss_countdown = 1

	clear(&fires)
	clear(&orbs)
	clear(&actions)
	clear(&shapes)
	clear(&enemies)
	clear(&walls)
	clear_sprites()
	clear_text_items()
	clear_radius_effects()	

	// add player
	cell := [2]int { 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_X - 2 * WIZARD_PAD), 
		WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_Y - 2 * WIZARD_PAD)
	}
	player_pos := cell_pos(cell)
	starting_mask_image := "mask_1.png"
	starting_mask_color := COL_LEMON_LIME
	spr_i := add_sprite(
		starting_mask_image, 
		pos = player_pos, 
		col = starting_mask_color, 
		anchor = .bottom_left, 
		z = 2
	)
	player = Wizard { sprite = spr_i, pos = player_pos, health = 3 }

	// add player masks
	mask := Mask {
		image_name = starting_mask_image,
		color = starting_mask_color,
		move_type = .step,
		spell_type = .fire,
		spell_cool_dur = 3  
	}
	add_mask(mask, &player)

	// add walls 
	add_wall({GAME_GRID_SIZE_X / 2, GAME_GRID_SIZE_Y / 2})
	add_wall({GAME_GRID_SIZE_X / 2, GAME_GRID_SIZE_Y / 2 + 1})
	add_wall({GAME_GRID_SIZE_X / 2, GAME_GRID_SIZE_Y / 2 + 2})
	add_wall({GAME_GRID_SIZE_X / 2, GAME_GRID_SIZE_Y / 2 - 1})
	add_wall({GAME_GRID_SIZE_X / 2, GAME_GRID_SIZE_Y / 2 - 2})

	// add enemy
	add_enemy(
		type = .enemy_0, 
		cell = {GAME_GRID_SIZE_X - cell.x, GAME_GRID_SIZE_Y - cell.y}
	)

	// UI: attack slot
	rhs_menu_spell_icon_sprite_i = add_sprite(
		name = spell_icon_name(mask.spell_type), 
		pos = rhs_menu_spell_icon_center(), 
		col = mask.color, 
		z = 2
	)

	// spell title text
	rhs_menu_spell_title_text_i = add_text_item(spell_title_text(mask.spell_type), color = mask.color)
	text_item := &text_items[rhs_menu_spell_title_text_i]
	// TODO: scale position in render (without scaling texture?). Also why is text top left anchor / easy to control this?
	text_item.pos = fit_res_vec2(rhs_menu_spell_text_top_left(), letterbox_resolution)

	// spell cooldown text
	rhs_menu_spell_cooldown_text_i = add_text_item(mask_spell_cooldown_number_text(mask), color = mask.color)
	spell_cooldown_text := &text_items[rhs_menu_spell_cooldown_text_i]
	// TODO: scale position in render (without scaling texture?). Also why is text top left anchor / easy to control this?
	spell_cooldown_text.pos = fit_res_vec2(rhs_menu_spell_cooldown_text_top_left(), letterbox_resolution)

	// right-side UI background / dividers

	rightbar_rect_width := INTERNAL_RES.x - grid_right
	add_shape({ // background fill
		type = .Rectangle,
		tf = tf({grid_right, 0}, 0, {rightbar_rect_width, INTERNAL_RES.y}),
		color = COL_BLACK,
		anchor = .bottom_left,
		z = 1,
		visible = true
	})
	add_shape({ // vertical divider
		type = .Rectangle,
		tf = tf({grid_right, 0}, 0, {UI_DIVIDER_1, INTERNAL_RES.y}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 1,
		visible = true
	})
	add_shape({ // hp section bottom divider
		type = .Rectangle,
		tf = tf({grid_right, rhs_menu_hp_section_bottom_divider_y()}, 0, {rightbar_rect_width, UI_DIVIDER_1}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 1,
		visible = true
	})
	add_shape({ // top mask selection bottom divider
		type = .Rectangle,
		tf = tf({grid_right, rhs_menu_mask_selector_bottom_divider_y() }, 0, {rightbar_rect_width, UI_DIVIDER_1}),
		color = COL_GRAY_0,
		anchor = .bottom_left,
		z = 1,
		visible = true
	})

	init_mask_boxes()
	init_hp_hearts()

	// player direction arrow (pos updated on stick / player move)
	player_dir_indicator_shape_i = add_shape({
		type = .Triangle,
		color = COL_GRAY_0,
		anchor = .center,
		z = 1,
		visible = false
	})

	// ------------ Test Add Some Masks ------------
	add_mask(
		{
			image_name = "mask_2.png",
			color = colors[7],
			move_type = .step,
			spell_type = .orb,
			spell_cool_dur = 1
		},
		actor = &player
	)
	add_mask(
		{
			image_name = "mask_3.png",
			color = colors[6],
			move_type = .step,
			spell_type = .fire,
			spell_cool_dur = 5
		},
		actor = &player
	)
	add_mask(
		{
			image_name = "mask_1.png",
			color = colors[5],
			move_type = .step,
			spell_type = .orb,
			spell_cool_dur = 2  
		},
		actor = &player
	)
	add_mask(
		{
			image_name = "mask_3.png",
			color = colors[4],
			move_type = .step,
			spell_type = .fire,
			spell_cool_dur = 6  
		},
		actor = &player
	)
}

