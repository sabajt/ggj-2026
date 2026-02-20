package main

import "core:math/rand"
import "core:fmt"

Projectile :: struct {
    t: int,
    dir: Direction,
    spr: int,
    pos: [2]f32,
    dur: int,
    type: Spell_Type,
    hostile: bool
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

fires: map[int]Projectile
orbs : map[int]Projectile

spell_icon_name :: proc(spell_type: Spell_Type) -> string
{
    result: string
    switch spell_type {
        case .fire: result = "fire_0.png"
        case .orb: result = "orb.png"
    }
    return result
}

spell_title_text :: proc(spell_type: Spell_Type) -> string
{
    result: string
    switch spell_type {
        case .fire: result = "Fire (Cast)"
        case .orb: result = "Orb (Cast)"
    }
    return result
}

create_current_mask_spell :: proc(cell: [2]int, dir: Direction) -> Spell
{
    mask := masks[mask_index]
    spell: Spell
    switch mask.spell_type {
        case .fire:
            spell =  Fire_Spell {cell=cell, dir=dir, hostile=false, color=mask.color}
        case .orb:
            spell = Orb_Spell {cell=cell, dir=dir, hostile=false, color=mask.color}
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
        hostile = hostile
    }
    fires[spr] = fire
}

// TODO: calculate cell from position
// track position in model, not cell 
add_orb :: proc(cell: [2]int, dir: Direction, dur: int = 20, hostile: bool, color: [4]f32) -> int
{
    pos := cell_pos(cell)
    spr := add_sprite("orb.png", pos, col = color, anchor = .bottom_left)
    orb := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        pos = pos,
        dur = dur,
        hostile = hostile
    }
    orbs[spr] = orb
    return spr
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
