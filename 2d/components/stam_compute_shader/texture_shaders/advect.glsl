#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    uint viewX;
    uint viewY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 1) uniform sampler2D read_texture;
layout(set = 0, binding = 2, rgba16f) uniform writeonly image2D write_texture;
// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
} pc;


void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / vec2(numX, numY);
    // vec2 UV = (vec2(cell) + 0.5) * texelSize;

    // uint N = consts.numX -1;
    // float dt0 = pc.dt * N;
    float dt0 = pc.dt * 64; // was N but we want constant scale at different grid sizes

    vec4 cell_value = texelFetch(read_texture, cell, 0);
    vec2 xy = vec2(cell) - dt0 * cell_value.xy;

    vec4 value = texture(read_texture, (xy + 0.5) * texelSize);

    value.b = cell_value.b;
    imageStore(write_texture, cell, value);

}