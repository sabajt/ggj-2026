cbuffer ResUBO : register(b0, space3)
{
    float4 res_cam : packoffset(c0);
};

struct Input {
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float period : TEXCOORD2;
    float2 model_pos : TEXCOORD3;
    float2 model_scale : TEXCOORD4;
    float thic : TEXCOORD5;
    float fade : TEXCOORD6;
    float2 arc_range : TEXCOORD7;
};

float4 main(Input input) : SV_Target0
{
    // convert clip space uv (-1 to 1) to normalized uv (0 to 1) 
    float2 norm_uv = input.uv / 2.0 + float2(0.5, 0.5);

    // convert normalized uv (0 to 1) to screen space uv (screen resolution)
    float2 coord = norm_uv * res_cam.xy;

    // stripes if period
    // don't divide by zero, don't branch?
    float n = (input.period > 0) * ((coord.x / input.period) % input.period);
    input.color.a = (input.period > 0) * ((n < input.period / 2.0) * 0 + (n >= input.period / 2.0) * input.color.a) + (input.period <= 0) * input.color.a;

    return input.color;
}
