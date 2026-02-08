package main

// import 
import sdl "vendor:sdl3"
import "core:fmt"
import "core:math"

ACTION_DUR :: int(7)

flash_on := true

// actions

Action :: struct {
    i: int,
    update: proc(action: ^Action),
    data: Action_Data
}

Action_Data :: struct {
    start_cell: [2]int,
    end_cell: [2]int
}

actions := make(map[int]Action)
action_i := 0

add_player_move_action :: proc(dest: [2]int)
{
    action := Action {
        i = action_i,
        update = action_update_player_move,
        data = { start_cell = player.cell, end_cell = dest}
    }
    actions[action_i] = action
    action_i += 1
}

add_enemy_move_action :: proc(dest: [2]int)
{
    action := Action {
        i = action_i,
        update = action_update_enemy_move,
        data = { start_cell = enemy.cell, end_cell = dest}
    }
    actions[action_i] = action
    action_i += 1
}

action_update_player_move :: proc(action: ^Action) 
{
    if action_step_t == ACTION_DUR {
        delete_key(&actions, action.i)
        sprite := &sprites[player.sprite]
        player.cell = action.data.end_cell
        update_sprite(sprite, cell_pos(player.cell))
        snap_sprite_to_latest_frame(sprite)
    } else {
        sprite := &sprites[player.sprite]
        t := f32(action_step_t) / f32(ACTION_DUR)
        pos := math.lerp(cell_pos(action.data.start_cell), cell_pos(action.data.end_cell), t)
        update_sprite(sprite, pos)
    }
}

action_update_enemy_move :: proc(action: ^Action) 
{
    if action_step_t == ACTION_DUR {
        delete_key(&actions, action.i)
        sprite := &sprites[enemy.sprite]
        enemy.cell = action.data.end_cell
        update_sprite(sprite, cell_pos(enemy.cell))
        snap_sprite_to_latest_frame(sprite)
    } else {
        sprite := &sprites[enemy.sprite]
        t := f32(action_step_t) / f32(ACTION_DUR)
        pos := math.lerp(cell_pos(action.data.start_cell), cell_pos(action.data.end_cell), t)
        update_sprite(sprite, pos)
    }
}

        // enemy_sprite := &sprites[enemy.sprite]
        // enemy.cell = {int(next_move.x), int(next_move.y)}
        // update_sprite(enemy_sprite, cell_pos(enemy.cell))
        // snap_sprite_to_latest_frame(enemy_sprite)



update_actions :: proc()
{
    for k, &action in actions {
        action.update(&action)
    }
}

// resolution

get_resolution :: proc () -> [2]f32 {
	s : [2]i32
	ok := sdl.GetWindowSize(window, &s.x, &s.y)
	assert(ok)
	return [2]f32 { f32(s.x), f32(s.y) }
}


update_resolutions :: proc()
{
    // update resolution from current window size
	resolution = get_resolution()
	letterbox_resolution = get_letterbox_res()
}

// general update

update :: proc() 
{
    update_resolutions()

    // initiate stepping state: no input processed 
    // calculate next step for all objects: moves, attacks etc
    // execute the step animated over time and check any collisions (try actual collision boxes?)
    // arrive at the next state and restore input 

    // player initiate step with movement
    if dir, ok := wizard_direction_request.?; ok { 
        wizard_direction_request = nil

        dest_cell := cell_move(player.cell, dir)
        add_player_move_action(dest_cell)

        is_stepping = true
    }

    if is_stepping {

        if action_step_t == 0 {
            // add world step actions
            // step_enemies
            coord := get_enemy_player_path_next_coord()
            add_enemy_move_action(coord)
        }

        action_step_t += 1
        update_actions()

        if action_step_t == ACTION_DUR {
            action_step_t = 0
            is_stepping = false
        }
    }
}

action_step_t: int = 0
is_stepping: bool = false

old_update :: proc() 
{
    update_resolutions()

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

