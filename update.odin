package main

// import 
import sdl "vendor:sdl3"
import "core:fmt"
import "core:math"
import "core:math/rand"

ACTION_DUR :: int(7)

flash_on := true
actions := make(map[int]Action)
action_i := 0
action_step_t: int = 0
is_stepping: bool = false
is_game_over: bool = false
game_over_delay: int = GAME_OVER_DELAY_DUR
killed_by: ^Sprite 

// actions

Action :: struct {
    i: int,
    update: proc(action: ^Action),
    data: Action_Data
}

Action_Data :: struct {
    obj_id: int,
    start_cell: [2]int,
    end_cell: [2]int,
}

add_player_move_action :: proc(dir: Direction)
{
    start_cell := pos_to_cell(player.pos)
    end_cell := cell_move(start_cell, dir)

    action := Action {
        i = action_i,
        update = action_update_player_move,
        data = { start_cell = start_cell, end_cell = end_cell}
    }
    actions[action_i] = action
    action_i += 1
}

add_enemy_move_action :: proc(dest: [2]int)
{
    action := Action {
        i = action_i,
        update = action_update_enemy_move,
        data = { start_cell = pos_to_cell(enemy.pos), end_cell = dest}
    }
    actions[action_i] = action
    action_i += 1
}

cast_orb_spell :: proc(cell: [2]int)
{
    for dir in DIRECTIONS {
        add_orb(cell, dir)
    }
}

cast_fire_spell :: proc(cell: [2]int)
{
    for dir in DIRECTIONS {
        // adjacent to player
        cell := cell_move(cell, dir)
        add_fire(cell, dir, dur = 5 + rand.int_max(4), col = COL_LEMON_LIME)

        // move 4 direction out
        for i in 0 ..< 8 {
            cell = cell_move(cell, dir)
            add_fire(cell, dir, dur = 5 + rand.int_max(4), col = COL_LEMON_LIME)

            // 1 / 3 chance to have a branch left or right
            if rand.int_max(3) == 0 {
                branch_dir := rand.int_max(2) == 0 ? turn_left(dir) : turn_right(dir)
                branch_cell := cell
                for i in 0 ..< (3 + rand.int_max(4)) {
                    branch_cell = cell_move(branch_cell, branch_dir)
                    add_fire(branch_cell, branch_dir, dur = 3 + rand.int_max(3), col = COL_LEMON_LIME)
                }
            }
        }
    }
}

action_update_player_move :: proc(action: ^Action) 
{
    if action_step_t == ACTION_DUR {
        delete_key(&actions, action.i)
        sprite := &sprites[player.sprite]
        player.pos = cell_pos(action.data.end_cell)
        update_sprite(sprite, player.pos)
        snap_sprite_to_latest_frame(sprite)
        
    } else {
        sprite := &sprites[player.sprite]
        t := f32(action_step_t) / f32(ACTION_DUR)
        player.pos = math.lerp(cell_pos(action.data.start_cell), cell_pos(action.data.end_cell), t)
        update_sprite(sprite, player.pos)
    }
}

action_update_enemy_move :: proc(action: ^Action) 
{
    if action_step_t == ACTION_DUR {
        delete_key(&actions, action.i)
        sprite := &sprites[enemy.sprite]
        enemy.pos = cell_pos(action.data.end_cell)
        update_sprite(sprite, enemy.pos)
        snap_sprite_to_latest_frame(sprite)
    } else {
        sprite := &sprites[enemy.sprite]
        t := f32(action_step_t) / f32(ACTION_DUR)
        enemy.pos = math.lerp(cell_pos(action.data.start_cell), cell_pos(action.data.end_cell), t)
        update_sprite(sprite, enemy.pos)
    }
}

action_update_orb :: proc(action: ^Action) 
{
    obj_id := action.data.obj_id
    sprite := &sprites[obj_id]
    orb := &orbs[obj_id]

    if action_step_t == ACTION_DUR {
        delete_key(&actions, action.i)

        orb.pos = cell_pos(action.data.end_cell)
        update_sprite(sprite, cell_pos(action.data.end_cell))
        snap_sprite_to_latest_frame(sprite)

        orb.t -= 1
        if orb.t == 0 {
            delete_key(&sprites, obj_id)
            delete_key(&orbs, obj_id)
        } 
    } else {
        t := f32(action_step_t) / f32(ACTION_DUR)
        pos := math.lerp(cell_pos(action.data.start_cell), cell_pos(action.data.end_cell), t)

        col := sprite.col
        col_alpha_start := f32(orb.t) / f32(orb.dur)
        col_alpha_end :=  f32(orb.t - 1) / f32(orb.dur)
        col.a = math.lerp(col_alpha_start, col_alpha_end, t)

        orb.pos = pos
        update_sprite(sprite, pos, col = col)
    }
}

