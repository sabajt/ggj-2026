package main

cell_pos :: proc(x: int, y: int) -> [2]f32
{
	return { f32(x) * GRID_PADDING, f32(y) * GRID_PADDING } 
}
