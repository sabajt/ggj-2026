static const uint QUAD_INDICES[6] = {0, 1, 2, 3, 2, 1};
static const float2 VERTEX_POSITIONS[4] = {
    {-1.0f, -1.0f}, // left
    {1.0f, -1.0f}, // r
    {-1.0f, 1.0f}, // left
    {1.0f, 1.0f} // r
};
static const float2 UV_POSITIONS[4] = {
    {0.0f, 0.0f}, 
    {1.0f, 0.0f},
    {0.0f, 1.0f}, 
    {1.0f, 1.0f} 
};

cbuffer ResolutionUniformBuffer : register(b0, space1)
{
    float2 resolution;
    float2 letterbox_resolution;
};

struct Output
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

Output main(uint id: SV_VertexID)
{
    Output output;
    uint i = QUAD_INDICES[id];
    float2 pos = VERTEX_POSITIONS[i];

    // transform the coordinates to fit into letter box
    float letter_pad_x = (resolution.x - letterbox_resolution.x) / resolution.x;
    float pos_x = pos.x < 1 ? pos.x + letter_pad_x : pos.x - letter_pad_x;

    float letter_pad_y = (resolution.y - letterbox_resolution.y) / resolution.y;
    float pos_y = pos.y < 1 ? pos.y + letter_pad_y : pos.y - letter_pad_y;

    // had to flip y when using this as post process for main render target
    // why does y have to be flipped? 
    output.position = float4(pos_x, -pos_y, 1, 1);
    output.color = float4(1, 1, 1, 1);
    output.uv = UV_POSITIONS[i];

    return output;
}
