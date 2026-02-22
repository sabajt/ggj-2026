package main

// import 
import sdl "vendor:sdl3"
import "core:fmt"
import "core:math"
import "core:math/rand"

ACTION_DUR :: int(8)
ACTION_POST_STEP_DUR :: int(3)

flash_5_on := true
flash_8_on := true
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

add_enemy_move_action :: proc(i: int, dest: [2]int)
{
    enemy := &enemies[i]
    action := Action {
        i = action_i,
        update = action_update_enemy_move,
        data = { obj_id = i, start_cell = pos_to_cell(enemy.pos), end_cell = dest}
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
    enemy := &enemies[action.data.obj_id]
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
            flash_5_on = !flash_5_on
        }
        if game_step_time % 8 == 0 {
            flash_8_on = !flash_8_on
        }
    }

    if is_game_over {
        game_over_delay -= 1
        if game_over_delay == 0 {
            reset_game()
        } else {
            // animate enemy and player
            // enemy_sprite := &sprites[enemy.sprite]
            killed_by.col.a = flash_5_on ? 1 : 0.2

            player_sprite := &sprites[player.sprite]
            player_sprite.col.a = flash_5_on ? 1 : 0.2
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
        // add any world step actions, beginning of action setup
        if action_step_t == 0 {
            step_action_begin()
        }
        check_hits()

        // update / animate step: steps currently remove themselves when finished
        action_step_t += 1
        update_actions()

        // finish step
        if action_step_t == ACTION_DUR {
            step_action_end()
        }
    } else {
        if action_post_step_t < ACTION_POST_STEP_DUR {
            action_post_step_t += 1
        }
    }

    // flash UI where needed
    if current_mask_spell_ready() {
        mask := get_current_mask()^
        color := mask.color
        color.a = flash_8_on ? 1 : 0.2
        update_text_item(rhs_menu_spell_cooldown_text_i, mask_spell_cooldown_number_text(mask), color)
    }

    // decrement hit_t and flash hit actors
    for k, &enemy in enemies {
        enemy.is_hit_t = max(0, enemy.is_hit_t - 1)
        sprite := &sprites[enemy.sprite]
        color := sprite.col
        if enemy.is_hit_t > 0 {
            color.a = flash_5_on ? 0.2 : 1
        } else {
            color.a = 1
        }
        update_sprite(sprite, col = color)
    }

    if is_game_over {
        if game_over_delay == GAME_OVER_DELAY_DUR {
            snap_all_sprites_to_latest_frame()
        }
    }
}

step_action_begin :: proc()
{
    begin_step_enemies()
    step_enemies()
    step_orbs()
    step_fire()       
    step_mask_cooldowns()
}

step_action_end :: proc()
{
    action_step_t = 0
    action_post_step_t = 0
    is_stepping = false
}

begin_step_enemies :: proc()
{
    for k, &enemy in enemies {
        enemy.is_hit_t = 0
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
    for k, &enemy in enemies {
        cell := pos_to_cell(enemy.pos)
        if enemy.t % 3 == 0 {
            for dir in CARDINALS {
                spell := Orb_Spell {
                    cell=cell, 
                    dir=dir, 
                    hostile=true,
                    color=enemy.color
                }
                cast_orb_spell(spell)
            }
        } else {
            cell := get_grid_cell_to_player_path_next_coord(cell)
            add_enemy_move_action(i = k, dest = cell)
        }
        enemy.t += 1
    }
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

    // enemy
    for k, &enemy in enemies {
        // TODO: checking enemy.is_hit_t == 0 makes enemy not attack on this step - wanted?
        if enemy.is_hit_t == 0 && grid_item_collide(enemy.pos, player.pos) { 
            is_game_over = true
            killed_by = &sprites[enemy.sprite]
            return
        }
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
        for k, &enemy in enemies {
            // hit enemy
            if enemy.is_hit_t == 0 && grid_item_collide(projectile.pos, enemy.pos) {
                enemy.is_hit_t = ACTOR_HIT_T_DUR
                enemy.health -= 1
                if enemy.health <= 0 {
                    destroy_enemy(enemy)
                }
            }
        }
    }
}

destroy_enemy :: proc(enemy: Wizard)
{
    // remove enemy
    delete_key(&sprites, enemy.sprite)
    delete_key(&actions, enemy.action_i)
    delete_key(&enemies, enemy.sprite)
    
    // next enemies
    for i in 0 ..< 2 {
        cell := find_empty_spawn_cell()
        add_enemy(cell)
    }
}


