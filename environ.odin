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

add_enemy :: proc(type: Wizard_Type, cell: [2]int) -> int
{
	i: int
	switch type {
		case .mask_bearer:
			i = add_enemy_mask_bearer(cell)
		case .enemy_0:
			i = add_enemy_basic_0(cell) 
	}
	return i
}

add_enemy_basic_0 :: proc(cell: [2]int) -> int
{
    color := colors[0]
	i := add_sprite("mask_2.png", pos = cell_pos(cell), col = color, anchor = .bottom_left)
	enemy := Wizard {
		type = .enemy_0,
		sprite = i,
		pos = cell_pos(cell),
        color = color,
        health = 3
	}
    enemies[i] = enemy
    return i
}

add_enemy_mask_bearer :: proc(cell: [2]int) -> int
{
	color := colors[2]
	i := add_sprite("mask_3.png", pos = cell_pos(cell), col = color, anchor = .bottom_left)
	enemy := Wizard {
		type = .mask_bearer,
		sprite = i,
		pos = cell_pos(cell),
		color = color,
		health = 4
	}
	enemies[i] = enemy
	return i
}

step_enemies :: proc()
{
    for k, &enemy in enemies {
		switch enemy.type {
			case .mask_bearer:
				step_enemy_mask_bearer(&enemy)
			case .enemy_0:
				step_enemy_0(&enemy)
		}
    }
}

step_enemy_mask_bearer :: proc(enemy: ^Wizard)
{
	// TODO: make spell from prototype + context vars (cell, direction etc)

	cell := pos_to_cell(enemy.pos)
	if enemy.t % 2 == 0 {
		for dir in CARDINALS {
			spell := Orb_Spell {
				cell = cell, 
				dir = dir, 
				hostile = true,
				color = enemy.color
			}
			cast_orb_spell(spell)
		}
	} else if enemy.t % 5 == 0 {
		for dir in ORDINALS {
			spell := Orb_Spell {
				cell = cell, 
				dir = dir, 
				hostile = true,
				color = enemy.color
			}
			cast_orb_spell(spell)
		}
	} else {
		cell := get_grid_cell_to_player_path_next_coord(cell)
		add_enemy_move_action(enemy, dest = cell)
	}
	enemy.t += 1
}

step_enemy_0 :: proc(enemy: ^Wizard)
{
	cell := pos_to_cell(enemy.pos)
	if enemy.t % 3 == 0 {
		// TODO: make spell from prototype
		info := snap_direction_info(angle_from_vec2(player.pos - enemy.pos))
		spell := Orb_Spell {
			cell = cell, 
			dir = info.direction, 
			hostile = true,
			color = enemy.color
		}
		cast_orb_spell(spell)
	} else {
		cell := get_grid_cell_to_player_path_next_coord(cell)
		add_enemy_move_action(enemy, dest = cell)
	}
	enemy.t += 1
}



