package main

import "core:fmt"

Wizard :: struct {
    sprite: int,
    cell: [2]int
}

Spell :: enum {
    fire_tree
}

wizard_direction_request: Maybe(Direction) = nil
wizard_spell_request: Maybe(Spell) = nil
wizard_wait_request: bool = false

player: Wizard

handle_wizard_move :: proc(dir: Direction)
{
    wizard_direction_request = dir
}

handle_wizard_wait :: proc()
{
    wizard_wait_request = true
}

handle_wizard_spell :: proc(spell: Spell)
{
    wizard_spell_request = spell
}

step_game :: proc()
{
    step_spells()
    step_enemies()
}

// Direction

Direction :: enum { up, down, left, right }
DIRECTIONS :: [4]Direction { .up, .down, .left, .right }

turn_left :: proc(facing: Direction) -> Direction {
    result: Direction
    switch facing {
        case .left: result = .down
        case .down: result = .right
        case .right: result = .up
        case .up: result = .left
    }
    return result
}

turn_right :: proc(facing: Direction) -> Direction {
    result: Direction
    switch facing {
        case .left: result = .up
        case .down: result = .left
        case .right: result = .down
        case .up: result = .right
    }
    return result
}

// enemies

enemy: Wizard

step_enemies :: proc()
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
    astar_block(&astar, {0,1})
    astar_block(&astar, {2,1})

	// // `astar_set_cost` can be used to add an additional cost value to a point, making it a less desirable point to visit.
    // 	pg.astar_set_cost(&astar, {2,0}, 3.)
    // 	pg.astar_set_cost(&astar, {1,1}, 1.)
    // 	pg.astar_set_cost(&astar, {3,1}, 100.)

	// `astar_get_path` gets you the set of points that A* calculates as the best path from your start point to your end point.
	// The result of `get_path` is just an array of `[2]i32`s. The second return value will return false if no path could be found.
	//
	// NOTE: By default, `get_path` allocates memory using `context.allocator`. You can pass your own allocator as an argument to change this.
	// This allocator is only used for the output slice, and not for anything internal to the pathfinding algorithm.
    sp := enemy.cell
    ep := player.cell
	path, ok := astar_get_path(&astar, {i32(sp.x), i32(sp.y)}, {i32(ep.x), i32(ep.y)})
    defer { delete(path) }

	if ok {
        fmt.println()
		for p,i in path {
			fmt.printf("{}: {}", i, p)
		}
	}
}


