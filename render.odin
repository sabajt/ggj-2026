package main

import "core:log"
import "core:fmt"
import "core:math/linalg"
import "core:math"
import "core:mem"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

GRID_PADDING : f32 : 40

text_index_offset := 0
text_vertex_offset := 0

camera := create_camera() 

Camera :: struct {
	pos: [2]f32,
	last_pos: [2]f32,
}

create_camera :: proc() -> Camera
{
	return Camera {
		pos = {0, 0},
		last_pos = {0, 0},
	}
}

clear_batch_shape :: proc() 
{
	clear(&batch_shape_inputs)
	clear(&batch_shape_verts)
	clear(&batch_shape_models)
}

render :: proc(dt: f32) 
{
	command_buffer := sdl.AcquireGPUCommandBuffer(gpu) 

	swapchain_texture: ^sdl.GPUTexture
	ok := sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, window, &swapchain_texture, nil, nil)
	assert(ok, "not ok")

	// get (already created?) target texture

	if swapchain_texture != nil {
		render_internal(dt, command_buffer, letterbox_texture)
		render_to_swapchain(
			command_buffer, 
			target_texture = letterbox_texture,
			target_sampler = letterbox_sampler,
			swapchain_texture = swapchain_texture
		)
	}

	ok = sdl.SubmitGPUCommandBuffer(command_buffer);
	assert(ok, "not ok")	
}

@(private) camera_mat_from_blend_pos :: proc(camera_blend_pos: [2]f32) -> linalg.Matrix4f32
{
	return linalg.matrix4_translate_f32({-camera_blend_pos.x, -camera_blend_pos.y, 0})
}

@(private) render_to_swapchain :: proc(command_buffer: ^sdl.GPUCommandBuffer, target_texture: ^sdl.GPUTexture, target_sampler: ^sdl.GPUSampler, swapchain_texture: ^sdl.GPUTexture) 
{	
	// TODO: figure out why sprites aren't scaling when samples to swapchain (should blit?)

	color_target := sdl.GPUColorTargetInfo {
		texture = swapchain_texture,
		clear_color = {0, 0, 0, 1},
		load_op = .CLEAR,
		store_op = .STORE,
		// TODO: Should cycle?
	}
	
	render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target, 1, nil)
	
	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_letterbox)
	
	// Bind offscreen texture
	sdl.BindGPUFragmentSamplers(
		render_pass,
		first_slot = 0,
		texture_sampler_bindings = &(sdl.GPUTextureSamplerBinding {
			texture = target_texture,
			sampler = target_sampler,
		}),
		num_bindings = 1,
	)

	// view_projection := proj_mat * camera_mat
	res_buf := Resolution_Uniform_Buffer {
		resolution = resolution,
		letterbox_resolution = letterbox_resolution
	}
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 0, 
		data = &res_buf, 
		length = size_of(res_buf)
	)
	
	// Draw fullscreen quad
	sdl.DrawGPUPrimitives(
		render_pass,
		num_vertices = 6,
		num_instances = 1,
		first_vertex = 0,
		first_instance = 0,
	)
	
	sdl.EndGPURenderPass(render_pass)
}

@(private) render_internal :: proc(dt: f32, command_buffer: ^sdl.GPUCommandBuffer, target_texture: ^sdl.GPUTexture) 
{	
	// make pausing not jitter
	sim_dt := get_sim_dt(dt) 

	proj_mat := linalg.matrix_ortho3d_f32(0, letterbox_resolution.x, 0, letterbox_resolution.y, near=-100, far=100, flip_z_axis=false)

	// Blend and scale camera position to letterbox
	camera_blend_pos := math.lerp(camera.last_pos, camera.pos, sim_dt)
	camera_blend_pos = fit_res_vec2(camera_blend_pos, letterbox_resolution)
	camera_mat := camera_mat_from_blend_pos(camera_blend_pos)

	// clear cpu models
	clear_batch_shape()
	clear_text()

	// pack cpu to render models
	pack(dt, camera_blend_pos) // use real dt so paused state can have animations (though it doesn't currently!)

	// copy and transfer memory to gpu
	copy_and_upload_mem(command_buffer, sim_dt)

	// begin render pass
 
	color_target := sdl.GPUColorTargetInfo {
		texture = target_texture,
		clear_color = {0, 0, 0, 1},
		load_op = .CLEAR,
		store_op = .STORE
	} // TODO: cycle?

	render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target, 1, nil)

	switch game_state {
		case .main:
			render_grid(command_buffer, render_pass, camera_blend_pos, proj_mat, letterbox_resolution)		
	}

	if len(batch_shape_inputs) > 0 {
		render_batched_shapes(render_pass, command_buffer, camera_blend_pos, proj_mat, letterbox_resolution)
	}
	if len(sprites) > 0 {
		render_sprites(render_pass, command_buffer, camera_blend_pos, proj_mat)
	}
	if needs_text_render {
		needs_text_render = false
		render_text(render_pass, command_buffer, proj_mat)
	}

	sdl.EndGPURenderPass(render_pass)
}

