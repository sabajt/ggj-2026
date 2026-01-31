package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

init :: proc() {
	ok := sdl.Init({.VIDEO, .GAMEPAD, .AUDIO})
	assert(ok)

	window = sdl.CreateWindow("New Project", i32(resolution.x), i32(resolution.y), {})
	// window = sdl.CreateWindow("New Project", i32(resolution.x), i32(resolution.y), {.FULLSCREEN})
	assert(window != nil)

	gpu = sdl.CreateGPUDevice({.MSL, .SPIRV, .DXIL}, true, nil)

	ok = sdl.ClaimWindowForGPUDevice(gpu, window)
	assert(ok)

	letterbox_resolution = get_letterbox_res()

	init_transfer_mem()
	init_pipelines()
	init_assets()
	init_audio()

	enter_main()
}

init_assets :: proc()
{
	load_json_obj("images/sprite_atlas.json", &sprite_atlas)
	for atlas_image in sprite_atlas.Images {
		sprite_atlas_map[atlas_image.Name] = atlas_image
	}
}

init_transfer_mem :: proc()
{
	// setup vertex buffers

	batch_shape_inputs_vertex_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.VERTEX},
		size = u32(batch_shape_inputs_byte_size)
	})

	// setup storage buffers

	batch_shape_vertex_storage_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.GRAPHICS_STORAGE_READ},
		size = u32(batch_shape_verts_byte_size)
	})
	batch_shape_models_storage_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.GRAPHICS_STORAGE_READ},
		size = u32(batch_shape_models_byte_size)
	})

	// grid vertex buffer

	grid_verts := []Grid_Vertex {
		{ position = {0, 0}, color = {1, 0, 0, 1} }, // b
		{ position = {0, 1}, color = {0, 1, 0, 1} }, // t

		{ position = {0, 0}, color = {1, 0, 0, 1} }, // l
		{ position = {1, 0}, color = {0, 0, 1, 1} }, // r
	}
	grid_verts_byte_size := len(grid_verts) * size_of(grid_verts[0]) // TODO: size_of(Grid_Vertex) the same?

	grid_vertex_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.VERTEX},
		size = u32(grid_verts_byte_size)
	})

	// image / sprites

	sprirte_atlas_surface := load_image("images/sprite_atlas.png")

	sprite_atlas_texture = sdl.CreateGPUTexture(gpu, {
		type = .D2,
		format = .R8G8B8A8_UNORM, // should use GetGPUSwapchainTextureFormat???
		width = u32(sprirte_atlas_surface.w),
		height = u32(sprirte_atlas_surface.h),
		layer_count_or_depth = 1,
		num_levels = 1,
		usage = {.SAMPLER}		
	})
	sprite_sampler = sdl.CreateGPUSampler(gpu, {
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		mipmap_mode = .NEAREST, 
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
		address_mode_w = .CLAMP_TO_EDGE
	})

	sprite_data_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.GRAPHICS_STORAGE_READ},
		size = u32(sprite_data_byte_size)
	})

	// sdl ttf
	
	ok := ttf.Init()
	assert(ok)

	// open font based on window size 

	responsive_font_size := resolution.y / 20

	font_sfns_mono = ttf.OpenFont("fonts/SFNSMono.ttf", responsive_font_size) // was 70
	if font_sfns_mono == nil {
		fmt.println("ERROR: Couldn't open font")
	}

	font_sfns_mono_2 = ttf.OpenFont("fonts/SFNSMono.ttf", 20)
	if font_sfns_mono_2 == nil {
		fmt.println("ERROR: Couldn't open font")
	}

	text_engine = ttf.CreateGPUTextEngine(gpu)

	// text vertex and index buffers

	text_vertex_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.VERTEX},
		size = u32(text_vert_buf_byte_size)
	})

	text_index_buffer = sdl.CreateGPUBuffer(gpu, {
		usage = {.INDEX},
		size = u32(text_index_buf_byte_size)
	})

	// text sampler

	text_sampler = sdl.CreateGPUSampler(gpu, {
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		mipmap_mode = .NEAREST, // TODO: need?
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
		address_mode_w = .CLAMP_TO_EDGE, // TODO: need?
	})

	// text geo

	// BAD?: just creating global text_items that next procs depend on?
	text_items = [dynamic]TTF_Text_Item{} 

	// scale sampler / texture

	letterbox_texture = sdl.CreateGPUTexture(gpu, {
		type = .D2,
		format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
		width = u32(letterbox_resolution.x), // this needs to be the aspect ratio max size of window
		height = u32(letterbox_resolution.y),
		layer_count_or_depth = 1,
		num_levels = 1,
		usage = {.COLOR_TARGET, .SAMPLER} // this is following the MSAA example, for "offscreen" sample. is it right?
	})

	letterbox_sampler = sdl.CreateGPUSampler(gpu, {
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		mipmap_mode = .NEAREST, // TODO: need?
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
		address_mode_w = .CLAMP_TO_EDGE, // TODO: need?
	})

	/////////////////////////
	// create main shared transfer buffer for dynamic data
	/////////////////////////

	transfer_buffer_byte_size := batch_shape_inputs_byte_size + 
		batch_shape_verts_byte_size + 
		batch_shape_models_byte_size + 
		text_vert_buf_byte_size + 
		text_index_buf_byte_size + 
		sprite_data_byte_size

	transfer_buffer = sdl.CreateGPUTransferBuffer(gpu, {
		usage = .UPLOAD,
		size = u32(transfer_buffer_byte_size)
	})

	// copy data into temp transfer buffer for static data (grid)

	grid_transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, {
		usage = .UPLOAD,
		size = u32(grid_verts_byte_size)
	})

	transfer_memory := transmute([^]byte)sdl.MapGPUTransferBuffer(gpu, grid_transfer_buffer, false)
	mem.copy(
		transfer_memory,
		raw_data(grid_verts),
		grid_verts_byte_size
	)

	sdl.UnmapGPUTransferBuffer(gpu, grid_transfer_buffer)

	// image

	// TODO: is this actually how to get the size? if so, why?
	tex_image_byte_size := int(sprirte_atlas_surface.w * sprirte_atlas_surface.h * 4)

	tex_transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, {
		usage = .UPLOAD,
		size = u32(tex_image_byte_size)
	})

	tex_transfer_memory := transmute([^]byte)sdl.MapGPUTransferBuffer(gpu, tex_transfer_buffer, false)
	mem.copy(
		tex_transfer_memory,
		sprirte_atlas_surface.pixels,
		tex_image_byte_size
	)

	sdl.UnmapGPUTransferBuffer(gpu, tex_transfer_buffer)

	// upload to gpu

	copy_command_buffer := sdl.AcquireGPUCommandBuffer(gpu) 
	copy_pass := sdl.BeginGPUCopyPass(copy_command_buffer)

	sdl.UploadToGPUBuffer(
		copy_pass, 
		{
			transfer_buffer = grid_transfer_buffer, 
		},
		{
			buffer = grid_vertex_buffer, 
			size = u32(grid_verts_byte_size)
		},
		false
	)

	sdl.UploadToGPUTexture(
		copy_pass, 
		{
			transfer_buffer = tex_transfer_buffer, 
			//offset = 0 // Zeroes out the rest... NEEDED?
		},
		{
			texture = sprite_atlas_texture, 
			w = u32(sprirte_atlas_surface.w),
			h = u32(sprirte_atlas_surface.h),
			d = 1
		},
		false
	)

	sdl.EndGPUCopyPass(copy_pass)
	ok = sdl.SubmitGPUCommandBuffer(copy_command_buffer)
	assert(ok)

	sdl.ReleaseGPUTransferBuffer(gpu, grid_transfer_buffer)
}

