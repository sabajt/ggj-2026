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
    if dir, ok := wizard_direction_request.?; ok { 
        player.cell = cell_move(player.cell, dir)
        spr := &sprites[player.sprite]
        update_sprite(spr, cell_pos(player.cell))
        snap_sprite_to_latest_frame(spr)

        step_game()
        wizard_direction_request = nil
    }

    if wizard_wait_request { 
        step_game()
        wizard_wait_request = false
    }

    // update player spell request
    if spell, ok := wizard_spell_request.?; ok { 
        create_spell(spell)

        wizard_spell_request = nil
    }
}