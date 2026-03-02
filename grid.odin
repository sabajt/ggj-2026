package main

import "core:math"

// GRID_OFFSET := [2]f32 {UI_DIVIDER_1, UI_DIVIDER_1}
Direction :: enum { north, south, west, east, northeast, northwest, southeast, southwest }
Direction_Info :: struct {
    direction: Direction,
    angle: f32
} 
DIRECTIONS :: [8]Direction { .north, .south, .west, .east, .northeast, .northwest, .southeast, .southwest }
CARDINALS :: [4]Direction { .north, .south, .west, .east }
ORDINALS :: [4]Direction { .northeast, .northwest, .southeast, .southwest }

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

snap_direction_info :: proc(ang: f32) -> Direction_Info
{
    info: Direction_Info
    snap_ang: f32
    EIGTH_OF_PI := f32(math.PI / 8.0) 
    if ang >= math.TAU - EIGTH_OF_PI || ang < EIGTH_OF_PI {
        info = {
            direction = .east,
            angle = 0
        }
    } else if ang >= EIGTH_OF_PI && ang < 3 * EIGTH_OF_PI {
        info = {
            direction = .northeast,
            angle = 2 * EIGTH_OF_PI 
        }
    } else if ang >= 3 * EIGTH_OF_PI && ang < 5 * EIGTH_OF_PI {
        info = {
            direction = .north,
            angle = 4 * EIGTH_OF_PI 
        }

    } else if ang >= 5 * EIGTH_OF_PI && ang < 7 * EIGTH_OF_PI {
        info = {
            direction = .northwest,
            angle = 6 * EIGTH_OF_PI 
        }

    } else if ang >= 7 * EIGTH_OF_PI && ang < 9 * EIGTH_OF_PI {
        info = {
            direction = .west,
            angle = math.PI
        }
    } else if ang >= 9 * EIGTH_OF_PI && ang < 11 * EIGTH_OF_PI {
        info = {
            direction = .southwest,
            angle = 10 * EIGTH_OF_PI 
        }
    } else if ang >= 11 * EIGTH_OF_PI && ang < 13 * EIGTH_OF_PI {
        snap_ang = 12 * EIGTH_OF_PI
        facing_dir = .south
        info = {
            direction = .south,
            angle = 12 * EIGTH_OF_PI 
        }
    } else if ang >= 13 * EIGTH_OF_PI && ang < 15 * EIGTH_OF_PI {
        info = {
            direction = .southeast,
            angle = 14 * EIGTH_OF_PI 
        }
    }
    return info
}

