cbuffer Mvp : register(b0, space1)
{
    float4x4 mvp : packoffset(c0);
};

cbuffer Axis : register(b1, space1)
{
    uint x_axis : packoffset(c0);
}

cbuffer Offset : register(b2, space1)
{
    float offset: packoffset(c0);
}

struct Input
{
    uint instance_index : SV_InstanceID;
    float2 position : TEXCOORD0;
    float4 color: TEXCOORD1; 
};

struct Output
{
    float4 position : SV_Position;
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float period : TEXCOORD2;
};

Output main(Input input)
{
    float2 pos = input.position;

    // TODO: could make more flexible by calc from screen space
    float off = input.instance_index * offset;

    if (x_axis == 1) {
        pos.x += off;
    } else {
        pos.y += off;
    }

    Output output;
    output.color = input.color;
    output.position = mul(mvp, float4(pos, 0.0, 1.0f));
    output.uv = output.position.xy;
    output.period = 0;

    return output;
}
