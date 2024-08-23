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

layout(set = 0, binding = 1) uniform sampler2D u;
layout(set = 0, binding = 2) uniform sampler2D v;
layout(set = 0, binding = 3) uniform sampler2D s;

layout(set = 0, binding = 4) uniform writeonly image2D write_texture;
layout(set = 0, binding = 5) uniform sampler2D read_texture;
// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
} pc;


void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / vec2(numX, numY);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;
    // uint N = consts.numX -1;

    // float dt0 = pc.dt * N;
    float dt0 = pc.dt * 64; // was N but we want constant scale at different grid sizes

    float x = cell.x - dt0 * texture(u, UV).r;
    float y = cell.y - dt0 * texture(v, UV).r;

    // x = clamp(x, 0.5, N + 0.5);
    int i0 = int(x);
    int i1 = i0 + 1;

    // y = clamp(y, 0.5, N + 0.5);
    int j0 = int(y);
    int j1 = j0 + 1;

    float s1 = x - float(i0);
    float s0 = 1.0 - s1;
    float t1 = y - float(j0);
    float t0 = 1.0 - t1;

    float value = s0 * (t0 * texture(read_texture, vec2(i0, j0) * texelSize).r + 
                        t1 * texture(read_texture, vec2(i0, j1) * texelSize).r) +
                  s1 * (t0 * texture(read_texture, vec2(i1, j0) * texelSize).r + 
                        t1 * texture(read_texture, vec2(i1, j1) * texelSize).r);

    imageStore(write_texture, cell, vec4(value));

}