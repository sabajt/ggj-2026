package main

import "core:fmt"
import "core:math"

vert_ref_quad := 0 // len 6 
vert_ref_tri := 0 // len 3

RenderPackData :: struct {
	rad: f32,
	pos: [2]f32,
	last_pos: [2]f32,
	thic: f32,
	fade: f32,
	col: [4]f32
}

get_sim_dt :: proc(dt: f32) -> f32
{
	// If you have a pause or any state where 
	// visuals need to stop animating but stay visible, 
	// override sim_dt to 0

	sim_dt: f32
	switch game_state {		
	case .main:
		sim_dt = dt
	}
	return sim_dt
}

pack :: proc(dt: f32, cam: [2]f32)
{
	sim_dt := get_sim_dt(dt)

	pack_shared_verts()

	pack_radius_particles(sim_dt, cam)

	//////////////////////////////////////////////////
	// WARNING: packing wish sdf is coupled to render order.
	// TODO: decouple this
	pack_sdf(sim_dt, cam)
	//////////////////////////////////////////////////

	switch game_state {
	case .main:
		// state specific packing
	}

	pack_text_ttf()
}

pack_shared_verts :: proc()
{
	// quad

	verts := []Batch_Shape_Vertex {
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, 0.5}, color = {1, 1, 1, 1} },
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, 0.5}, color = {1, 1, 1, 1} },
		{ position = {-0.5, 0.5}, color = {1, 1, 1, 1} }
	}

	vert_ref_quad = pack_vert_ref(verts[:])

	// triangle

	verts = []Batch_Shape_Vertex {
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0, 0.5}, color = {1, 1, 1, 1} },
	}

	vert_ref_tri = pack_vert_ref(verts[:])
}

pack_sdf :: proc(dt: f32, cam: [2]f32)
{
	first_sdf_input = len(batch_shape_inputs)

	pack_radius_particles_sdf(dt, cam)

	switch game_state {
	case .main:
		// state specific sdf packing
	}

	last_sdf_input = len(batch_shape_inputs)
}

pack_render_data_sdf :: proc(data: RenderPackData, dt: f32, cam: [2]f32)
{
	models := [dynamic]Batch_Shape_Model{}
	blend_rad: f32 = data.rad // TODO: rad isn't being blended here... does it need to be?
	blend_rad = fit_res_x(blend_rad, letterbox_resolution)

	blend_pos := math.lerp(data.last_pos, data.pos, dt)
	blend_pos = fit_res_vec2(blend_pos, letterbox_resolution)

	model := Batch_Shape_Model {
		position = { blend_pos.x, blend_pos.y, 1 },
		rotation = 0,
		scale = blend_rad * 2.0,
		color = data.col,
		thic = data.thic,
		fade = data.fade,
		period = 0
	}

	// TODO: instead of appending dups, reference a common quad
	verts := [dynamic]Batch_Shape_Vertex {}

	append(&verts, Batch_Shape_Vertex { 
		position = {-0.5, -0.5}, 
		color = {1, 1, 1, 1}  // multiplying by this col in shader
	})
	append(&verts, Batch_Shape_Vertex { 
		position = {0.5, -0.5}, 
		color = {1, 1, 1, 1}  
	})
	append(&verts, Batch_Shape_Vertex { 
		position = {0.5, 0.5}, 
		color = {1, 1, 1, 1} 
	})

	append(&verts, Batch_Shape_Vertex { 
		position = {-0.5, -0.5}, 
		color = {1, 1, 1, 1}
	})
	append(&verts, Batch_Shape_Vertex { 
		position = {0.5, 0.5}, 
		color = {1, 1, 1, 1}
	})
	append(&verts, Batch_Shape_Vertex { 
		position = {-0.5, 0.5}, 
		color = {1, 1, 1, 1}
	})

	pack_batch_shape(verts[:], model)

	delete(models)
	delete(verts)
}

// pack a shape based on existing vert ref
pack_batch_shape_vert_ref :: proc (vert_index: int, count: int, model: Batch_Shape_Model)
{
	model_index := uint(len(batch_shape_models))
	append(&batch_shape_models, model)

	for i := vert_index; i < vert_index + count; i += 1 {
		input := Batch_Shape_Input { 
			vertex_index = uint(i),
			model_index = model_index
		}
		append(&batch_shape_inputs, input)
	}
}

// add a new vert ref, return index
pack_vert_ref :: proc(verts : []Batch_Shape_Vertex) -> (vert_index: int)
{
	i := len(batch_shape_verts)
	for &v in verts {
		append(&batch_shape_verts, v)
	}
	return i
}

pack_batch_shape :: proc(verts : []Batch_Shape_Vertex, model: Batch_Shape_Model) 
{
	// TODO: understand odin reference / arg passing rules 

	model_index := uint(len(batch_shape_models))
	append(&batch_shape_models, model)

	for &v in verts {
		vertex_index := uint(len(batch_shape_verts))
		append(&batch_shape_verts, v)

		input := Batch_Shape_Input { 
			vertex_index = vertex_index,
			model_index = model_index
		}
		append(&batch_shape_inputs, input)
	}
}

// TODO: separate packing concenrs...
// some pack functions like this don't need to translate 
// models to letterbox / screen scale. refactor for clarity...
pack_batch_shape_arr :: proc(
	src_verts : []Batch_Shape_Vertex, 
	src_models: []Batch_Shape_Model, 
	dest_verts: ^[dynamic]Batch_Shape_Vertex,
	dest_models: ^[dynamic]Batch_Shape_Model,
	dest_inputs: ^[dynamic]Batch_Shape_Input) 
{
	vertex_start_index := len(dest_verts)
	num_verts := len(src_verts)

	for &v in src_verts {
		append(dest_verts, v)
	}

	for m in src_models {
		model_index := uint(len(dest_models))
		append(dest_models, m)

		for i := 0; i < num_verts; i += 1 {

			input := Batch_Shape_Input { 
				vertex_index = uint(vertex_start_index + i),
				model_index = model_index
			}
			append(dest_inputs, input)
		}
	}
}



