package main

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
        cell := cell_move(player.cell, dir)
        add_sprite("fire.png", cell_pos(cell), anchor = .bottom_left)
        for i in 0 ..< 8 {
            cell = cell_move(cell, dir)
            add_sprite("fire.png", cell_pos(cell), anchor = .bottom_left)
        }
    }
}
