package main

import "core:math"

// GRID_OFFSET := [2]f32 {UI_DIVIDER_1, UI_DIVIDER_1}

Direction :: enum { north, south, west, east, northeast, northwest, southeast, southwest }
DIRECTIONS :: [8]Direction { .north, .south, .west, .east, .northeast, .northwest, .southeast, .southwest }

turn_left_90_deg :: proc(facing: Direction) -> Direction 
{
    result: Direction
    switch facing {
        case .west: result = .south
        case .south: result = .east
        case .east: result = .north
        case .north: result = .west
        case .northwest: result = .southwest
        case .southwest: result = .southeast
        case .southeast: result = .northeast
        case .northeast: result = .northwest

    }
    return result
}

turn_right_90_deg :: proc(facing: Direction) -> Direction 
{
    result: Direction
    switch facing {
        case .west: result = .north
        case .south: result = .west
        case .east: result = .south
        case .north: result = .east
        case .northwest: result = .northeast
        case .northeast: result = .southeast
        case .southeast: result = .southwest
        case .southwest: result = .northwest
    }
    return result
}

cell_pos :: proc(cell: [2]int) -> [2]f32
{
	return { 
        f32(cell.x) * GRID_PADDING, 
        f32(cell.y) * GRID_PADDING 
    } 
}

pos_to_cell :: proc(pos: [2]f32) -> [2]int
{
    return {
        int(math.floor(pos.x / GRID_PADDING)),
        int(math.floor(pos.y / GRID_PADDING))
    }
}

cell_move :: proc(cell: [2]int, dir: Direction) -> [2]int
{
    result: [2]int
    switch dir {
        case .west:
            result = { cell.x - 1, cell.y }
        case .east:
            result = { cell.x + 1, cell.y }  
        case .north:
            result = {cell.x, cell.y + 1}
        case .south:
            result = { cell.x, cell.y - 1}    
        case .northwest:
            result = { cell.x - 1, cell.y + 1 }  
        case .northeast:
            result = { cell.x + 1, cell.y + 1 } 
        case .southwest:
            result = { cell.x - 1, cell.y - 1 }   
        case .southeast:
            result = { cell.x + 1, cell.y - 1 }        
    }
    return result
}

grid_item_collide :: proc(p0: [2]f32, p1: [2]f32) -> bool
{
    rad := GRID_PADDING / 3.0
    return collide(p0, rad, p1, rad)
}

