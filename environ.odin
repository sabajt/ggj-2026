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
	i := add_sprite("", pos = cell_pos(cell), anchor = .bottom_left)
	enemy := Wizard {
		type = .mask_bearer,
		sprite = i,
		pos = cell_pos(cell),
		health = 4
	}
	add_mask(
		{
			image_name = "mask_2.png",
			color = colors[3],
			move_type = .step,
			spell_prototype = Fire_Spell { color = colors[3], hostile = true },
			spell_cool_dur = 6
		},
		actor = &enemy
	)
	add_mask(
		{
			image_name = "mask_1.png",
			color = colors[4],
			move_type = .step,
			spell_prototype = Orb_Spell { color = colors[4], hostile = true },
			spell_cool_dur = 3
		},
		actor = &enemy
	)
	update_enemy_sprite_for_current_mask(&enemy)
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

cast_spell :: proc(prototype: Spell, cell: [2]int, dir: Direction)
{
	switch val in prototype {
		case Fire_Spell:
			spell := Fire_Spell {
				cell = cell, 
				dir = dir, 
				hostile = val.hostile,
				color = val.color
			}
			cast_fire_spell(spell)
		case Orb_Spell:
			spell := Orb_Spell {
				cell = cell, 
				dir = dir, 
				hostile = val.hostile,
				color = val.color
			}
			cast_orb_spell(spell)
	}
}

step_enemy_mask_bearer :: proc(enemy: ^Wizard)
{
	cell := pos_to_cell(enemy.pos)

	if current_mask_spell_ready(enemy^) {
		// cast spell
		info := snap_direction_info(angle_from_vec2(player.pos - enemy.pos))
		mask := &enemy.masks[enemy.cur_mask]
		mask.spell_cool_t = mask.spell_cool_dur + 1
		cast_spell(mask.spell_prototype, cell = cell, dir = info.direction)

		// find the lowest cooldown num slot and change to it
		lowest_cooldown := max(int)
		for i in 0 ..< enemy.num_masks {
			m := &enemy.masks[i]
			if m.spell_cool_t < lowest_cooldown {
				lowest_cooldown = m.spell_cool_t
				enemy.cur_mask = i
			}
		}
		update_enemy_sprite_for_current_mask(enemy)

	} else {
		// move
		cell := get_grid_cell_to_player_path_next_coord(cell)
		add_enemy_move_action(enemy, dest = cell)
	}
	enemy.t += 1
}

update_enemy_sprite_for_current_mask :: proc(enemy: ^Wizard)
{
	next_mask := &enemy.masks[enemy.cur_mask]
	update_sprite(&sprites[enemy.sprite], name = next_mask.image_name, col = next_mask.color)
}

step_enemy_0 :: proc(enemy: ^Wizard)
{
	cell := pos_to_cell(enemy.pos)
	if enemy.t % 3 == 0 {
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



