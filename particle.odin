#+feature dynamic-literals

package main

import "core:fmt"
import "core:math"
import "core:math/rand"


LINE_WIDTH := f32(3) // TODO: resolution scale abstract. something is messed up here (look at entry animation in)

Ease_Mode :: enum {
	Linear,
	Quadratic_In,
	Quadratic_Out,
	Quadratic_In_Out,
	Cubic_In,
	Cubic_Out,
	Cubic_In_Out,
	Quartic_In,
	Quartic_Out,
	Quartic_In_Out,
	Exponential_In,
	Exponential_Out,
	Exponential_In_Out,
}

Radius_Effect :: struct {
	mode: Radius_Effect_Mode,
	t_int: int, // raw t interger
	delay_onset_t: int, // t before active / rendered
	t: f32, // normalized 0-1
	last_t: f32,
	ease: Ease_Mode,
	life: f32, // approx. seconds
	res: uint,
	rad_start: f32,
	rad_end: f32,
	pos: [2]f32,
	last_pos: [2]f32,
	vel: [2]f32,
	drag: f32,
	col_start: [4]f32,
	col_end: [4]f32,
	rot_start: f32,
	rot_end: f32,
	node_rad_start: f32,
	node_rad_end: f32,
	expired: bool,
	thic: f32,
	fade: f32
}

Radius_Effect_Mode :: enum {
	Solid,
	Line,
	Circles
}

MAX_RADIUS_EFFECT_BATCH := int(100)
radius_effects := [dynamic][dynamic]Radius_Effect { [dynamic]Radius_Effect{} }
create_random_particles := false

clear_radius_effects :: proc()
{
	for &arr in radius_effects {
		clear(&arr)
	}
	clear(&radius_effects)
}

create_random_particle :: proc(mode: Radius_Effect_Mode) -> Radius_Effect 
{
	pos := [2]f32{
		INTERNAL_RES.x / 2 + (2 * rand.float32() - 1) * 300, 
		INTERNAL_RES.y / 2 + (2 * rand.float32() - 1) * 300 
	}
	return create_random_particle_pos(mode, pos + camera.pos)
}

create_random_particle_pos :: proc(mode: Radius_Effect_Mode, pos: [2]f32) -> Radius_Effect
{
	rad_start := f32(2)
	rad_end := f32(2) + f32(rand.int_max(int(INTERNAL_RES.y / 2.0)))

	return create_particle_effect(
		mode = mode, 
		pos = pos,
		vel = {0, 0},
		drag = 0,
		life = 0.5 + 3.0 * rand.float32(),
		res = uint(rand.int_max(15) + 3),
		rad_start = rad_start,
		rad_end = rad_end, 
		col_start = {rand.float32(), rand.float32(), rand.float32(), 1},
		col_end = {rand.float32(), rand.float32(), rand.float32(), 0},
		rot_start = 0,
		rot_end = (2 * rand.float32() - 1.0) * math.TAU + (math.PI / 4.0),
		node_rad_start = 6,
		node_rad_end = 6,
		thic = rand.float32_range(2, rad_end),
		fade = rand.float32_range(0, 10),
	)
}

// TODO: REFACTOR 1) Modes have mode create structs to separate from common particle effect container
// TODO: REFACTOR 2) Designated inits for each type of effect

// creates particle with life starting at current sim_time
create_particle_effect :: proc(
	mode: Radius_Effect_Mode, 
	pos: [2]f32,
	vel: [2]f32,
	drag: f32,
	life: f32,
	res: uint,
	rad_start: f32,
	rad_end: f32,
	col_start: [4]f32,
	col_end: [4]f32,
	rot_start: f32,
	rot_end: f32,	
	node_rad_start : f32,
	node_rad_end : f32,
	thic : f32, 
	fade: f32,
	delay: int = 0, 
	ease: Ease_Mode = .Linear) -> Radius_Effect 
{
	return Radius_Effect {
		t_int = 0,
		delay_onset_t = delay,
		t = 0,
		last_t = 0,
		ease = ease,
		life = life,
		res = res,
		rad_start = rad_start,
		rad_end = rad_end,
		pos = pos,
		last_pos = pos,
		vel = vel,
		drag = drag,
		col_start = col_start,
		col_end = col_end,
		rot_start = rot_start,
		rot_end = rot_end,
		mode = mode,
		expired = false,
		node_rad_start = node_rad_start,
		node_rad_end = node_rad_end,
		thic = thic,
		fade = fade
	}
}

