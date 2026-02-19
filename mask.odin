package main

MASK_SLOT_SIDE :: GRID_PADDING + 4

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
masks := make([dynamic]Mask)

add_mask :: proc(mask: Mask)
{
	append(&masks, mask)

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

	// number_of_masks := len(masks)
	// switch dir {
	// 	case .up:
	// 		if mask_index < number_of_masks - 1 {
	// 			mask_index += 1
	// 		}
	// 	case .down:
	// 		if mask_index > 0 {
	// 			mask_index -= 1
	// 		}
	// }
}

mask_slot_center :: proc(i: int) -> [2]f32
{
	box_padding := f32(6)
	pos_x := MASK_SLOT_SIDE / 2.0 + box_padding
	pos_y := MASK_SLOT_SIDE / 2.0 + 5.0 // TODO: WHY
	pos: [2]f32 = {
		grid_right + pos_x + f32(i) * MASK_SLOT_SIDE + f32(i) * box_padding,
		grid_top - pos_y
	}
	return pos
}

init_mask_boxes :: proc()
{
	// DOING:
	// [x] save shape indexes for reference later (give me shapes at index 0-5)
	// [x] step mask index based on player mask array from input
	// [x] update shape visibility on index change
	// [x] draw mask sprite on top always 
	// [] player actions based on mask 
	// [] implement orb attack mask 

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


