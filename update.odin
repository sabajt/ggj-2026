package main

// import 
import sdl "vendor:sdl3"

get_resolution :: proc () -> [2]f32 {
	s : [2]i32
	ok := sdl.GetWindowSize(window, &s.x, &s.y)
	assert(ok)
	return [2]f32 { f32(s.x), f32(s.y) }
}

update :: proc() 
{
    // update resolution from current window size
	resolution = get_resolution()
	letterbox_resolution = get_letterbox_res()

    // update player move request
    if wizard_direction_request != nil {   
        switch wizard_direction_request {
            case .left:
                player.cell = { player.cell.x - 1, player.cell.y }
            case .right:
                player.cell = { player.cell.x + 1, player.cell.y }  
            case .up:
                player.cell = { player.cell.x, player.cell.y + 1}
            case .down:
                player.cell = { player.cell.x, player.cell.y - 1}          
        }

        update_sprite(player.sprite, cell_pos(player.cell.x, player.cell.y))
        snap_sprite_to_latest_frame(player.sprite)

        wizard_direction_request = nil
    }
}