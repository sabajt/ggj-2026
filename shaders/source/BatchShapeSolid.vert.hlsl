static const float PI = 3.14159265f;

struct Input
{
    uint vertex_index : TEXCOORD0;
    uint model_index : TEXCOORD1;
};

struct Output
{
    float4 position : SV_Position;
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float period : TEXCOORD2;
};

struct Model
{
    float3 position;
    float rotation;
    float4 color;
    float2 scale;
    float period;
    float padding;
};

struct Vertex
{
    float4 color;
    float2 position;
    float2 padding;
};

StructuredBuffer<Vertex> VertexBuffer : register(t0, space0);
StructuredBuffer<Model> ModelBuffer : register(t1, space0);

cbuffer ViewProjection : register(b0, space1)
{
    float4x4 view_projection : packoffset(c0);
};

Output main(Input input)
{
    // get vertex

    uint vertex_index = input.vertex_index;
    Vertex vertex = VertexBuffer[vertex_index];

    // get model

    uint model_index = input.model_index;
    Model model = ModelBuffer[model_index];

    // scale

    float2 pos_2d = vertex.position;
    pos_2d *= model.scale;

    // rotate

    float c = cos(model.rotation);
    float s = sin(model.rotation);
    float2x2 rotation = {c, s, -s, c};
    pos_2d = mul(pos_2d, rotation);

    // translate

    float3 vertex_pos = float3(pos_2d + model.position.xy, model.position.z);

    // build output

    Output output;
    output.position = mul(view_projection, float4(vertex_pos, 1.0f));
    output.color = vertex.color * model.color;
    output.uv = output.position.xy;
    output.period = model.period;

    return output;
}


