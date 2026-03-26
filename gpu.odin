package main

import "core:math/linalg"
import "core:strings"
import sdl "vendor:sdl3"

vs_batch_shape_solid:^sdl.GPUShader
vs_batch_shape_sdf:^sdl.GPUShader
vs_grid:^sdl.GPUShader
vs_text:^sdl.GPUShader
vs_sprite:^sdl.GPUShader
vs_fullscreen_quad:^sdl.GPUShader
fs_solid_col:^sdl.GPUShader
fs_sdf_quad:^sdl.GPUShader
fs_text:^sdl.GPUShader

vs_grid_code: []u8
vs_batch_shape_solid_code: []u8
vs_batch_shape_sdf_code: []u8
vs_text_code: []u8
vs_sprite_code: []u8
vs_fullscreen_quad_code: []u8
fs_solid_color_code: []u8
fs_sdf_quad_code: []u8
fs_textured_quad_code: []u8

_vs_grid_code_msl := #load("shaders/compiled/msl/Grid.vert.msl")
_vs_batch_shape_solid_code_msl := #load("shaders/compiled/msl/BatchShapeSolid.vert.msl")
_vs_batch_shape_sdf_code_msl := #load("shaders/compiled/msl/BatchShapeSDF.vert.msl")
_vs_text_code_msl := #load("shaders/compiled/msl/Text.vert.msl")
_vs_sprite_code_msl := #load("shaders/compiled/msl/BatchSprite.vert.msl")
_vs_fullscreen_quad_code_msl := #load("shaders/compiled/msl/FullscreenQuad.vert.msl")
_fs_solid_color_code_msl := #load("shaders/compiled/msl/SolidColor.frag.msl")
_fs_sdf_quad_code_msl := #load("shaders/compiled/msl/SDFQuad.frag.msl")
_fs_textured_quad_code_msl := #load("shaders/compiled/msl/TexturedQuad.frag.msl")

_vs_grid_code_dxil := #load("shaders/compiled/dxil/Grid.vert.dxil")
_vs_batch_shape_solid_code_dxil := #load("shaders/compiled/dxil/BatchShapeSolid.vert.dxil")
_vs_batch_shape_sdf_code_dxil := #load("shaders/compiled/dxil/BatchShapeSDF.vert.dxil")
_vs_text_code_dxil := #load("shaders/compiled/dxil/Text.vert.dxil")
_vs_sprite_code_dxil := #load("shaders/compiled/dxil/BatchSprite.vert.dxil")
_vs_fullscreen_quad_code_dxil := #load("shaders/compiled/dxil/FullscreenQuad.vert.dxil")
_fs_solid_color_code_dxil := #load("shaders/compiled/dxil/SolidColor.frag.dxil")
_fs_sdf_quad_code_dxil := #load("shaders/compiled/dxil/SDFQuad.frag.dxil")
_fs_textured_quad_code_dxil := #load("shaders/compiled/dxil/TexturedQuad.frag.dxil")

_vs_grid_code_spv := #load("shaders/compiled/spirv/Grid.vert.spv")
_vs_batch_shape_solid_code_spv := #load("shaders/compiled/spirv/BatchShapeSolid.vert.spv")
_vs_batch_shape_sdf_code_spv := #load("shaders/compiled/spirv/BatchShapeSDF.vert.spv")
_vs_text_code_spv := #load("shaders/compiled/spirv/Text.vert.spv")
_vs_sprite_code_spv := #load("shaders/compiled/spirv/BatchSprite.vert.spv")
_vs_fullscreen_quad_code_spv := #load("shaders/compiled/spirv/FullscreenQuad.vert.spv")
_fs_solid_color_code_spv := #load("shaders/compiled/spirv/SolidColor.frag.spv")
_fs_sdf_quad_code_spv := #load("shaders/compiled/spirv/SDFQuad.frag.spv")
_fs_textured_quad_code_spv := #load("shaders/compiled/spirv/TexturedQuad.frag.spv")

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

Batch_Shape_Solid_Model :: struct {
	position: [3]f32,
	rotation: f32,
	color: [4]f32,
	scale: [2]f32,
	period: f32, // for solid rendering: 0 -> solid, >=2 -> transparent "stripes"
	padding: f32
}

