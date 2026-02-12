package main

import "core:math/linalg"

collide :: proc(p0: [2]f32, r0: f32, p1: [2]f32, r1: f32) -> bool
{
	return linalg.length(p0 - p1) - (r0 + r1) < 0 
}



