package main

import "core:fmt"
import "core:math"

vert_ref_quad := 0 // len 6 
vert_ref_tri := 0 // len 3

solid_input_start_0: int
solid_input_end_0: int
solid_input_start_1: int
solid_input_end_1: int
solid_input_start_2: int
solid_input_end_2: int

sdf_input_start_0: int
sdf_input_end_0: int
sdf_input_start_1: int
sdf_input_end_1: int
sdf_input_start_2: int
sdf_input_end_2: int

sprite_start_0: int
sprite_end_0: int
sprite_start_1: int
sprite_end_1: int
sprite_start_2: int
sprite_end_2: int

gpu_sprites := make([dynamic]GPU_Sprite)
rectangles := make([dynamic]Rectangle)

RenderPackData :: struct {
	rad: f32,
	pos: [2]f32,
	last_pos: [2]f32,
	thic: f32,
	fade: f32,
	col: [4]f32
}

Rectangle :: struct {
	position: [2]f32,
	size: [2]f32,
	color: [4]f32,
	z: int
}

add_rectangle :: proc(rect: Rectangle)
{
	append(&rectangles, rect)
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

	for i in 0 ..< Z_ORDER_MAX {
		// Need to create checkpoints (first_sdf etc) as going thru z index that render will use to draw 

		if i == 0 {
			pack_shared_verts()
		}

		// pack_radius_particles(sim_dt, cam)
		// pack_sdf(sim_dt, cam)
		pack_shapes(sim_dt, cam, z = i)
		pack_sprites(sim_dt, z = i)

		switch game_state {
		case .main:
			// state specific packing
		}

		pack_text_ttf()
	}
}

pack_shapes :: proc(dt: f32, cam: [2]f32, z: int)
{
	if z == 0 {
		solid_input_start_0 = len(batch_shape_inputs)
	} else if z == 1 {
		solid_input_start_1 = len(batch_shape_inputs)
	} else if z == 2 {
		solid_input_start_2 = len(batch_shape_inputs)
	}
	defer {
		if z == 0 {
			solid_input_end_0 = len(batch_shape_inputs)
		} else if z == 1 {
			solid_input_end_1 = len(batch_shape_inputs)
		} else if z == 2 {
			solid_input_end_2 = len(batch_shape_inputs)
		}
	}

	// pack the shapes

	if len(rectangles) > 0 {
		for rect in rectangles {
			if rect.z == z {
				pack_rect(rect)
			}
		}
	}
}

pack_sprites :: proc(dt: f32, z: int)
{
	if z == 0 {
		sprite_start_0 = len(gpu_sprites)
	} else if z == 1 {
		sprite_start_1 = len(gpu_sprites)
	} else if z == 2 {
		sprite_start_2 = len(gpu_sprites)
	}
	defer {
		if z == 0 {
			sprite_end_0 = len(gpu_sprites)
		} else if z == 1 {
			sprite_end_1 = len(gpu_sprites)
		} else if z == 2 {
			sprite_end_2 = len(gpu_sprites)
		}
	}

	if len(sprites) > 0 {
		for i, spr in sprites {
			if spr.z == z {
				append(&gpu_sprites, create_gpu_sprite(spr, dt)) 
			}
		}
	}
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
// DOING: could give a z index (or z enum?) referencing different models and inputs
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

pack_rect :: proc(rect: Rectangle)
{
	// TODO: will need to blend

	pack_batch_shape_vert_ref(
		vert_ref_quad,  
		count = 6, 
		model = Batch_Shape_Model {
			position = {rect.position.x, rect.position.y, 1},
			rotation = 0, // + math.PI/2
			scale = rect.size,
			color = rect.color
		}
	)
}


