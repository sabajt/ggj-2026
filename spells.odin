package main

import "core:math/rand"

Projectile :: struct {
    t: int,
    dir: Direction,
    spr: int,
    cell: [2]int,
    dur: int
}

fires := make(map[int]Projectile)
orbs := make(map[int]Projectile)

create_spell :: proc(spell: Spell)
{
    switch spell {
        case .fire_tree:
            create_fire_tree_spell()
        case .orb:
            create_orb_spell(player.cell)
    }
}

@(private) create_fire_tree_spell :: proc() 
{    
    for dir in DIRECTIONS {
        // adjacent to player
        cell := cell_move(player.cell, dir)
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

add_fire :: proc(cell: [2]int, dir: Direction, dur: int = 5, col: [4]f32) 
{
    spr := add_sprite("fire.png", cell_pos(cell), col = col, anchor = .bottom_left)
    fire := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        cell = cell,
        dur = dur
    }
    fires[spr] = fire
}

create_orb_spell :: proc(cast_cell: [2]int) 
{    
    for dir in DIRECTIONS {
        // adjacent to player
        cell := cell_move(cast_cell, dir)
        add_orb(cell, dir)
    }
}

add_orb :: proc(cell: [2]int, dir: Direction, dur: int = 20) 
{
    spr := add_sprite("orb.png", cell_pos(cell), col = enemy_col, anchor = .bottom_left)
    orb := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        cell = cell,
        dur = dur
    }
    orbs[spr] = orb
}

step_spells :: proc()
{
    step_fire()
    step_orb()
}

step_fire :: proc()
{
    for key, &fire in fires {
        fire.t -= 1
        if fire.t == 0 {
            delete_key(&sprites, key)
            delete_key(&fires, key)
        } else {
            fire.cell = cell_move(fire.cell, fire.dir)
            sprite := &sprites[key]
            col := sprite.col
            col.a = f32(fire.t + 1) / f32(fire.dur)
            update_sprite(sprite, cell_pos(fire.cell), col = col)
            snap_sprite_to_latest_frame(sprite)
        }
    }
}

step_orb :: proc()
{
    for key, &orb in orbs {
        orb.t -= 1
        if orb.t == 0 {
            delete_key(&sprites, key)
            delete_key(&orbs, key)
        } else {
            orb.cell = cell_move(orb.cell, orb.dir)
            sprite := &sprites[key]
            col := sprite.col
            col.a = f32(orb.t + 1) / f32(orb.dur)
            update_sprite(sprite, cell_pos(orb.cell), col = col)
            snap_sprite_to_latest_frame(sprite)
        }
    }
}
