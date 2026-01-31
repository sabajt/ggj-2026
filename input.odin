package main

import sdl "vendor:sdl3"

handle_input :: proc(event: ^sdl.Event) -> sdl.AppResult 
{
	#partial switch event.type {
        case .QUIT:
            return .SUCCESS
        case .KEY_DOWN:
            #partial switch event.key.scancode {
                case .Q:
                    return .SUCCESS
                }
    }
    return .CONTINUE
}
