cbuffer ResUBO : register(b0, space3)
{
    float4 res_cam : packoffset(c0);
};

float4 main(float4 color : TEXCOORD0, float2 uv: TEXCOORD1, float period: TEXCOORD2) : SV_Target0
{
    // convert clip space uv (-1 to 1) to normalized uv (0 to 1) 
    float2 norm_uv = uv / 2.0 + float2(0.5, 0.5);

    // convert normalized uv (0 to 1) to screen space uv (screen resolution)
    float2 coord = norm_uv * res_cam.xy;

    // stripes if period 
    // don't divide by zero, don't branch?
    float n = (period > 0) * ((coord.x / period) % period); 
    color.a = (period > 0) * ((n < period / 2.0) * 0 + (n >= period / 2.0) * color.a) + (period <= 0) * color.a;

    return color;
}
