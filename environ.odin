package main

Wall :: struct {
	sprite_i: int,
	cell: [2]int
}

walls: [dynamic]Wall

add_wall :: proc(cell: [2]int) 
{
	wall_pos := cell_pos(cell)
	wall_sprite_i := add_sprite(
		"wall_1.png", 
		pos = wall_pos, 
		col = {0.88, 0.93, 0.7, 1} ,
		anchor = .bottom_left, 
		z = 2
	)
	append(&walls, Wall { sprite_i = wall_sprite_i, cell = pos_to_cell(wall_pos) })
}
