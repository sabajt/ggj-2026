package main

cell_pos :: proc(cell: [2]int) -> [2]f32
{
	return { f32(cell.x) * GRID_PADDING, f32(cell.y) * GRID_PADDING } 
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
