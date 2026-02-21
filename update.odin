package main

// import 
import sdl "vendor:sdl3"
import "core:fmt"
import "core:math"
import "core:math/rand"

ACTION_DUR :: int(8)
ACTION_POST_STEP_DUR :: int(3)

flash_on := true
actions: map[int]Action
action_i := 0
action_step_t: int = 0
action_post_step_t: int = 0
is_stepping: bool = false
is_game_over: bool = false
game_over_delay: int = GAME_OVER_DELAY_DUR
killed_by: ^Sprite 
enemy_hit: int // last enemy hit (will need to refactor for many)

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
    enemy.action_i = action_i
    action_i += 1
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
    check_input()

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
    // player initiate step with wait
    if wizard_wait_request {
        wizard_wait_request = false
        is_stepping = true
    }

    // player initiate step with spell cast
    if spell, ok := wizard_spell_request.?; ok {         
        wizard_spell_request = nil
        is_stepping = true
        
        mask := get_current_mask()
        mask.spell_cool_t = mask.spell_cool_dur + 1
        
        switch s in spell {
            case Fire_Spell:
                cast_fire_spell(s)
            case Orb_Spell:
                cast_orb_spell(s)
        }
    }

    if is_stepping {
        // check for hits before adding actions, otherwise killed enemy might add action
        check_hits()

        // add any world step actions
        if action_step_t == 0 {
            step_enemies()
            step_orbs()
            step_fire()       
            step_mask_cooldowns()
        }

        // update / animate step: steps currently remove themselves when finished
        action_step_t += 1
        update_actions()

        // finish step
        if action_step_t == ACTION_DUR {
            action_step_t = 0
            action_post_step_t = 0
            is_stepping = false
        }
    } else {
        if action_post_step_t < ACTION_POST_STEP_DUR {
            action_post_step_t += 1
        }
    }

    if is_game_over {
        if game_over_delay == GAME_OVER_DELAY_DUR {
            snap_all_sprites_to_latest_frame()
        }
    }
}

step_mask_cooldowns :: proc()
{
    for &mask in masks {
        mask.spell_cool_t = max(0, mask.spell_cool_t - 1)
    }
    update_rhs_menu_spell_cooldown_text()
    update_rhs_menu_spell_title_text()
    update_rhs_spell_icon()
}

update_rhs_spell_icon :: proc()
{
    mask := get_current_mask()^
    sprite := get_spell_icon_sprite()
	sprite.name = spell_icon_name(mask.spell_type)
	sprite.col = mask_spell_cooldown_color(mask)
}

update_rhs_menu_spell_cooldown_text :: proc()
{
    mask := get_current_mask()^
    update_text_item(rhs_menu_spell_cooldown_text_i, mask_spell_cooldown_number_text(mask), mask.color)
}

update_rhs_menu_spell_title_text :: proc()
{
    mask := get_current_mask()^
    update_text_item(rhs_menu_spell_title_text_i, spell_title_text(mask.spell_type), mask_spell_cooldown_color(mask))
}


step_enemies :: proc()
{
    if enemy.t % 3 == 0 {
        cell := pos_to_cell(enemy.pos)
        for dir in DIRECTIONS {
            spell := Orb_Spell {
                cell=cell, 
                dir=dir, 
                hostile=true,
                color=enemy_col
            }
            cast_orb_spell(spell)
        }
    } else {
        cell := get_enemy_player_path_next_coord()
        add_enemy_move_action(cell)
    }
    enemy.t += 1
}

find_empty_spawn_cell :: proc() -> [2]int
{
    x := WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_X - WIZARD_PAD)
    y := WIZARD_PAD + rand.int_max(GAME_GRID_SIZE_Y - WIZARD_PAD)
    cell := [2]int{x, y}

    if cell == pos_to_cell(player.pos) {
        find_empty_spawn_cell()
    }
    for k, fire in fires {
        if pos_to_cell(fire.pos) == cell {
            return find_empty_spawn_cell()
        }
    }
    return cell
}

check_hits :: proc()
{
    // projectiles
    for k, projectile in fires {
        check_projectile_hit(projectile)
    }
    for k, projectile in orbs {
        check_projectile_hit(projectile)
    }

    // reset if enemy hits player directly
    if grid_item_collide(enemy.pos, player.pos) {
        is_game_over = true
        killed_by = &sprites[enemy.sprite]
        return
    }
}

check_projectile_hit :: proc(projectile: Projectile) 
{
    if projectile.hostile {
        // reset if orbs hits player
        if grid_item_collide(projectile.pos, player.pos) {
            is_game_over = true
            killed_by = &sprites[projectile.spr]
            return
        }
    } else {
        // destroy enemy
        if grid_item_collide(projectile.pos, enemy.pos) {
            // TODO: add flashing hit indicator

            // remove enemy
            delete_key(&sprites, enemy.sprite)
            delete_key(&actions, enemy.action_i)

            // next enemy
            cell := find_empty_spawn_cell()
            add_enemy(cell)
        }
    }
}