@(private) render_sprites :: proc(render_pass: ^sdl.GPURenderPass, command_buffer: ^sdl.GPUCommandBuffer,  camera_blend_pos: [2]f32, proj_mat: matrix[4, 4]f32)
{
	camera_mat := camera_mat_from_blend_pos(camera_blend_pos)

	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_sprite)

	sdl.BindGPUVertexStorageBuffers(
		render_pass,
		first_slot = 0,
		storage_buffers = &sprite_data_buffer,
		num_bindings = 1
	)
	sdl.BindGPUFragmentSamplers(
		render_pass, 
		first_slot = 0, 
		texture_sampler_bindings =  &(sdl.GPUTextureSamplerBinding {
			texture = sprite_atlas_texture,  
			sampler = sprite_sampler 
		}),
		num_bindings = 1
	)

	view_projection := proj_mat * camera_mat
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 0, 
		data = &view_projection, 
		length = size_of(view_projection)
	)
	sdl.DrawGPUPrimitives(
		render_pass, 
		u32(len(sprites)) * 6,
		num_instances = 1, 
		first_vertex = 0, 
		first_instance = 0
	)
}

@(private) render_batched_shapes :: proc(render_pass: ^sdl.GPURenderPass, command_buffer: ^sdl.GPUCommandBuffer,  camera_blend_pos: [2]f32, proj_mat: matrix[4, 4]f32, res: [2]f32)
{
	camera_mat := camera_mat_from_blend_pos(camera_blend_pos)

	// draw batched shapes: fill

	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_fill)

	sdl.BindGPUVertexBuffers(
		render_pass, 
		first_slot = 0, 
		bindings = &(sdl.GPUBufferBinding { buffer = batch_shape_inputs_vertex_buffer }), 
		num_bindings = 1
	)

	// TODO: figure out how to do in 1 call (how to build multi pointer?)
	sdl.BindGPUVertexStorageBuffers(
		render_pass,
		first_slot = 0,
		storage_buffers = &batch_shape_vertex_storage_buffer,
		num_bindings = 1
	)
	sdl.BindGPUVertexStorageBuffers(
		render_pass,
		first_slot = 1,
		storage_buffers = &batch_shape_models_storage_buffer,
		num_bindings = 1
	)

	view_projection := proj_mat * camera_mat
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 0, 
		data = &view_projection, 
		length = size_of(view_projection)
	)

	res_ubo := Res_Ubo { res_cam = {res.x, res.y, camera_blend_pos.x, camera_blend_pos.y } }
	sdl.PushGPUFragmentUniformData(command_buffer, 0, &res_ubo, size_of(res_ubo))

	sdl.DrawGPUPrimitives(
		render_pass, 
		num_vertices = u32(first_sdf_input),
		num_instances = 1, 
		first_vertex = 0, 
		first_instance = 0
	)

	// draw batched shapes: sdf circles

	sdf_particles_len := last_sdf_input - first_sdf_input

	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_sdf)

	res_ubo = Res_Ubo { res_cam = {res.x, res.y, camera_blend_pos.x, camera_blend_pos.y } }
	sdl.PushGPUFragmentUniformData(command_buffer, 0, &res_ubo, size_of(res_ubo))

	sdl.DrawGPUPrimitives(
		render_pass, 
		num_vertices = u32(sdf_particles_len),
		num_instances = 1, 
		first_vertex = u32(first_sdf_input), 
		first_instance = 0
	)

	// draw batched shapes: players

	players_len := len(batch_shape_inputs) - last_sdf_input

	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_fill)

	sdl.DrawGPUPrimitives(
		render_pass, 
		num_vertices = u32(players_len),
		num_instances = 1, 
		first_vertex = u32(last_sdf_input), 
		first_instance = 0
	)
}


@(private) render_text :: proc(render_pass: ^sdl.GPURenderPass, command_buffer: ^sdl.GPUCommandBuffer, proj_mat: matrix[4, 4]f32)
{
	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_text)

	sdl.BindGPUVertexBuffers(
		render_pass, 
		first_slot = 0, 
		bindings = &(sdl.GPUBufferBinding { buffer = text_vertex_buffer }), 
		num_bindings = 1
	)
	sdl.BindGPUIndexBuffer(
		render_pass, 
		binding = sdl.GPUBufferBinding { buffer = text_index_buffer }, 
		index_element_size = ._32BIT
	)

	text_pos_mat := linalg.matrix4_translate_f32({0, 0, 0}) // TODO: z?	
	text_mvp := proj_mat * text_pos_mat // Ignores camera
	text_mvp_ubo := Mvp_Ubo { mvp = text_mvp }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 0, 
		data = &text_mvp_ubo, 
		length = size_of(text_mvp_ubo)
	)

	text_index_offset = 0
	text_vertex_offset = 0
	for &item in text_items {
		if item.active {
			render_text_item(render_pass, item = &item)
		}
	}
}

