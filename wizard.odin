package main

import "core:fmt"
import "core:math/rand"

ACTOR_HIT_T_DUR :: int(70)

Wizard :: struct {
    sprite: int,
    pos: [2]f32,
    t: int, // cumulative step / turn time
    action_i: int, // step action time normalized
    color: [4]f32,
    is_hit_t: int, // marked during action step, cleared on decrement to 0 or next step start
    health: int
}

Move_Type :: enum {
    step
}

player: Wizard
wizard_direction_request: Maybe(Direction) = nil
wizard_spell_request: Maybe(Spell) = nil
wizard_wait_request: bool = false

enemies: map[int]Wizard

get_player_sprite :: proc() -> ^Sprite 
{
	return &sprites[player.sprite]
}

handle_wizard_move :: proc(dir: Direction)
{
    if !is_stepping {
        wizard_direction_request = dir
    }
}

handle_wizard_wait :: proc()
{
    if !is_stepping {
        wizard_wait_request = true
    }
}

handle_wizard_spell :: proc(spell: Spell)
{
    if !is_stepping {
        wizard_spell_request = spell
    }
}

// enemies
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

get_grid_cell_to_player_path_next_coord :: proc(cell: [2]int) -> [2]int
{
	astar: AStar_Grid
	astar_grid_init(&astar)
	defer astar_grid_destroy(&astar)

	// Set the region to 12x12 for example. (Using a min and max vector allows it to support offset coordinates.)
	astar.region.min = {0, 0}
	astar.region.max = {i32(GAME_GRID_SIZE_X), i32(GAME_GRID_SIZE_Y)}

	// `astar_grid_clear` clears out any and all blocked/added-cost points in the grid.
	astar_grid_clear(&astar)

	// `astar_block` sets points on the grid as impassable.
    // astar_block(&astar, {0,1})
    // astar_block(&astar, {2,1})

	// // `astar_set_cost` can be used to add an additional cost value to a point, making it a less desirable point to visit.
    // 	pg.astar_set_cost(&astar, {2,0}, 3.)
    // 	pg.astar_set_cost(&astar, {1,1}, 1.)
    // 	pg.astar_set_cost(&astar, {3,1}, 100.)

	// `astar_get_path` gets you the set of points that A* calculates as the best path from your start point to your end point.
	// The result of `get_path` is just an array of `[2]i32`s. The second return value will return false if no path could be found.
	//
	// NOTE: By default, `get_path` allocates memory using `context.allocator`. You can pass your own allocator as an argument to change this.
	// This allocator is only used for the output slice, and not for anything internal to the pathfinding algorithm.
    sp := cell
    ep := pos_to_cell(player.pos)
	path, ok := astar_get_path(&astar, {i32(sp.x), i32(sp.y)}, {i32(ep.x), i32(ep.y)})
    defer { delete(path) }

	if ok && len(path) > 0 {
        next_move := path[0]
        return {int(next_move.x), int(next_move.y)}
	}
    fmt.println("warning: could not find astar path from %v to %v", sp, ep)
    return {0, 0}
}

