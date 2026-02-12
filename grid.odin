package main

import "core:math"

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
        case .left:
            result = { cell.x - 1, cell.y }
        case .right:
            result = { cell.x + 1, cell.y }  
        case .up:
            result = {cell.x, cell.y + 1}
        case .down:
            result = { cell.x, cell.y - 1}          
    }
    return result
}

grid_item_collide :: proc(p0: [2]f32, p1: [2]f32) -> bool
{
    rad := GRID_PADDING / 2.0
    return collide(p0, rad, p1, rad)
}