@(private) render_text_item :: proc(render_pass: ^sdl.GPURenderPass, item: ^TTF_Text_Item) 
{
	atlas_draw_seq := ttf.GetGPUTextDrawData(item.text)

	for seq := atlas_draw_seq; seq != nil; seq = seq.next {

		sdl.BindGPUFragmentSamplers(
			render_pass, 
			first_slot = 0, 
			texture_sampler_bindings =  &(sdl.GPUTextureSamplerBinding {
				texture = seq.atlas_texture,  
				sampler = text_sampler 
			}),
			num_bindings = 1
		)
		sdl.DrawGPUIndexedPrimitives(
			render_pass, 
			num_indices = u32(seq.num_indices),
			num_instances = 1, 
			first_index = u32(text_index_offset), 
			vertex_offset = i32(text_vertex_offset), 
			first_instance = 0
		)

		text_index_offset += int(seq.num_indices)
		text_vertex_offset += int(seq.num_vertices)
	}
}

@(private) render_grid :: proc(command_buffer: ^sdl.GPUCommandBuffer, render_pass: ^sdl.GPURenderPass, camera_blend_pos: [2]f32, proj_mat: linalg.Matrix4f32, res: [2]f32)
{
	camera_mat := camera_mat_from_blend_pos(camera_blend_pos)

	// grid: common

	sdl.BindGPUGraphicsPipeline(render_pass, pipeline_bkg)

	sdl.BindGPUVertexBuffers(
		render_pass, 
		first_slot = 0, 
		bindings = &(sdl.GPUBufferBinding { buffer = grid_vertex_buffer }), 
		num_bindings = 1
	)

	grid_padding := fit_res_x(GRID_PADDING, res)
	grid_offset_ubo := Offset_Ubo { offset = grid_padding }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 2,
		data = &grid_offset_ubo, 
		length = size_of(grid_offset_ubo)
	)

	// grid: vertical lines

	grid_scale_mat := linalg.matrix4_scale_f32({1, res.y, 1})	

	grid_axis_ubo := Axis_Ubo { x_axis = 1 }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 1, 
		data = &grid_axis_ubo, 
		length = size_of(grid_axis_ubo)
	)

	grid_x_left := math.ceil(camera_blend_pos.x / grid_padding) * grid_padding
	grid_pos_mat := linalg.matrix4_translate_f32({grid_x_left, camera_blend_pos.y, 1}) // TODO: z?

	grid_mvp := proj_mat * camera_mat * grid_pos_mat * grid_scale_mat
	grid_mvp_ubo := Mvp_Ubo { mvp = grid_mvp }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		0, 
		&grid_mvp_ubo, 
		size_of(grid_mvp_ubo)
	)

	vertical_instances := sdl.Uint32(math.ceil(res.x / grid_padding))

	sdl.DrawGPUPrimitives(
		render_pass, 
		num_vertices = 2, 
		num_instances = vertical_instances, 
		first_vertex = 0, 
		first_instance = 0
	)

	// grid: horizontal lines

	grid_scale_mat = linalg.matrix4_scale_f32({res.x, 1, 1})	

	grid_axis_ubo = Axis_Ubo { x_axis = 0 }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 1, 
		data = &grid_axis_ubo, 
		length = size_of(grid_axis_ubo)
	)

	grid_y_bottom := math.ceil(camera_blend_pos.y / grid_padding) * grid_padding
	grid_pos_mat = linalg.matrix4_translate_f32({camera_blend_pos.x, grid_y_bottom, 1}) // TODO: z?

	grid_mvp = proj_mat * camera_mat * grid_pos_mat * grid_scale_mat
	grid_mvp_ubo = Mvp_Ubo { mvp = grid_mvp }
	sdl.PushGPUVertexUniformData(
		command_buffer, 
		slot_index = 0, 
		data = &grid_mvp_ubo, 
		length = size_of(grid_mvp_ubo)
	)

	horizontal_instances := sdl.Uint32(math.ceil(res.y / grid_padding))

	sdl.DrawGPUPrimitives(
		render_pass, 
		num_vertices = 2, 
		num_instances = horizontal_instances, 
		first_vertex = 2, 
		first_instance = 0
	)
}

