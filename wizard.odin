package main

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
    step_spells()
}

handle_wizard_spell :: proc(spell: Spell)
{
    wizard_spell_request = spell
}

// Direction

Direction :: enum { up, down, left, right }
DIRECTIONS :: [4]Direction { .up, .down, .left, .right }

turn_left :: proc(facing: Direction) -> Direction {
    result: Direction
    switch facing {
        case .left: result = .down
        case .down: result = .right
        case .right: result = .up
        case .up: result = .left
    }
    return result
}

turn_right :: proc(facing: Direction) -> Direction {
    result: Direction
    switch facing {
        case .left: result = .up
        case .down: result = .left
        case .right: result = .down
        case .up: result = .right
    }
    return result
}

