package main

import "core:math/rand"

Fire :: struct {
    t: int,
    dir: Direction,
    spr: int
}

fires := make(map[int]Fire)

create_spell :: proc(spell: Spell)
{
    switch spell {
        case .fire_tree:
            create_fire_tree_spell()
    }
}

@(private) create_fire_tree_spell :: proc() 
{
    cells := [dynamic][2]i32{}
    defer { delete(cells) }
    
    for dir in DIRECTIONS {
        // adjacent to player
        cell := cell_move(player.cell, dir)
        add_fire(cell, dir)

        // move 4 direction out
        for i in 0 ..< 8 {
            cell = cell_move(cell, dir)
            add_fire(cell, dir)

            // 1 / 3 chance to have a branch left or right
            if rand.int_max(3) == 0 {
                branch_dir := rand.int_max(2) == 0 ? Direction.left : Direction.right
                branch_cell := cell_move(cell, branch_dir)
                add_fire(branch_cell, branch_dir)
            }
        }
    }
}

add_fire :: proc(cell: [2]int, dir: Direction) 
{
    spr := add_sprite("fire.png", cell_pos(cell), anchor = .bottom_left)
    fire := Fire {
        t = 3,
        dir = dir,
        spr = spr
    }
    fires[spr] = fire
}

step_spells :: proc()
{
    step_fire()
}

step_fire :: proc()
{
    for key, &fire in fires {
        fire.t -= 1
        if fire.t == 0 {
            delete_key(&sprites, key)
            delete_key(&fires, key)
        }
    }
}
