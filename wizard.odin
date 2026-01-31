package main

Direction :: enum { up, down, left, right }

Wizard :: struct {
    sprite: ^Sprite,
    cell: [2]int
}

wizard_direction_request: Maybe(Direction) = nil

handle_move_wizard :: proc(dir: Direction)
{
    wizard_direction_request = dir
}