update_actions :: proc()
{
    for k, &action in actions {
        action.update(&action)
    }
}

// resolution

get_resolution :: proc () -> [2]f32 
{
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

    defer {
        // update step time and common step vars
        game_step_time += 1

        if game_step_time % 5 == 0 {
            flash_on = !flash_on
        }
    }

    if is_game_over {
        game_over_delay -= 1
        if game_over_delay == 0 {
            reset_game()
        } else {
            // animate enemy and player
            // enemy_sprite := &sprites[enemy.sprite]
            killed_by.col.a = flash_on ? 1 : 0.2

            player_sprite := &sprites[player.sprite]
            player_sprite.col.a = flash_on ? 1 : 0.2
        }
        return
    }

    // player initiate step with movement
    if dir, ok := wizard_direction_request.?; ok { 
        wizard_direction_request = nil
        add_player_move_action(dir)
        is_stepping = true
    }

    // player initiate step with spell cast
    if spell, ok := wizard_spell_request.?; ok {         
        wizard_spell_request = nil
        cast_fire_spell(pos_to_cell(player.pos))
        is_stepping = true
    }

    if is_stepping {
        // add any world step actions
        if action_step_t == 0 {
            step_enemies()
            step_orbs()
            step_fire()
        }

        // update / animate step: steps currently remove themselves when finished
        action_step_t += 1
        update_actions()

        // finish step
        if action_step_t == ACTION_DUR {
            action_step_t = 0
            is_stepping = false
        }

        check_hits()
    }
}

step_enemies :: proc()
{
    if enemy.t % 3 == 0 {
        cell := pos_to_cell(enemy.pos)
        cast_orb_spell(cell)
    } else {
        cell := get_enemy_player_path_next_coord()
        add_enemy_move_action(cell)
    }
    enemy.t += 1
}

step_orbs :: proc()
{
    for k, orb in orbs {
        // move outward
        cur := pos_to_cell(orb.pos)
        dest := cell_move(cur, orb.dir)

        action := Action {
            i = action_i,
            update = action_update_orb,
            data = { 
                start_cell = cur, 
                end_cell = dest,
                obj_id = orb.spr
            }
        }
        actions[action_i] = action
        action_i += 1
    }
}

step_fire :: proc()
{
    for key, &fire in fires {
        fire.t -= 1
        if fire.t == 0 {
            delete_key(&sprites, key)
            delete_key(&fires, key)
        } else {
            // fire.cell = cell_move(fire.cell, fire.dir)
            sprite := &sprites[key]
            col := sprite.col
            col.a = f32(fire.t + 1) / f32(fire.dur)
            update_sprite(sprite, col = col)
            snap_sprite_to_latest_frame(sprite)
        }
    }
}

check_hits :: proc()
{
    // reset if orbs hits player
    for k, orb in orbs {
        if grid_item_collide(orb.pos, player.pos) {
            snap_all_sprites_to_latest_frame()
            is_game_over = true
            killed_by = &sprites[orb.spr]
            return
        }
    }
    // reset if enemy hits player
    if grid_item_collide(enemy.pos, player.pos) {
        snap_all_sprites_to_latest_frame()
        is_game_over = true
        killed_by = &sprites[enemy.sprite]
        return
    }
}

// old_update :: proc() 
// {
//     update_resolutions()

//     // update player move request
//     if dir, ok := wizard_direction_request.?; ok { 
//         player.cell = cell_move(player.cell, dir)
//         spr := &sprites[player.sprite]
//         update_sprite(spr, cell_pos(player.cell))
//         snap_sprite_to_latest_frame(spr)

//         step_game()
//         wizard_direction_request = nil
//     }

//     if wizard_wait_request { 
//         step_game()
//         wizard_wait_request = false
//     }

//     // update player spell request

//     if spell, ok := wizard_spell_request.?; ok { 
//         create_spell(spell)
//         step_game()

//         wizard_spell_request = nil
//     }

//     // animate enemy and player

//     enemy_sprite := &sprites[enemy.sprite]
//     enemy_sprite.col.a = flash_on ? 1 : 0.2

//     player_sprite := &sprites[player.sprite]
//     player_sprite.col.a = flash_on ? 1 : 0.2

//     // update step time and common step vars

//     if game_step_time % 8 == 0 {
//         flash_on = !flash_on
//     }
//     game_step_time += 1
// }

