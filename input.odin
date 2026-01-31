package main

import sdl "vendor:sdl3"

handle_input :: proc(event: ^sdl.Event) -> sdl.AppResult 
{
	#partial switch event.type {
        case .QUIT:
            return .SUCCESS
        case .KEY_DOWN:
            #partial switch event.key.scancode {
                
                // quit
                case .Q:
                    return .SUCCESS
                
                // move
                case .LEFT:
                    handle_wizard_move(.left)
                case .RIGHT:
                    handle_wizard_move(.right)
                case .UP:
                    handle_wizard_move(.up)
                case .DOWN:
                    handle_wizard_move(.down)

                // spell
                case .Z:
                    handle_wizard_spell(.fire_tree)
                }

    }
    return .CONTINUE
}



