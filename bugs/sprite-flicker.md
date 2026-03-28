
In render.odin, sprites_sz on line 582 uses len(sprites) (the full map including invisible sprites) but should use len(gpu_sprites) (the packed visible subset). This causes a buffer overread on Windows, making sprites flicker. Same fix needed on line 768 for the upload guard.

sprites_sz := len(sprites) * size_of(GPU_Sprite)
sprites is a map[int]Sprite — all sprites, including invisible ones. But the actual gpu_sprites buffer only contains the visible/packed subset. So sprites_sz is too large, and the mem.copy on line 647 reads past the end of gpu_sprites into garbage memory.

Then on line 768 the upload guard also checks len(sprites) instead of len(gpu_sprites).

The reason it's Windows-specific: Mac memory likely happens to be zeroed beyond the array (Metal/OS behavior), while Windows ends up with stale/garbage data in that region, corrupting the sprite buffer.

----

The SV_VertexID + StartVertexLocation Bug
Why it happens
BatchSprite.vert.hlsl has no vertex input attributes — it derives everything from SV_VertexID:


uint sprite_index = id / 6;   // which sprite in DataBuffer
uint vert = triangle_indices[id % 6];  // which corner
When you draw z-layer sprites, render_sprites calls:


sdl.DrawGPUPrimitives(
    render_pass,
    u32(current_batch_len) * 6,
    num_instances = 1,
    first_vertex = u32(current_batch_start * 6),  // e.g. 6*5 = 30 for z=1
    first_instance = 0
)
The intent is: "give me vertices 30–71 so SV_VertexID will be 30–71, and id / 6 will give sprite indices 5–11."

The D3D12 spec says SV_VertexID for DrawInstanced equals VertexID + StartVertexLocation. So this should work. But there's a catch:

SDL3's GPU API with BindGPUVertexStorageBuffers (no vertex input state) and shadercross-compiled DXIL may not behave this way. The StructuredBuffer path involves special shadercross rewriting (see the warning comment in the shader itself). The compiled DXIL uses a resource binding indirection — and in that path, some D3D12 drivers/implementations start SV_VertexID at 0 regardless of StartVertexLocation when there's no IASetVertexBuffers call. No vertex buffer = no IA stage = StartVertexLocation silently ignored.

Result: z=1 draw call asks for sprites 5–11, but shader reads DataBuffer[0]–DataBuffer[5]. z=0 sprites get drawn twice, last z=2 sprite never drawn.

The Fix
Pass current_batch_start as a second uniform to the shader, so it doesn't need first_vertex to offset at all. Always draw from first_vertex = 0.

1. shaders/source/BatchSprite.vert.hlsl — add a second cbuffer and use it:


cbuffer SpriteOffset : register(b0, space2)
{
    uint base_sprite_index : packoffset(c0);
};
And change line 42:


uint sprite_index = id / 6;
to:


uint sprite_index = (id / 6) + base_sprite_index;
2. gpu.odin — bump vs_sprite to 2 uniform buffers (line ~324):


num_uniform_buffers = 2,  // was 1
num_storage_buffers = 1
3. render.odin — push the base index and zero first_vertex:


// After pushing view_projection (slot 0), push base sprite index (slot 1)
base_sprite_index := u32(current_batch_start)
sdl.PushGPUVertexUniformData(
    command_buffer,
    slot_index = 1,
    data = &base_sprite_index,
    length = size_of(base_sprite_index)
)

sdl.DrawGPUPrimitives(
    render_pass,
    u32(current_batch_len) * 6,
    num_instances = 1,
    first_vertex = 0,           // was current_batch_start * 6
    first_instance = 0
)
Then recompile the shader (compile.sh / shadercross) to get new DXIL/MSL/SPIRV.

The Mac/Metal path doesn't hit this because Metal handles SV_VertexID + vertex offsets correctly even with storage buffers, and MSL doesn't go through the shadercross StructuredBuffer rewriting.
