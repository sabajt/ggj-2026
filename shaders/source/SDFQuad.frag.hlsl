// Circle SDF function

static const float PI = 3.14159265f;

cbuffer ResUBO : register(b0, space3)
{
    float4 res_cam : packoffset(c0);
};

// TODO: since it's quad, can use a hard-coded vertices for it (in vert shader)
// instead of combine w/ pos col transform vert shader?

float4 main(float4 Color: TEXCOORD0, float2 uv: TEXCOORD1, float period: TEXCOORD2, float2 model_pos: TEXCOORD3, float2 model_scale: TEXCOORD4, float thic: TEXCOORD5, float fade: TEXCOORD6, float2 arc_range: TEXCOORD7) : SV_Target0
{
    // convert clip space uv (-1 to 1) to normalized uv (0 to 1) 
    float2 norm_uv = uv / 2.0 + float2(0.5, 0.5);

    // convert normalized uv (0 to 1) to screen space uv (screen resolution)
    float2 coord = norm_uv * res_cam.xy;

    // // get distance from current point to center of circle
    float2 dis = coord - (model_pos - res_cam.zw);

    // define radius of circle
    float radius = min(model_scale.x / 2.0, model_scale.y / 2.0);

    // get 0 or 1 value based on radius, distance to center, and thickness to determine if frag is rendered
    // TODO: can do without branching?
    float a = 1;
    float len = length(dis);

    // draw segments(s): -PI to PI
    float ang = atan2(dis.y, dis.x);
    float sa0 = arc_range[0];
    float ea0 = arc_range[1];
    float sa1 = arc_range[0];
    float ea1 = arc_range[1];
    if (sa0 == 0 && ea0 == 0) {
        sa0 = -PI;
        ea0 = PI;
    } else if (sa0 > ea0) {
        sa0 = -PI;
        ea0 = arc_range[1];
        sa1 = arc_range[0];
        ea1 = PI;
    }
    bool should_show = (ang > sa0 && ang < ea0) || (ang > sa1 && ang < ea1);

    if (len > radius || (thic > 0 && len < (radius - thic)) || !should_show) {
        a = 0;
    } else if (fade > 0) {
        float inner_edge = (radius - thic) + fade;
        if (len > inner_edge) {
            a = min((radius - len) / fade, 1);
        } else {
            a = 1.0 - min((inner_edge - len) / fade, 1);
        }
    } 
    Color.a *= a;

    return Color;
}
