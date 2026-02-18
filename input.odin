package main

import "core:fmt"
import "core:math/linalg"
import "core:math"
import sdl "vendor:sdl3"

gamepad_1 : ^sdl.Gamepad
gamepad_2 : ^sdl.Gamepad
left_x_axis_val: f32
left_y_axis_val: f32
AXIS_CUTOFF : f32 = 0.3
facing_dir: Maybe(Direction)

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
                // TODO: keyboard arrow key
                // case .LEFT:
                // case .RIGHT:
                // case .UP:
                // case .DOWN:
                case .X:
                    handle_wizard_wait()
                // spell
                case .Z:
                    // handle_wizard_spell(.fire_tree)
            }
        case .GAMEPAD_BUTTON_DOWN:
		    button := sdl.GamepadButton(event.gbutton.button)
		    #partial switch button {
                // TODO: menu
                // case .DPAD_LEFT:
                // case .DPAD_RIGHT:
                // case .DPAD_UP:
                // case .DPAD_DOWN:
                // case .EAST
                case .RIGHT_SHOULDER:
                    if !is_stepping {
                        if val, ok := facing_dir.?; ok { 
                            handle_wizard_move(val)
                        } else  {
                            handle_wizard_wait()
                        }
                    }
		    }
        case .GAMEPAD_ADDED:
		    handle_gamepad_added(event.gdevice.which)
        case .GAMEPAD_REMOVED:
		    handle_gamepad_removed(event.gdevice.which)
        case .GAMEPAD_AXIS_MOTION:
            if !is_stepping {
                axis := sdl.GamepadAxis(event.gaxis.axis)
                #partial switch axis {
                case .LEFTX, .LEFTY:
                    handle_rotate_left_axis(axis, event.gaxis.value)
                case .RIGHT_TRIGGER:
                    if event.gaxis.value > 0 {
                        if val, ok := facing_dir.?; ok { 
                            spell := Fire_Spell { cell = pos_to_cell(player.pos), dir = val }
                            handle_wizard_spell(spell)
                        }
                    }
                }
            }
    }
    return .CONTINUE
}

handle_rotate_left_axis :: proc(axis: sdl.GamepadAxis, value: sdl.Sint16) 
{
	axis_val := f32(value) / f32(max(sdl.Sint16))

	if sdl.GamepadAxis(axis) == sdl.GamepadAxis.LEFTX {
		left_x_axis_val = axis_val
	}
	if sdl.GamepadAxis(axis) == sdl.GamepadAxis.LEFTY {
		left_y_axis_val = -axis_val
	}

    left_x_axis_val := abs(left_x_axis_val) > AXIS_CUTOFF ? left_x_axis_val : 0
	left_y_axis_val := abs(left_y_axis_val) > AXIS_CUTOFF ? left_y_axis_val : 0
	is_rotating : bool = abs(left_x_axis_val) > AXIS_CUTOFF || abs(left_y_axis_val) > AXIS_CUTOFF
    dir_indicator := &shapes[player_dir_indicator_shape_i]

	if is_rotating {
		ang := linalg.atan2(left_y_axis_val, left_x_axis_val)
		if ang < 0 {
			// neg val is bottom half, convert to 0...TAU going ccw
			ang = math.TAU - abs(ang)
		}
        snap_ang: f32
        EIGTH_OF_PI := f32(math.PI / 8.0) 
        if ang >= math.TAU - EIGTH_OF_PI || ang < EIGTH_OF_PI {
            snap_ang = 0
            facing_dir = .east
        } else if ang >= EIGTH_OF_PI && ang < 3 * EIGTH_OF_PI {
            snap_ang = 2 * EIGTH_OF_PI 
            facing_dir = .northeast
        } else if ang >= 3 * EIGTH_OF_PI && ang < 5 * EIGTH_OF_PI {
            snap_ang = 4 * EIGTH_OF_PI
            facing_dir = .north
        } else if ang >= 5 * EIGTH_OF_PI && ang < 7 * EIGTH_OF_PI {
            snap_ang = 6 * EIGTH_OF_PI
            facing_dir = .northwest
        } else if ang >= 7 * EIGTH_OF_PI && ang < 9 * EIGTH_OF_PI {
            snap_ang = math.PI
            facing_dir = .west
        } else if ang >= 9 * EIGTH_OF_PI && ang < 11 * EIGTH_OF_PI {
            snap_ang = 10 * EIGTH_OF_PI
            facing_dir = .southwest
        } else if ang >= 11 * EIGTH_OF_PI && ang < 13 * EIGTH_OF_PI {
            snap_ang = 12 * EIGTH_OF_PI
            facing_dir = .south
        } else if ang >= 13 * EIGTH_OF_PI && ang < 15 * EIGTH_OF_PI {
            snap_ang = 14 * EIGTH_OF_PI 
            facing_dir = .southeast
        }
        
        tri_pos := pvec(
            ang = snap_ang, 
            radius = GRID_PADDING / 2.0 + 4, 
            center = player.pos + GRID_PADDING / 2.0
	    )
        dir_indicator.tf = tf(tri_pos, snap_ang - math.PI / 2.0 , {5, 5})
        dir_indicator.visible = true
    } else {
        dir_indicator.visible = false
        facing_dir = nil
    }
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



