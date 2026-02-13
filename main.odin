package main

import "core:fmt"
import "core:os"
import "core:math/linalg"
import "base:runtime"
import sdl "vendor:sdl3"

window: ^sdl.Window

INTERNAL_RES :: [2]f32 {640, 360} 
GRID_PADDING :: f32(16)
UI_GRID_PADDING_WIDTH :: f32(10)
UI_GRID_PADDING_TOP :: f32(1)

// resolution := [2]f32 {640, 360} 
// resolution := [2]f32 {960, 540} 
resolution := 3 * INTERNAL_RES 
letterbox_resolution: [2]f32

// frame timing

real_time := sdl.Uint64(0)
sim_time := sdl.Uint64(0)
lag_time := sdl.Uint64(0)
game_step_time := int(0)

MAX_FRAME_TIME : sdl.Uint64 : sdl.Uint64(0.25 * 1000.0)
MS_PER_UPDATE : sdl.Uint64 : 16

// other constants

ROTATION_OFFSET := f32(linalg.PI / 2.0)

// main entry point

main :: proc() 
{
	fmt.println("\n* SDL EnterAppMainCallbacks *", sdl.GetError())
	exit_code := sdl.EnterAppMainCallbacks(0, nil, AppInit, AppIterate, AppEvent, AppQuit)
	fmt.println("final error = ", sdl.GetError())
    os.exit(int(exit_code))
}

// app callbacks

AppInit :: proc "c" (appstate: ^rawptr, argc: i32, argv: [^]cstring) -> sdl.AppResult 
{
	context = runtime.default_context()
	init()

	return .CONTINUE
}

AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult 
{
	context = runtime.default_context()

	new_time := sdl.GetTicks()
	frame_time := new_time - real_time

	if frame_time > MAX_FRAME_TIME {
		frame_time = MAX_FRAME_TIME
	}

	real_time = new_time
	lag_time += frame_time

	for lag_time >= MS_PER_UPDATE {
		sim_time += MS_PER_UPDATE
		update()
		lag_time -= MS_PER_UPDATE
	}

	dt := f32(lag_time) / f32(MS_PER_UPDATE)

	// render
	render(dt)

	free_all(context.temp_allocator)

	return .CONTINUE
}

AppEvent :: proc "c" (appstate: rawptr, event: ^sdl.Event) -> sdl.AppResult 
{
	context = runtime.default_context()

	return handle_input(event)
}

AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) 
{
	context = runtime.default_context()

	fmt.println("\n* App Quit *")

    // delete stuff

	sdl.Quit()
}