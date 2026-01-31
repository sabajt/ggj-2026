package main

import "core:math"

Transform :: struct {
    pos: [2]f32, 
    rot: f32,
    scale: [2]f32,
}

Blendable_Transform :: struct {
    cur: Transform,
    last: Transform
}

tf :: proc(pos: [2]f32, rot: f32, scale: [2]f32) -> Blendable_Transform 
{
    return {{pos, rot, scale}, {pos, rot, scale}}
}

blend :: proc(transform: Blendable_Transform, t: f32, adjust_rot: f32 = 0) -> Transform
{
    return { 
        pos = math.lerp(transform.last.pos, transform.cur.pos, t), 
        rot = math.lerp(transform.last.rot, transform.cur.rot, t) + adjust_rot, // TODO: figure out why -pi/2 needed sometimes
        scale = math.lerp(transform.last.scale, transform.cur.scale, t) 
    }
}

fit_res_letterbox :: proc(transform: Transform) -> Transform 
{
    return {
        pos = fit_res_vec2(transform.pos, letterbox_resolution),
        scale = fit_res_vec2(transform.scale, letterbox_resolution),
        rot = transform.rot
    }
}

blend_fit_res_letterbox :: proc(transform: Blendable_Transform, t: f32, adjust_rot: f32 = 0) -> Transform
{
    return fit_res_letterbox(blend(transform, t, adjust_rot))
}

fit_res_x :: proc(val: f32, res: [2]f32) -> f32 
{
    return val / INTERNAL_RES.x * res.x
}

fit_res_y :: proc(val: f32, res: [2]f32) -> f32 
{
    return val / INTERNAL_RES.y * res.y
}

fit_res_vec2 :: proc(val: [2]f32, res: [2]f32) -> [2]f32 
{
    return {fit_res_x(val.x, res), fit_res_y(val.y, res)}
}

get_letterbox_res :: proc() -> [2]f32
{
	screen_ratio := resolution.x / resolution.y
	aspect_ratio := INTERNAL_RES.x / INTERNAL_RES.y
	letterbox_res: [2]f32
	if screen_ratio > aspect_ratio {
		letterbox_res = {INTERNAL_RES.x * resolution.y / INTERNAL_RES.y, resolution.y}
	} else {
		letterbox_res = {resolution.x, INTERNAL_RES.y * resolution.x / INTERNAL_RES.x}
	}
	return letterbox_res
}


