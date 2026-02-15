package main

import "core:fmt"
import sdl "vendor:sdl3"

gamepad_1 : ^sdl.Gamepad
gamepad_2 : ^sdl.Gamepad

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
                case .X:
                    handle_wizard_wait()
                // spell
                case .Z:
                    handle_wizard_spell(.fire_tree)
            }
        case .GAMEPAD_BUTTON_DOWN:
		    button := sdl.GamepadButton(event.gbutton.button)
		    #partial switch button {
			    case .START:
				    fmt.println("start pressed")
                case .DPAD_LEFT:
                    handle_wizard_move(.left)
                case .DPAD_RIGHT:
                    handle_wizard_move(.right)  
                case .DPAD_UP:
                    handle_wizard_move(.up)
                case .DPAD_DOWN:
                    handle_wizard_move(.down)  
                case .EAST, .SOUTH:
                    handle_wizard_wait()  
                case .RIGHT_SHOULDER:
                    handle_wizard_spell(.fire_tree)

		    }
        case .GAMEPAD_ADDED:
		    handle_gamepad_added(event.gdevice.which)
        case .GAMEPAD_REMOVED:
		    handle_gamepad_removed(event.gdevice.which)

    }
    return .CONTINUE
}

// Gamepad management

@(private) handle_gamepad_added :: proc(jid: sdl.JoystickID) 
{
	fmt.println("gamepad added, jid ", jid)

	if gamepad_1 == nil {
		if jid != sdl.GetGamepadID(gamepad_2) {
			gamepad_1 = sdl.OpenGamepad(jid)
			fmt.println("gamepad 1 opened and assigned")
		}
	} else if gamepad_2 == nil {
		if jid != sdl.GetGamepadID(gamepad_1) {
			gamepad_2 = sdl.OpenGamepad(jid)
			fmt.println("gamepad 2 opened and assigned")
		}
	}
}

@(private) handle_gamepad_removed :: proc(jid: sdl.JoystickID) 
{
	fmt.println("gamepad removed, jid ", jid)

	if gamepad_1 != nil && jid == sdl.GetGamepadID(gamepad_1) {
		sdl.CloseGamepad(gamepad_1)
		gamepad_1 = nil
		fmt.println("gamepad 1 closed and unassigned")
	} else if gamepad_2 != nil && jid == sdl.GetGamepadID(gamepad_2) {
		sdl.CloseGamepad(gamepad_2)
		gamepad_2 = nil
		fmt.println("gamepad 2 closed and unassigned")
	}
}



