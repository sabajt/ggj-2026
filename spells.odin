package main

import "core:math/rand"
import "core:math"
import "core:fmt"

Projectile :: struct {
    t: int,
    dir: Direction,
    spr: int,
    pos: [2]f32,
    dur: int,
    type: Spell_Type,
    hostile: bool,
    action_i: int,
    shape_i: int
}

Spell :: union {
    Fire_Spell,
    Orb_Spell
}

Spell_Type :: enum {
    fire,
    orb
}

Fire_Spell :: struct {
    cell: [2]int,
    dir: Direction,
    hostile: bool,
    color: [4]f32
}

Orb_Spell :: struct {
    cell: [2]int,
    dir: Direction,
    hostile: bool,
    color: [4]f32
}

Kill_Particle :: enum {
    enemy_1,
    player
}

fires: map[int]Projectile
orbs : map[int]Projectile

spell_icon_name :: proc(spell: Spell) -> string
{
    result: string
    switch _ in spell {
        case Fire_Spell: result = "fire_0.png"
        case Orb_Spell: result = "orb.png"
    }
    return result
}

spell_title_text :: proc(spell: Spell) -> string
{
    result: string
    switch _ in spell {
        case Fire_Spell: result = "Fire (Cast)"
        case Orb_Spell: result = "Orb (Cast)"
    }
    return result
}

create_current_mask_spell :: proc(cell: [2]int, dir: Direction, wizard: Wizard) -> Spell
{
    mask := wizard.masks[wizard.cur_mask]
    hostile := wizard != player
    spell: Spell
    switch proto in mask.spell_prototype {
        case Fire_Spell:
            spell = Fire_Spell {
                cell = cell, 
                dir = dir, 
                hostile = hostile, 
                color = mask.color
            }
        case Orb_Spell:
            spell = Orb_Spell {
                cell = cell, 
                dir = dir, 
                hostile = hostile, 
                color = mask.color}
    }
    return spell
}

cast_fire_spell :: proc(spell: Fire_Spell)
{
    dir := spell.dir

    // adjacent to caster
    cell := cell_move(spell.cell, dir)
    add_fire(cell, dir, dur = 5 + rand.int_max(4), col = spell.color, hostile = spell.hostile)

    // move 4 direction out
    for i in 0 ..< 8 {
        cell = cell_move(cell, dir)
        add_fire(cell, dir, dur = 5 + rand.int_max(4), col = spell.color, hostile = spell.hostile)

        // 1 / 3 chance to have a branch left or right
        if rand.int_max(3) == 0 {
            branch_dir := rand.int_max(2) == 0 ? turn_left_90_deg(dir) : turn_right_90_deg(dir)
            branch_cell := cell
            for i in 0 ..< (3 + rand.int_max(4)) {
                branch_cell = cell_move(branch_cell, branch_dir)
                add_fire(branch_cell, branch_dir, dur = 3 + rand.int_max(3), col = spell.color, hostile = spell.hostile)
            }
        }
    }
}

add_kill_particle :: proc(pos: [2]f32, color: [4]f32, type: Kill_Particle)
{
    grow_effect_batch_if_needed()
    re_arr := &radius_effects[len(radius_effects) - 1]
    
    switch type {
        case .player:
            append(re_arr, create_kill_particle_1(pos, color))
        case .enemy_1:
            append(re_arr, create_kill_particle_2(pos, color))
    }
}

add_appear_particle :: proc(pos: [2]f32, color: [4]f32)
{
    grow_effect_batch_if_needed()
    re_arr := &radius_effects[len(radius_effects) - 1]
    append(re_arr, create_appear_particle(pos, color))
}

add_game_over_particle :: proc(pos: [2]f32, color: [4]f32)
{
    grow_effect_batch_if_needed()
    re_arr := &radius_effects[len(radius_effects) - 1]
    append(re_arr, create_game_over_particle(pos, color))
}

cast_orb_spell :: proc(s: Orb_Spell)
{
    add_orb(s.cell, s.dir, hostile = s.hostile , color = s.color)
}

add_fire :: proc(cell: [2]int, dir: Direction, dur: int = 5, col: [4]f32, hostile: bool) 
{
    pos := cell_pos(cell)
    spr := add_sprite("fire_0.png", pos, col = col, anchor = .bottom_left)
    fire := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        pos = pos,
        dur = dur,
        type = .fire,
        hostile = hostile
    }
    fires[spr] = fire
}

// TODO: calculate cell from position
// track position in model, not cell 
add_orb :: proc(cell: [2]int, dir: Direction, dur: int = 8, hostile: bool, color: [4]f32) -> int
{
    pos := cell_pos(cell)
    spr := add_sprite("orb.png", pos, col = color, anchor = .bottom_left)
    dir_indicator_i := add_shape({
		type = .Triangle,
		color = color,
		anchor = .center,
		z = 0,
		visible = false
	})
    orb := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        pos = pos,
        dur = dur,
        type = .orb,
        hostile = hostile,
        shape_i = dir_indicator_i
    }
    orbs[spr] = orb
    return spr
}

step_orbs :: proc()
{
    for k, &orb in orbs {
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
        orb.action_i = action_i
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

projectile_dir_indicator :: proc(projectile: Projectile)
{
    snap_ang: f32
    EIGTH_OF_PI := f32(math.PI / 8.0) 

    switch projectile.dir {
        case .north:
            snap_ang = 4 * EIGTH_OF_PI
        case .south:
            snap_ang = 12 * EIGTH_OF_PI
        case .west:
            snap_ang = math.PI
        case .east:
            snap_ang = 0
        case .northeast:
            snap_ang = 2 * EIGTH_OF_PI 
        case .northwest:
            snap_ang = 6 * EIGTH_OF_PI
        case .southeast:
            snap_ang = 14 * EIGTH_OF_PI 
        case .southwest:
            snap_ang = 10 * EIGTH_OF_PI 
    }

    tri_pos := pvec(
        ang = snap_ang, 
        radius = GRID_PADDING / 2.0 - 1, 
        center = projectile.pos + GRID_PADDING / 2.0
    )

    dir_indicator := &shapes[projectile.shape_i]
    dir_indicator.tf = tf(tri_pos, snap_ang - math.PI / 2.0 , {3, 3})
    dir_indicator.visible = true
}