init_pipelines :: proc()
{
	// load shaders
	// vert
 	vs_wrap_shape := load_shader(
 		gpu, 
 		vs_batch_shape_code, 
 		.VERTEX, 
 		num_uniform_buffers = 1, 
 		num_storage_buffers = 2
 	)
 	vs_grid := load_shader(
 		gpu, 
 		vs_grid_code, 
 		.VERTEX, 
 		num_uniform_buffers = 3
 	)
	vs_text := load_shader(
		gpu,
		vs_text_code,
		.VERTEX,
		num_uniform_buffers = 1
	)
	vs_sprite := load_shader(
		gpu,
		vs_sprite_code,
		.VERTEX,
		num_uniform_buffers = 1,
		num_storage_buffers = 1
	)
	vs_fullscreen_quad := load_shader(
		gpu,
		vs_fullscreen_quad_code,
		.VERTEX,
		num_uniform_buffers = 1
	)

	// frag
	fs_solid_col := load_shader(
		gpu, 
		fs_solid_color_code, 
		.FRAGMENT, 
		num_uniform_buffers = 1
	)
	fs_sdf_quad := load_shader(
		gpu, 
		fs_sdf_quad_code, 
		.FRAGMENT, 
		num_uniform_buffers = 1
	)
	fs_text := load_shader(
		gpu, 
		fs_textured_quad_code, 
		.FRAGMENT, 
		num_samplers = 1
	)

	// setup base fill pipeline    

	fill_vertex_attributes := []sdl.GPUVertexAttribute {
		{
			location = 0,
			format = .UINT,
			offset = u32(offset_of(Batch_Shape_Input, vertex_index)),
		},
		{
			location = 1,
			format = .UINT,
			offset = u32(offset_of(Batch_Shape_Input, model_index)),
		}
	}  

	color_target : sdl.GPUColorTargetDescription = {
		format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
		blend_state = {
			enable_blend = true,
			color_blend_op = .ADD,
			alpha_blend_op = .ADD,
			src_color_blendfactor = .SRC_ALPHA,
			dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
			src_alpha_blendfactor = .SRC_ALPHA,
			dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA
		}
	}

	pipeline_info : sdl.GPUGraphicsPipelineCreateInfo = {
		vertex_shader = vs_wrap_shape,
		fragment_shader = fs_solid_col,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &color_target,
		},
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = (&sdl.GPUVertexBufferDescription {
				slot = 0,
				pitch = size_of(Batch_Shape_Input),
				input_rate = .VERTEX,
				instance_step_rate = 0
			}),
			num_vertex_attributes = u32(len(fill_vertex_attributes)),
			vertex_attributes = raw_data(fill_vertex_attributes)
		},
	}

	pipeline_fill = sdl.CreateGPUGraphicsPipeline(gpu, pipeline_info)

	// sdf quad pipeline

	pipeline_info.fragment_shader = fs_sdf_quad
	pipeline_sdf =  sdl.CreateGPUGraphicsPipeline(gpu, pipeline_info)

	// background grid pipeline

	grid_vertex_attributes := []sdl.GPUVertexAttribute {
		{
			location = 0,
			format = .FLOAT2,
			offset = u32(offset_of(Grid_Vertex, position)),
		},
		{
			location = 1,
			format = .FLOAT4,
			offset = u32(offset_of(Grid_Vertex, color)),
		}
	}

	grid_vertex_input_state: sdl.GPUVertexInputState = {
		num_vertex_buffers = 1,
		vertex_buffer_descriptions = (&sdl.GPUVertexBufferDescription {
			slot = 0,
			pitch = size_of(Grid_Vertex),
			input_rate = .VERTEX,
			instance_step_rate = 0
		}),
		num_vertex_attributes = u32(len(grid_vertex_attributes)),
		vertex_attributes = raw_data(grid_vertex_attributes)
	}

	pipeline_info.vertex_shader = vs_grid
	pipeline_info.fragment_shader = fs_solid_col
	pipeline_info.primitive_type = .LINELIST
	pipeline_info.vertex_input_state = grid_vertex_input_state

	pipeline_bkg = sdl.CreateGPUGraphicsPipeline(gpu, pipeline_info)

	// ttf text pipeline

	text_vertex_attributes := []sdl.GPUVertexAttribute {
		{
			location = 0,
			format = .FLOAT2,
			offset = u32(offset_of(Text_Vertex, position)),
		},
		{
			location = 1,
			format = .FLOAT4,
			offset = u32(offset_of(Text_Vertex, color)),
		},
		{
			location = 2,
			format = .FLOAT2,
			offset = u32(offset_of(Text_Vertex, uv)),
		},
	}

	text_vertex_input_state: sdl.GPUVertexInputState = {
		num_vertex_buffers = 1,
		vertex_buffer_descriptions = (&sdl.GPUVertexBufferDescription {
			slot = 0,
			pitch = size_of(Text_Vertex),
			input_rate = .VERTEX,
			instance_step_rate = 0
		}),
		num_vertex_attributes = u32(len(text_vertex_attributes)),
		vertex_attributes = raw_data(text_vertex_attributes)
	}

	pipeline_info.vertex_shader = vs_text
	pipeline_info.fragment_shader = fs_text
	pipeline_info.primitive_type = .TRIANGLELIST
	pipeline_info.vertex_input_state = text_vertex_input_state

	pipeline_text = sdl.CreateGPUGraphicsPipeline(gpu, pipeline_info)

	// sprite pipeline

	sprite_pipeline_info : sdl.GPUGraphicsPipelineCreateInfo = {
		vertex_shader = vs_sprite,
		fragment_shader = fs_text,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &color_target,
		}
	}
	pipeline_sprite = sdl.CreateGPUGraphicsPipeline(gpu, sprite_pipeline_info)

	// letterbox pipeline

	letterbox_pipeline_info: sdl.GPUGraphicsPipelineCreateInfo = {
		vertex_shader = vs_fullscreen_quad,
		fragment_shader = fs_text,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &color_target,
		}
	}
	pipeline_letterbox = sdl.CreateGPUGraphicsPipeline(gpu, letterbox_pipeline_info)

	// cleanup

	sdl.ReleaseGPUShader(gpu, vs_wrap_shape)
	sdl.ReleaseGPUShader(gpu, vs_grid)
	sdl.ReleaseGPUShader(gpu, vs_text)
	sdl.ReleaseGPUShader(gpu, vs_sprite)
	sdl.ReleaseGPUShader(gpu, vs_fullscreen_quad)
	sdl.ReleaseGPUShader(gpu, fs_solid_col)
	sdl.ReleaseGPUShader(gpu, fs_sdf_quad)
	sdl.ReleaseGPUShader(gpu, fs_text)
}