pack_radius_particles :: proc(dt: f32, cam: [2]f32) 
{
	// pack fill and lines
	for arr in radius_effects {
		for p in arr {
			// skip "removed", delayed and circle mode
			if p.delay_onset_t == 0 && !p.expired && p.mode != .Circles  {
				pack_radius_particle(p, dt, cam)
			}
		}
	}
}

pack_radius_particles_sdf :: proc(dt: f32, cam: [2]f32) 
{
	for arr in radius_effects {
		for p in arr {
			// skip "removed", delayed and only pack circles
			if p.delay_onset_t == 0 && !p.expired && p.mode == .Circles  {
				pack_radius_particle(p, dt, cam)
			}
		}
	}
}

pack_radius_particle :: proc(p: Radius_Effect, dt: f32, cam: [2]f32)
{
	model: Batch_Shape_Model
	blend_t := math.lerp(p.last_t, p.t, dt)

	rad := math.lerp(p.rad_start, p.rad_end, blend_t)
	rad = fit_res_x(rad, letterbox_resolution) // TODO: resolution scale abstract (remember that x or y doesn't matter here) 
	
	rot := math.lerp(p.rot_start, p.rot_end, blend_t)
	col := math.lerp(p.col_start, p.col_end, blend_t)

	blend_node_rad := math.lerp(p.node_rad_start, p.node_rad_end, blend_t)
	blend_node_rad = fit_res_x(blend_node_rad, letterbox_resolution) // TODO: resolution scale abstract (remember that x or y doesn't matter here) 

	// TODO: use blend fit abstractions
	pos := math.lerp(p.last_pos, p.pos, dt) 
	pos = fit_res_vec2(pos, letterbox_resolution) 

	if p.mode == .Solid || p.mode == .Line {

		model = Batch_Shape_Model {
			position = { pos.x, pos.y, 1 },
			rotation = rot,
			scale = 1,
			color = col,
			thic = p.thic,
			fade = p.fade,
			period = 0
		}
	}	

	verts := [dynamic]Batch_Shape_Vertex {}

	for i : uint = 0; i < p.res; i += 1 {

 		angle := math.TAU * f32(i) / f32(p.res)

 		switch p.mode {
 		case .Solid:
			pos := pvec(angle, rad)

			// outer
			append(&verts, Batch_Shape_Vertex { 
				position = pos, 
				color = col  
			})

			// center
			append(&verts, Batch_Shape_Vertex { 
				position = {0, 0}, 
				color = col
			}) 

			// next index
			angle = math.TAU * f32(i + 1) / f32(p.res)
			pos = pvec(angle, rad)

			append(&verts, Batch_Shape_Vertex { 
				position = pos, 
				color = col
			}) 
		case .Line:
			// outer
			pos0 :=  pvec(angle, rad + LINE_WIDTH / 2.0)
			append(&verts, Batch_Shape_Vertex { 
				position = pos0, 
				color = col
			}) 

			// inner
			ang1 := math.TAU * f32(i) / f32(p.res)
			pos1 := pvec(ang1, rad - LINE_WIDTH / 2.0)
			append(&verts, Batch_Shape_Vertex { 
				position = pos1, 
				color = col  
			}) 

			// next outer
			ang2 := math.TAU * f32(i + 1) / f32(p.res)
			pos2 := pvec(ang2, rad + LINE_WIDTH / 2.0)
			append(&verts, Batch_Shape_Vertex { 
				position = pos2, 
				color = col 
			})

			// inner
			append(&verts, Batch_Shape_Vertex { 
				position = pos1, 
				color = col  
			})

			// next outer
			append(&verts, Batch_Shape_Vertex { 
				position = pos2, 
				color =col 
			})

			// next inner
			ang3 := math.TAU * f32(i + 1) / f32(p.res)
			pos3 := pvec(ang3, rad - LINE_WIDTH / 2.0)
			append(&verts, Batch_Shape_Vertex { 
				position = pos3, 
				color = col
			})
		case .Circles:
			pos := [2]f32 { 
				pos.x + rad * math.cos(angle), 
				pos.y + rad * math.sin(angle) 
			}

			model = Batch_Shape_Model {
				position = { pos.x, pos.y, 1 },
				rotation = 0,
				scale = blend_node_rad * 2.0,
				color = col,
				thic = p.thic,
				fade = p.fade,
				period = 0
			}

			pack_batch_shape_vert_ref(
				vert_index = vert_ref_quad, 
				count = 6, 
				model = model
			)
		}
	}

	if p.mode != .Circles {
		pack_batch_shape(verts[:], model)
	}

	delete(verts)
}
