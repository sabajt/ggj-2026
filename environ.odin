package main

import "core:math/rand"

Wall :: struct {
	sprite_i: int,
	cell: [2]int
}

walls: [dynamic]Wall // TODO: all globals should be moved to one spot?
enemies: map[int]Wizard

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

add_enemy :: proc(cell: [2]int) -> int
{
    col_i := rand.int_max(8)
    color := colors[col_i]
	i := add_sprite("mask_2.png", pos = cell_pos(cell), col = color, anchor = .bottom_left)
	enemy := Wizard {
		sprite = i,
		pos = cell_pos(cell),
        color = color,
        health = 3
	}
    enemies[i] = enemy
    return i
}