needs_text_render: bool = false
@(private) copy_and_upload_mem :: proc (command_buffer: ^sdl.GPUCommandBuffer, dt: f32)
{
	// copy data into transfer buffer

	inputs_sz := len(batch_shape_inputs) * size_of(Batch_Shape_Input)
	verts_sz := len(batch_shape_verts) * size_of(Batch_Shape_Vertex)
	models_sz := len(batch_shape_models) * size_of(Batch_Shape_Model)

	text_verts_sz := 0 
	text_verts := [dynamic]Text_Vertex {}
	defer { delete(text_verts) }

	text_indices_sz := 0
	text_indices := [dynamic]u32 {}
	defer { delete(text_indices) }

	for item in text_items {
		if item.active {
			needs_text_render = true
			text_verts_sz += len(item.geo_data.vertices) * size_of(Text_Vertex)
			append(&text_verts, ..item.geo_data.vertices[:])
			text_indices_sz += len(item.geo_data.indices) * size_of(u32)
			append(&text_indices, ..item.geo_data.indices[:])
		}
	}

	sprites_sz := len(sprites) * size_of(GPU_Sprite) 

	transfer_memory := transmute([^]byte)sdl.MapGPUTransferBuffer(gpu, transfer_buffer, true) // TODO: should cycle?

	if len(batch_shape_inputs) > 0 {
		mem.copy(
			transfer_memory, 
			raw_data(batch_shape_inputs), 
			inputs_sz
		)
		mem_loc := batch_shape_inputs_byte_size
		mem.copy(
			transfer_memory[mem_loc:], 
			raw_data(batch_shape_verts), 
			verts_sz
		)
		mem_loc += batch_shape_verts_byte_size
		mem.copy(
			transfer_memory[mem_loc:],
			raw_data(batch_shape_models), 
			models_sz
		)
	}
	if needs_text_render {
		mem_loc := batch_shape_inputs_byte_size + batch_shape_verts_byte_size + batch_shape_models_byte_size
		mem.copy(
			transfer_memory[mem_loc:],
			raw_data(text_verts),
			text_verts_sz
		)
		mem_loc += text_vert_buf_byte_size
		mem.copy(
			transfer_memory[mem_loc:],
			raw_data(text_indices),
			text_indices_sz
		)
	}
	if len(sprites) > 0 {
		gpu_sprites: [dynamic]GPU_Sprite
		for spr in sprites {
			append(&gpu_sprites, create_gpu_sprite(spr, dt))
		}

		mem_loc := batch_shape_inputs_byte_size + batch_shape_verts_byte_size + batch_shape_models_byte_size + text_vert_buf_byte_size + text_index_buf_byte_size
		mem.copy(
			transfer_memory[mem_loc:],
			raw_data(gpu_sprites),
			sprites_sz
		)
	}

	sdl.UnmapGPUTransferBuffer(gpu, transfer_buffer)

	// upload to gpu

	copy_pass := sdl.BeginGPUCopyPass(command_buffer)

	if len(batch_shape_inputs) > 0 {
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer
			},
			destination = {
				buffer = batch_shape_inputs_vertex_buffer, 
				size = u32(batch_shape_inputs_byte_size)
			},
			cycle = true
		)
		offset := u32(batch_shape_inputs_byte_size)
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer,
				offset = offset

			},
			destination = {
				buffer = batch_shape_vertex_storage_buffer, 
				size = u32(batch_shape_verts_byte_size)
			},
			cycle = false 
		)
		offset += u32(batch_shape_verts_byte_size)
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer, 
				offset = offset
			},
			destination = {
				buffer = batch_shape_models_storage_buffer, 
				size = u32(batch_shape_models_byte_size)
			},
			cycle = false
		)
	}
	if needs_text_render {
		offset := u32(batch_shape_inputs_byte_size + batch_shape_verts_byte_size + batch_shape_models_byte_size)
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer, 
				offset = offset
			},
			destination = {
				buffer = text_vertex_buffer, 
				size = u32(text_vert_buf_byte_size)
			},
			cycle = false
		)
		offset += u32(text_vert_buf_byte_size)
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer, 
				offset = offset
			},
			destination = {
				buffer = text_index_buffer, 
				size = u32(text_index_buf_byte_size)
			},
			cycle = false
		)
	}
	if len(sprites) > 0 {
		offset := u32(batch_shape_inputs_byte_size + batch_shape_verts_byte_size + batch_shape_models_byte_size  + text_vert_buf_byte_size + text_index_buf_byte_size)
		sdl.UploadToGPUBuffer(
			copy_pass, 
			source = {
				transfer_buffer = transfer_buffer, 
				offset = offset
			},
			destination = {
				buffer = sprite_data_buffer, 
				size = u32(sprite_data_byte_size)
			},
			cycle = false
		)
	}

	sdl.EndGPUCopyPass(copy_pass)
}

