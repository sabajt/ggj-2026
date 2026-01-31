cbuffer GradientUniformBuffer : register(b0, space3)
{
    float2 resolution;
    float4 bottom_color;
    float4 top_color;
};

struct Input
{
    float4 position : SV_Position;
};

float4 main(Input input) : SV_Target
{
    float2 pixelCoord = input.position.xy;
    // Normalize to 0-1
    float2 uv = pixelCoord / resolution;

    return lerp(top_color, bottom_color, uv.y);
}
