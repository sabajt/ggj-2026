package main

import "core:math/linalg"
import sdl "vendor:sdl3"

// shaders

vs_grid_code := #load("shaders/compiled/msl/Grid.vert.msl")
vs_batch_shape_code := #load("shaders/compiled/msl/BatchShape.vert.msl")
vs_text_code := #load("shaders/compiled/msl/Text.vert.msl")
vs_sprite_code := #load("shaders/compiled/msl/BatchSprite.vert.msl")
vs_fullscreen_quad_code := #load("shaders/compiled/msl/FullscreenQuad.vert.msl")

fs_solid_color_code := #load("shaders/compiled/msl/SolidColor.frag.msl")
fs_sdf_quad_code := #load("shaders/compiled/msl/SDFQuad.frag.msl")
fs_textured_quad_code := #load("shaders/compiled/msl/TexturedQuad.frag.msl")

// shader models

Batch_Shape_Input :: struct {
	vertex_index : uint,
	model_index : uint,
}

Batch_Shape_Vertex :: struct {
	color : [4]f32,
	position : [2]f32,
	padding : [2]f32
}

Batch_Shape_Model :: struct {
    position: [3]f32,
    rotation: f32,
    scale: [2]f32,
    arc_range: [2]f32, // -PI to PI, clockwise, 0 is full range (default)
    color: [4]f32, // overrides vert colors
    thic: f32, // thickness of circle if SDF
    fade: f32, // fade length of circle if SDF
    period: f32, // for solid rendering: 0 -> solid, >=2 -> transparent "stripes"
    padding_b: f32
}

GPU_Sprite :: struct {
	position: [3]f32,
	rotation: f32,
	scale: [2]f32,
	anchor: [2]f32,
	tex_u: f32, tex_v: f32, tex_w: f32, tex_h: f32,
	color: [4]f32
} 

Grid_Vertex :: struct {
	position : [2]f32,
	color : [4]f32 
}

Text_Vertex :: struct {
	position : [2]f32,
	color : [4]f32, 
	uv : [2]f32
}

// shader uniforms

View_Projection :: struct {
	view_projection : linalg.Matrix4x4f32
}

Mvp_Ubo :: struct {
	mvp : linalg.Matrix4x4f32
}

Res_Ubo :: struct {
	res_cam : [4]f32
}

Axis_Ubo :: struct {
	x_axis : uint
}

Offset_Ubo :: struct {
	offset: f32
}

Resolution_Uniform_Buffer:: struct {
	resolution: [2]f32,
	letterbox_resolution: [2]f32
}

// helpers

create_batch_shape_model :: proc(
    pos: [2]f32 = 0,
    rot: f32 = 0,
    scale: [2]f32 = 1,
    col: [4]f32 = 1, 
    thic: f32 = 0,
    fade: f32 = 0, 
    period: f32 = 0) -> Batch_Shape_Model
{
	return Batch_Shape_Model {
		position = {pos.x, pos.y, 1},
		rotation = rot,
		scale = scale,
		color = col,
		thic = thic,
		fade = fade,
		period = period
	}
}

// gpu resources

gpu: ^sdl.GPUDevice

pipeline_fill: ^sdl.GPUGraphicsPipeline
pipeline_sdf: ^sdl.GPUGraphicsPipeline
pipeline_bkg: ^sdl.GPUGraphicsPipeline
pipeline_text: ^sdl.GPUGraphicsPipeline
pipeline_sprite: ^sdl.GPUGraphicsPipeline
pipeline_gradient: ^sdl.GPUGraphicsPipeline
pipeline_letterbox: ^sdl.GPUGraphicsPipeline

grid_vertex_buffer: ^sdl.GPUBuffer
transfer_buffer: ^sdl.GPUTransferBuffer

// letterbox

letterbox_texture: ^sdl.GPUTexture
letterbox_sampler: ^sdl.GPUSampler

// image

sprite_models: [dynamic]GPU_Sprite
sprite_atlas_texture: ^sdl.GPUTexture
sprite_sampler: ^sdl.GPUSampler
sprite_data_buffer: ^sdl.GPUBuffer
sprite_data_byte_size := 8000 * size_of(GPU_Sprite) 

// text

text_vertex_buffer: ^sdl.GPUBuffer
text_index_buffer: ^sdl.GPUBuffer
text_sampler: ^sdl.GPUSampler

text_vert_buf_byte_size := size_of(Text_Vertex) * 4000
text_index_buf_byte_size := size_of(u32) * 6000

// batch fill shapes

batch_shape_inputs := [dynamic]Batch_Shape_Input {}
batch_shape_inputs_byte_size := 80_000 * size_of(Batch_Shape_Input) // TODO: rename max size?
batch_shape_inputs_vertex_buffer : ^sdl.GPUBuffer

batch_shape_verts := [dynamic]Batch_Shape_Vertex {}
batch_shape_verts_byte_size := 40_000 * size_of(Batch_Shape_Vertex) 
batch_shape_vertex_storage_buffer: ^sdl.GPUBuffer

batch_shape_models := [dynamic]Batch_Shape_Model {}
batch_shape_models_byte_size := 20_000 * size_of(Batch_Shape_Model)
batch_shape_models_storage_buffer : ^sdl.GPUBuffer

first_sdf_input := int(0)
last_sdf_input := int(0)


load_shader :: proc(
	device: ^sdl.GPUDevice, 
	code: []u8, 
	stage: sdl.GPUShaderStage, 
	num_samplers: u32 = 0,
	num_uniform_buffers: u32 = 0, 
	num_storage_buffers: u32 = 0,
	num_storage_textures: u32 = 0) -> ^sdl.GPUShader 
{
	return sdl.CreateGPUShader(device, {
		code_size = len(code),
		code = raw_data(code),   
		entrypoint = "main0",
		format = {.MSL},
		stage = stage,
		num_samplers = num_samplers,
		num_uniform_buffers = num_uniform_buffers,
		num_storage_buffers = num_storage_buffers,
		num_storage_textures = num_storage_textures
	})
}

