// Based on:
// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Content/Shaders/Source/PullSpriteBatch.vert.hlsl

struct SpriteData
{
    float3 position;
    float rotation;
    float2 scale;
    float2 anchor; // default is center: {0, 0}. {-0.5, -0.5} for bottom left, etc
    float tex_u, tex_v, tex_w, tex_h;
    float4 color;
};

struct Output
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

// WARNING: StructuredBuffers are not natively supported by SDL's GPU API.
// They will work with SDL_shadercross because it does special processing to
// support them, but not with direct compilation via dxc.
// See https://github.com/libsdl-org/SDL/issues/12200 for details.
StructuredBuffer<SpriteData> DataBuffer : register(t0, space0);

cbuffer ViewProjection : register(b0, space1)
{
    float4x4 view_projection : packoffset(c0);
};

static const uint triangle_indices[6] = {0, 1, 2, 3, 2, 1};
static const float2 vertex_pos[4] = {
    {-0.5f, -0.5f},
    {0.5f, -0.5f},
    {-0.5f, 0.5f},
    {0.5f, 0.5f} // why not -1,1?
};

Output main(uint id : SV_VertexID)
{
    uint sprite_index = id / 6;
    uint vert = triangle_indices[id % 6];
    SpriteData sprite = DataBuffer[sprite_index];

    float2 uv[4] = {
        {sprite.tex_u, sprite.tex_v },
        {sprite.tex_u + sprite.tex_w, sprite.tex_v},
        {sprite.tex_u, sprite.tex_v + sprite.tex_h},
        {sprite.tex_u + sprite.tex_w, sprite.tex_v + sprite.tex_h}
    };

    float c = cos(sprite.rotation);
    float s = sin(sprite.rotation);

    float2 coord = vertex_pos[vert];
    coord += sprite.anchor;
    coord *= sprite.scale;
    float2x2 rotation = {c, s, -s, c};
    coord = mul(coord, rotation);

    float3 coord_with_depth = float3(coord + sprite.position.xy, sprite.position.z);

    Output output;

    output.position = mul(view_projection, float4(coord_with_depth, 1.0f));
    output.uv = uv[vert];
    output.color = sprite.color;

    return output;
}







