cbuffer Mvp : register(b0, space1)
{
    float4x4 mvp : packoffset(c0);
};

struct Input
{
    float2 position : TEXCOORD0;
    float4 color : TEXCOORD1;
    float2 uv : TEXCOORD2;
};

struct Output
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

Output main(Input input)
{
    Output output;
    output.color = input.color;
    output.uv = input.uv;
    output.position = mul(mvp, float4(input.position, 0.0f, 1.0f));
    return output;
}


