package main

import sdl "vendor:sdl3"

get_resolution :: proc () -> [2]f32 {
	s : [2]i32
	ok := sdl.GetWindowSize(window, &s.x, &s.y)
	assert(ok)
	return [2]f32 { f32(s.x), f32(s.y) }
}

update :: proc() 
{
    // update resolution from current window size
	resolution = get_resolution()
	letterbox_resolution = get_letterbox_res()
}