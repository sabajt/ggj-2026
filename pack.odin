package main

import "core:fmt"
import "core:math"

vert_ref_quad_solid := 0 // len 6 
vert_ref_quad_bl_solid := 0 // len 6
vert_ref_tri_solid := 0 // len 3

vert_ref_quad_sdf := 0 // len 6 
vert_ref_quad_bl_sdf := 0 // len 6
vert_ref_tri_sdf := 0 // len 3

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

particle_input_start: int
particle_input_end: int

gpu_sprites: [dynamic]GPU_Sprite

shapes: [dynamic]Shape
shape_i := 0

RenderPackData :: struct {
	rad: f32,
	pos: [2]f32,
	last_pos: [2]f32,
	thic: f32,
	fade: f32,
	col: [4]f32
}

ShapeType :: enum {
	Rectangle,
	Triangle
}

Shape :: struct {
	type: ShapeType,
	tf: Blendable_Transform,
	color: [4]f32,
	anchor: Anchor,
	z: int,
	visible: bool
}

add_shape :: proc(shape: Shape) -> int
{
	i := len(shapes)
	append(&shapes, shape)
	return i
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

	for i in 0 ..< Z_ORDER_MAX {
		pack_shapes(sim_dt, cam, z = i)
		pack_sprites(sim_dt, z = i)

		switch game_state {
		case .main:
			// state specific packing
		}
	}
	pack_radius_particles_solid(sim_dt, cam)
	pack_sdf(sim_dt, cam)
	pack_text_ttf()
}

pack_shapes :: proc(dt: f32, cam: [2]f32, z: int)
{
	if z == 0 {
		solid_input_start_0 = len(batch_shape_solid_inputs)
	} else if z == 1 {
		solid_input_start_1 = len(batch_shape_solid_inputs)
	} else if z == 2 {
		solid_input_start_2 = len(batch_shape_solid_inputs)
	}
	defer {
		if z == 0 {
			solid_input_end_0 = len(batch_shape_solid_inputs)
		} else if z == 1 {
			solid_input_end_1 = len(batch_shape_solid_inputs)
		} else if z == 2 {
			solid_input_end_2 = len(batch_shape_solid_inputs)
		}
	}

	// pack the shapes

	if len(shapes) > 0 {
		for shape in shapes {
			if shape.z == z && shape.visible {
				switch shape.type {
					case .Rectangle:
						pack_rect(shape, dt)
					case .Triangle:
						pack_tri(shape, dt)
				}
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
			if spr.visible && spr.z == z {
				append(&gpu_sprites, create_gpu_sprite(spr, dt)) 
			}
		}
	}
}

pack_shared_verts :: proc()
{
	// quad: centered
	verts := []Batch_Shape_Vertex {
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, 0.5}, color = {1, 1, 1, 1} },
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, 0.5}, color = {1, 1, 1, 1} },
		{ position = {-0.5, 0.5}, color = {1, 1, 1, 1} }
	}
	vert_ref_quad_solid = pack_vert_ref_solid(verts[:])
	vert_ref_quad_sdf = pack_vert_ref_sdf(verts[:])

	// quad: bottom left 
	verts = []Batch_Shape_Vertex {
		{ position = {0, 0}, color = {1, 1, 1, 1} },
		{ position = {1, 0}, color = {1, 1, 1, 1} },
		{ position = {1, 1}, color = {1, 1, 1, 1} },
		{ position = {0, 0}, color = {1, 1, 1, 1} },
		{ position = {1, 1}, color = {1, 1, 1, 1} },
		{ position = {0, 1}, color = {1, 1, 1, 1} }
	}
	vert_ref_quad_bl_solid = pack_vert_ref_solid(verts[:])
	vert_ref_quad_bl_sdf = pack_vert_ref_sdf(verts[:])

	// triangle: centered
	verts = []Batch_Shape_Vertex {
		{ position = {-0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0.5, -0.5}, color = {1, 1, 1, 1} },
		{ position = {0, 0.5}, color = {1, 1, 1, 1} },
	}
	vert_ref_tri_solid = pack_vert_ref_solid(verts[:])
	vert_ref_tri_sdf = pack_vert_ref_sdf(verts[:])
}

pack_sdf :: proc(dt: f32, cam: [2]f32)
{
	// TODO: prolly don't input flags anymore since in their own arr
	first_sdf_input = len(batch_shape_sdf_inputs)

	pack_radius_particles_sdf(dt, cam)

	switch game_state {
	case .main:
		// state specific sdf packing
	}

	last_sdf_input = len(batch_shape_sdf_inputs)
}

