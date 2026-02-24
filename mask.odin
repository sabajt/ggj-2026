package main

import ttf "vendor:sdl3/ttf"
import "core:fmt"

MASK_SLOT_SIDE :: GRID_PADDING
MASK_SLOT_MARGIN :: f32(4) 

mask_box_refs: [6][2]int = {}
mask_index: int = 0
heart_sprite_refs: [6]int = {}

Index_Step_Direction :: enum {
	up, 
	down
}

Mask :: struct {
	image_name: string,
	color: [4]f32,
	move_type: Move_Type,
	spell_type: Spell_Type,
	spell_cool_t: int, // ready when 0
	spell_cool_dur: int
}
masks: [dynamic]Mask

add_mask :: proc(mask: Mask)
{
	append(&masks, mask)

	// UI: mask slot
	add_sprite(
		name = mask.image_name, 
		pos = mask_slot_center(len(masks) - 1), 
		col = mask.color, 
		z = 2
	)
}

attempt_current_mask_spell :: proc(dir: Direction) 
{
    if current_mask_spell_ready() {
        spell := create_current_mask_spell(pos_to_cell(player.pos), dir = dir)
        handle_wizard_spell(spell)
    } else {
		// TODO: implement "can't cast" feedback or remove
        fmt.println("current mask spell not ready")
    }
}

current_mask_spell_ready :: proc() -> bool
{
	mask := get_current_mask()
	return mask.spell_cool_t == 0
}

get_current_mask :: proc() -> ^Mask 
{
	return &masks[mask_index]
}

mask_spell_cooldown_number_text :: proc(mask: Mask) -> string
{
	result := "Ready"
	if mask.spell_cool_t > 0 {
		result = fmt.tprint(mask.spell_cool_t)
	}
	return result
}

mask_spell_cooldown_color :: proc(mask: Mask) -> [4]f32
{
	result := mask.color
	if mask.spell_cool_t > 0 {
		result = COL_GRAY_0
	}
	return result
}

step_mask_index :: proc(dir: Index_Step_Direction) 
{
	last_mask_index := mask_index
	mask_index = dir == .up ? min(mask_index + 1, len(masks) - 1) : max(mask_index - 1, 0) 

	if last_mask_index != mask_index {
		for i in mask_box_refs[last_mask_index] {
			(&shapes[i]).visible = false
		}
		for i in mask_box_refs[mask_index] {
			(&shapes[i]).visible = true
		}
	}  

	// update player sprite
	mask := masks[mask_index]
	sprite := get_player_sprite()
	sprite.name = mask.image_name
	sprite.col = mask.color

	// update spell UI
	update_rhs_spell_icon()
	update_rhs_menu_spell_title_text()
	update_rhs_menu_spell_cooldown_text()
}

get_spell_icon_sprite :: proc() -> ^Sprite
{
	return &sprites[rhs_menu_spell_icon_sprite_i]
}

mask_slot_center :: proc(i: int) -> [2]f32
{
	org_x := grid_right + UI_DIVIDER_1
	rhs_width := INTERNAL_RES.x - org_x
	slot_width := (rhs_width - 2 * MASK_SLOT_MARGIN) / 6.0

	pos: [2]f32 = {
		org_x + f32(i) * slot_width + slot_width/2 + MASK_SLOT_MARGIN,
		INTERNAL_RES.y - 1.5 * rhs_section_height()
	}
	return pos
}

heart_slot_center :: proc(i: int) -> [2]f32
{
	org_x := grid_right + UI_DIVIDER_1
	rhs_width := INTERNAL_RES.x - org_x
	slot_width := (rhs_width - 2 * MASK_SLOT_MARGIN) / 6.0

	pos: [2]f32 = {
		org_x + f32(i) * slot_width + slot_width/2 + MASK_SLOT_MARGIN,
		INTERNAL_RES.y - 0.5 * rhs_section_height()
	}
	return pos
}


rhs_menu_spell_icon_center :: proc() -> [2]f32
{
	pos := mask_slot_center(0)
	pos.y = rhs_menu_mask_selector_bottom_divider_y() - (MASK_SLOT_MARGIN + MASK_SLOT_SIDE / 2)
	return pos
}

rhs_menu_spell_text_top_left :: proc() -> [2]f32
{
	pos := rhs_menu_spell_icon_center()
	// TODO: this will break at different sizes and need to be added to config
	// sdl text size gives unexpected results.. how to get actual text size in pixels?
	pos += {16, 4} 
	return pos
}

rhs_menu_spell_cooldown_text_top_left :: proc() -> [2]f32
{
	pos := rhs_menu_spell_text_top_left()
	// TODO: this will break at different sizes and need to be added to config
	// sdl text size gives unexpected results.. how to get actual text size in pixels?
	pos += {60, 0} 
	return pos
}

rhs_menu_hp_section_bottom_divider_y :: proc() -> f32
{
	return INTERNAL_RES.y - rhs_section_height()
}

rhs_menu_mask_selector_bottom_divider_y :: proc() -> f32
{
	return INTERNAL_RES.y - 2 * rhs_section_height()
}

rhs_section_height :: proc() -> f32
{
	return MASK_SLOT_SIDE + 4 * UI_PAD + 1
}

init_mask_boxes :: proc()
{
	for i in 0..<6 {
		pos := mask_slot_center(i)
		mask_box_refs[i][0] = add_shape({ // outer
			type = .Rectangle,
			tf = tf(
				pos = pos, 
				rot = 0, 
				scale = {MASK_SLOT_SIDE, MASK_SLOT_SIDE}
			),
			color = COL_GRAY_0,
			anchor = .center,
			z = 1,
			visible = i == 0 ? true : false
		})
		mask_box_refs[i][1] = add_shape({ // inner
			type = .Rectangle,
			tf = tf(
				pos = pos, 
				rot = 0, 
				scale = {MASK_SLOT_SIDE - 2, MASK_SLOT_SIDE - 2}
			),
			color = {0,0,0,1},
			anchor = .center,
			z = 1,
			visible = i == 0 ? true : false
		})
	}
}

init_hp_hearts :: proc()
{
	for i in 0..<6 {
		pos := heart_slot_center(i)
		heart_sprite_refs[i] = add_sprite(
			name = "heart.png",
			pos = pos,
			col = COL_PANIC_RED,
			z = 2
		)
	}
}

