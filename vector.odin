package main

import "core:math"
import "core:math/rand"
import "core:math/linalg"

pvec :: proc(ang: f32, radius: f32 = 1, center: [2]f32 = 0, flip_x: bool = false) -> [2]f32
{
	m: f32 = flip_x ? -1 : 1
	return { m * math.cos(ang), math.sin(ang) } * radius + center
}

limvec ::proc(v: [2]f32, max: f32) -> [2]f32
{
	return linalg.length(v) > max ? max * linalg.normalize(v) : v 
}

rand_screen_vec :: proc() -> [2]f32
{
	return camera.pos + {
		rand.float32() * INTERNAL_RES.x, 
		rand.float32() * INTERNAL_RES.y
	}
}

