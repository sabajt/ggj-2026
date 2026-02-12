package main

import "core:math/rand"
import "core:fmt"

Projectile :: struct {
    t: int,
    dir: Direction,
    spr: int,
    pos: [2]f32,
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
            fmt.println("unhandled spell: orb")
    }
}

@(private) create_fire_tree_spell :: proc() 
{    
    // for dir in DIRECTIONS {
    //     // adjacent to player
    //     cell := cell_move(player.cell, dir)
    //     add_fire(cell, dir, dur = 5 + rand.int_max(4), col = COL_LEMON_LIME)

    //     // move 4 direction out
    //     for i in 0 ..< 8 {
    //         cell = cell_move(cell, dir)
    //         add_fire(cell, dir, dur = 5 + rand.int_max(4), col = COL_LEMON_LIME)

    //         // 1 / 3 chance to have a branch left or right
    //         if rand.int_max(3) == 0 {
    //             branch_dir := rand.int_max(2) == 0 ? turn_left(dir) : turn_right(dir)
    //             branch_cell := cell
    //             for i in 0 ..< (3 + rand.int_max(4)) {
    //                 branch_cell = cell_move(branch_cell, branch_dir)
    //                 add_fire(branch_cell, branch_dir, dur = 3 + rand.int_max(3), col = COL_LEMON_LIME)
    //             }
    //         }
    //     }
    // }
}

add_fire :: proc(cell: [2]int, dir: Direction, dur: int = 5, col: [4]f32) 
{
    pos := cell_pos(cell)
    spr := add_sprite("fire_0.png", pos, col = col, anchor = .bottom_left)
    fire := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        pos = pos,
        dur = dur
    }
    fires[spr] = fire
}

// TODO: calculate cell from position
// track position in model, not cell
add_orb :: proc(cell: [2]int, dir: Direction, dur: int = 20) -> int
{
    pos := cell_pos(cell)
    spr := add_sprite("orb.png", pos, col = enemy_col, anchor = .bottom_left)
    orb := Projectile {
        t = dur,
        dir = dir,
        spr = spr,
        pos = pos,
        dur = dur
    }
    orbs[spr] = orb
    return spr
}

step_spells :: proc()
{
    step_fire()
}
