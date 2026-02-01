package main

// import 
import sdl "vendor:sdl3"

flash_on := true

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
        step_game()

        wizard_spell_request = nil
    }

    // animate enemy and player

    enemy_sprite := &sprites[enemy.sprite]
    enemy_sprite.col.a = flash_on ? 1 : 0.2

    player_sprite := &sprites[player.sprite]
    player_sprite.col.a = flash_on ? 1 : 0.2

    // update step time and common step vars

    if game_step_time % 8 == 0 {
        flash_on = !flash_on
    }
    game_step_time += 1
}