pack_render_data_sdf :: proc(data: RenderPackData, dt: f32, cam: [2]f32)
{
	models := [dynamic]Batch_Shape_SDF_Model{}
	blend_rad: f32 = data.rad // TODO: rad isn't being blended here... does it need to be?
	blend_rad = fit_res_x(blend_rad, letterbox_resolution)

	blend_pos := math.lerp(data.last_pos, data.pos, dt)
	blend_pos = fit_res_vec2(blend_pos, letterbox_resolution)

	model := Batch_Shape_SDF_Model {
		position = { blend_pos.x, blend_pos.y, 1 },
		rotation = 0,
		scale = blend_rad * 2.0,
		color = data.col,
		thic = data.thic,
		fade = data.fade,
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

	pack_batch_shape_sdf(verts[:], model)

	delete(models)
	delete(verts)
}

// pack a shape based on existing vert ref
// DOING: could give a z index (or z enum?) referencing different models and inputs
pack_batch_shape_solid_vert_ref :: proc (vert_index: int, count: int, model: Batch_Shape_Solid_Model)
{
	model_index := uint(len(batch_shape_solid_models))
	append(&batch_shape_solid_models, model)

	for i := vert_index; i < vert_index + count; i += 1 {
		input := Batch_Shape_Input { 
			vertex_index = uint(i),
			model_index = model_index
		}
		append(&batch_shape_solid_inputs, input)
	}
}
pack_batch_shape_sdf_vert_ref :: proc (vert_index: int, count: int, model: Batch_Shape_SDF_Model)
{
	model_index := uint(len(batch_shape_sdf_models))
	append(&batch_shape_sdf_models, model)

	for i := vert_index; i < vert_index + count; i += 1 {
		input := Batch_Shape_Input { 
			vertex_index = uint(i),
			model_index = model_index
		}
		append(&batch_shape_sdf_inputs, input)
	}
}

// add a new vert ref, return index
pack_vert_ref_solid :: proc(verts : []Batch_Shape_Vertex) -> (vert_index: int)
{
	i := len(batch_shape_solid_verts)
	for &v in verts {
		append(&batch_shape_solid_verts, v)
	}
	return i
}
// add a new vert ref, return index
pack_vert_ref_sdf :: proc(verts : []Batch_Shape_Vertex) -> (vert_index: int)
{
	i := len(batch_shape_sdf_verts)
	for &v in verts {
		append(&batch_shape_sdf_verts, v)
	}
	return i
}

pack_batch_shape_solid :: proc(verts : []Batch_Shape_Vertex, model: Batch_Shape_Solid_Model) 
{
	model_index := uint(len(batch_shape_solid_models))
	append(&batch_shape_solid_models, model)

	for &v in verts {
		vertex_index := uint(len(batch_shape_solid_verts))
		append(&batch_shape_solid_verts, v)

		input := Batch_Shape_Input { 
			vertex_index = vertex_index,
			model_index = model_index
		}
		append(&batch_shape_solid_inputs, input)
	}
}

pack_batch_shape_sdf :: proc(verts : []Batch_Shape_Vertex, model: Batch_Shape_SDF_Model) 
{
	model_index := uint(len(batch_shape_sdf_models))
	append(&batch_shape_sdf_models, model)

	for &v in verts {
		vertex_index := uint(len(batch_shape_sdf_verts))
		append(&batch_shape_sdf_verts, v)

		input := Batch_Shape_Input { 
			vertex_index = vertex_index,
			model_index = model_index
		}
		append(&batch_shape_sdf_inputs, input)
	}
}

pack_rect :: proc(shape: Shape, dt: f32)
{
	tf := blend_fit_res_letterbox(shape.tf, dt)

	vert_ref: int
	switch shape.anchor {
		case .center:
			vert_ref = vert_ref_quad_solid
		case .bottom_left:
			vert_ref = vert_ref_quad_bl_solid
	}

	pack_batch_shape_solid_vert_ref(
		vert_ref,  
		count = 6, 
		model = Batch_Shape_Solid_Model {
			position = {tf.pos.x, tf.pos.y, 1},
			rotation = tf.rot, // + math.PI/2
			scale = tf.scale,
			color = shape.color
		}
	)
}

// TODO: anchor is ignored, add or change Shape description?
pack_tri :: proc(shape: Shape, dt: f32)
{
	tf := blend_fit_res_letterbox(shape.tf, dt)

	pack_batch_shape_solid_vert_ref(
		vert_ref_tri_solid,  
		count = 3, 
		model = Batch_Shape_Solid_Model {
			position = {tf.pos.x, tf.pos.y, 1},
			rotation = tf.rot, // + math.PI/2
			scale = tf.scale,
			color = shape.color
		}
	)
}


