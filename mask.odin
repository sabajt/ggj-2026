package main

import ttf "vendor:sdl3/ttf"
import "core:fmt"

MASK_SLOT_SIDE :: GRID_PADDING
MASK_SLOT_MARGIN :: f32(4) 

mask_box_refs: [6][2]int = {}
mask_index: int = 0

Index_Step_Direction :: enum {
	up, 
	down
}

Mask :: struct {
	image_name: string,
	color: [4]f32,
	move_type: Move_Type,
	spell_type: Spell_Type
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

	// update rhs menu spell icon
	spell_icon_sprite := &sprites[rhs_menu_spell_icon_sprite_i]
	spell_icon_sprite.name = spell_icon_name(mask.spell_type)
	spell_icon_sprite.col = mask.color

	// update rhs menu spell title text
	update_text_item(rhs_menu_spell_title_text_i, spell_title_text(mask.spell_type), mask.color)

}

// vv menu layout file?

mask_slot_center :: proc(i: int) -> [2]f32
{
	pos_y := MASK_SLOT_SIDE / 2.0 + 2 * UI_PAD
	org_x := grid_right + UI_DIVIDER_1

	rhs_width := INTERNAL_RES.x - org_x
	slot_width := (rhs_width - 2 * MASK_SLOT_MARGIN) / 6.0

	pos: [2]f32 = {
		org_x + f32(i) * slot_width + slot_width/2 + MASK_SLOT_MARGIN,
		INTERNAL_RES.y - pos_y
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

rhs_menu_mask_selector_bottom_divider_y :: proc() -> f32
{
	return INTERNAL_RES.y - 2 * (INTERNAL_RES.y - mask_slot_center(0).y) - 1
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

// ^^ menu layout?

