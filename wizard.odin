package main

Direction :: enum { up, down, left, right }
DIRECTIONS :: [4]Direction { .up, .down, .left, .right }

Wizard :: struct {
    sprite: int,
    cell: [2]int
}

Spell :: enum {
    fire_tree
}

wizard_direction_request: Maybe(Direction) = nil
wizard_spell_request: Maybe(Spell) = nil

handle_wizard_move :: proc(dir: Direction)
{
    wizard_direction_request = dir
}

handle_wizard_spell :: proc(spell: Spell)
{
    wizard_spell_request = spell
}