Batch_Shape_SDF_Model :: struct {
    position: [3]f32,
    rotation: f32,
    scale: [2]f32,
    arc_range: [2]f32, // -PI to PI, clockwise, 0 is full range (default)
    color: [4]f32, // overrides vert colors
    thic: f32, // thickness of circle if SDF
    fade: f32, // fade length of circle if SDF
    padding: [2]f32
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

create_batch_shape_solid_model :: proc(
    pos: [2]f32 = 0,
    rot: f32 = 0,
    scale: [2]f32 = 1,
    col: [4]f32 = 1, 
    period: f32 = 0) -> Batch_Shape_Solid_Model
{
	return Batch_Shape_Solid_Model {
		position = {pos.x, pos.y, 1},
		rotation = rot,
		scale = scale,
		color = col,
		period = period
	}
}

create_batch_shape_sdf_model :: proc(
    pos: [2]f32 = 0,
    rot: f32 = 0,
    scale: [2]f32 = 1,
    arc_range: [2]f32 = 0,
    col: [4]f32 = 1,
    thic: f32 = 0,
    fade: f32 = 0) -> Batch_Shape_SDF_Model
{
	return Batch_Shape_SDF_Model {
		position = {pos.x, pos.y, 1},
		rotation = rot,
		scale = scale,
		arc_range = arc_range,
		color = col,
		thic = thic,
		fade = fade,
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

batch_shape_solid_inputs := [dynamic]Batch_Shape_Input {}
batch_shape_solid_inputs_byte_size := 80_000 * size_of(Batch_Shape_Input) // TODO: rename max size?
batch_shape_solid_inputs_vertex_buffer : ^sdl.GPUBuffer

batch_shape_sdf_inputs := [dynamic]Batch_Shape_Input {}
batch_shape_sdf_inputs_byte_size := 80_000 * size_of(Batch_Shape_Input) // TODO: rename max size?
batch_shape_sdf_inputs_vertex_buffer : ^sdl.GPUBuffer

batch_shape_solid_verts := [dynamic]Batch_Shape_Vertex {}
batch_shape_solid_verts_byte_size := 40_000 * size_of(Batch_Shape_Vertex) 
batch_shape_solid_vertex_storage_buffer: ^sdl.GPUBuffer

batch_shape_sdf_verts := [dynamic]Batch_Shape_Vertex {}
batch_shape_sdf_verts_byte_size := 40_000 * size_of(Batch_Shape_Vertex) 
batch_shape_sdf_vertex_storage_buffer: ^sdl.GPUBuffer

batch_shape_solid_models := [dynamic]Batch_Shape_Solid_Model {}
batch_shape_solid_models_byte_size := 20_000 * size_of(Batch_Shape_Solid_Model)
batch_shape_solid_models_storage_buffer : ^sdl.GPUBuffer

batch_shape_sdf_models := [dynamic]Batch_Shape_SDF_Model {}
batch_shape_sdf_models_byte_size := 20_000 * size_of(Batch_Shape_SDF_Model)
batch_shape_sdf_models_storage_buffer : ^sdl.GPUBuffer

first_sdf_input := int(0)
last_sdf_input := int(0)

load_shaders :: proc(device: ^sdl.GPUDevice)
{
	formats := sdl.GetGPUShaderFormats(device)
	format := sdl.GPU_SHADERFORMAT_INVALID
	entrypoint := "main"

	if .MSL in formats {
		format = {.MSL}
		entrypoint = "main0"
		vs_grid_code = _vs_grid_code_msl
		vs_batch_shape_solid_code = _vs_batch_shape_solid_code_msl
		vs_batch_shape_sdf_code = _vs_batch_shape_sdf_code_msl
		vs_text_code = _vs_text_code_msl
		vs_sprite_code = _vs_sprite_code_msl
		vs_fullscreen_quad_code = _vs_fullscreen_quad_code_msl
		fs_solid_color_code = _fs_solid_color_code_msl
		fs_sdf_quad_code = _fs_sdf_quad_code_msl
		fs_textured_quad_code = _fs_textured_quad_code_msl
	} else if .DXIL in formats {
		format = {.DXIL}
		vs_grid_code = _vs_grid_code_dxil
		vs_batch_shape_solid_code = _vs_batch_shape_solid_code_dxil
		vs_batch_shape_sdf_code = _vs_batch_shape_sdf_code_dxil
		vs_text_code = _vs_text_code_dxil
		vs_sprite_code = _vs_sprite_code_dxil
		vs_fullscreen_quad_code = _vs_fullscreen_quad_code_dxil
		fs_solid_color_code = _fs_solid_color_code_dxil
		fs_sdf_quad_code = _fs_sdf_quad_code_dxil
		fs_textured_quad_code = _fs_textured_quad_code_dxil
	} else if .SPIRV in formats {
		format = {.SPIRV}
		vs_grid_code = _vs_grid_code_spv
		vs_batch_shape_solid_code = _vs_batch_shape_solid_code_spv
		vs_batch_shape_sdf_code = _vs_batch_shape_sdf_code_spv
		vs_text_code = _vs_text_code_spv
		vs_sprite_code = _vs_sprite_code_spv
		vs_fullscreen_quad_code = _vs_fullscreen_quad_code_spv
		fs_solid_color_code = _fs_solid_color_code_spv
		fs_sdf_quad_code = _fs_sdf_quad_code_spv
		fs_textured_quad_code = _fs_textured_quad_code_spv
	}

	// vert
 	vs_batch_shape_solid = load_shader(
 		gpu, 
 		vs_batch_shape_solid_code, 
 		.VERTEX,
		format,
		entrypoint,  
 		num_uniform_buffers = 1, 
 		num_storage_buffers = 2
 	)
	vs_batch_shape_sdf = load_shader(
 		gpu, 
 		vs_batch_shape_sdf_code, 
 		.VERTEX,
		format,
		entrypoint,  
 		num_uniform_buffers = 1, 
 		num_storage_buffers = 2
 	)
 	vs_grid = load_shader(
 		gpu, 
 		vs_grid_code, 
 		.VERTEX,
		format,
		entrypoint,  
 		num_uniform_buffers = 3
 	)
	vs_text = load_shader(
		gpu,
		vs_text_code,
		.VERTEX,
		format,
		entrypoint, 
		num_uniform_buffers = 1
	)
	vs_sprite = load_shader(
		gpu,
		vs_sprite_code,
		.VERTEX,
		format,
		entrypoint,
		num_uniform_buffers = 1,
		num_storage_buffers = 1
	)
	vs_fullscreen_quad = load_shader(
		gpu,
		vs_fullscreen_quad_code,
		.VERTEX,
		format,
		entrypoint,
		num_uniform_buffers = 1
	)

	// frag
	fs_solid_col = load_shader(
		gpu, 
		fs_solid_color_code, 
		.FRAGMENT,
		format,
		entrypoint, 
		num_uniform_buffers = 1
	)
	fs_sdf_quad = load_shader(
		gpu, 
		fs_sdf_quad_code, 
		.FRAGMENT,
		format,
		entrypoint,  
		num_uniform_buffers = 1
	)
	fs_text = load_shader(
		gpu, 
		fs_textured_quad_code, 
		.FRAGMENT,
		format,
		entrypoint,  
		num_samplers = 1
	)
}

load_shader :: proc(
	device: ^sdl.GPUDevice, 
	code: []u8, 
	stage: sdl.GPUShaderStage, 
	format: sdl.GPUShaderFormat,
	entrypoint: string,
	num_samplers: u32 = 0,
	num_uniform_buffers: u32 = 0, 
	num_storage_buffers: u32 = 0,
	num_storage_textures: u32 = 0) -> ^sdl.GPUShader 
{
	return sdl.CreateGPUShader(device, {
		code_size = len(code),
		code = raw_data(code),
		entrypoint = strings.clone_to_cstring(entrypoint, context.temp_allocator),
		format = format,
		stage = stage,
		num_samplers = num_samplers,
		num_uniform_buffers = num_uniform_buffers,
		num_storage_buffers = num_storage_buffers,
		num_storage_textures = num_storage_textures
	})
}

