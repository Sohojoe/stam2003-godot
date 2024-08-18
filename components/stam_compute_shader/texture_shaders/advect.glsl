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

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint N = consts.numX -1;

    if (idx >= N || idy >= N) return;

    // float dt0 = pc.dt * N;
    float dt0 = pc.dt * 64; // was N but we want constant scale at different grid sizes
    uint i = idx;
    uint j = idy;
    ivec2 cell = ivec2(idx, idy);

    float x = i - dt0 * texelFetch(u, cell, 0).r;
    float y = j - dt0 * texelFetch(v, cell, 0).r;

    if (x < 0.5) x = 0.5;
    if (x > N + 0.5) x = N + 0.5;
    int i0 = int(x);
    int i1 = i0 + 1;

    if (y < 0.5) y = 0.5;
    if (y > N + 0.5) y = N + 0.5;
    int j0 = int(y);
    int j1 = j0 + 1;

    float s1 = x - float(i0);
    float s0 = 1.0 - s1;
    float t1 = y - float(j0);
    float t0 = 1.0 - t1;

    float value = s0 * (t0 * texelFetch(read_texture, ivec2(i0, j0), 0).r + 
                        t1 * texelFetch(read_texture, ivec2(i0, j1), 0).r) +
                  s1 * (t0 * texelFetch(read_texture, ivec2(i1, j0), 0).r + 
                        t1 * texelFetch(read_texture, ivec2(i1, j1), 0).r);

    imageStore(write_texture, cell, vec4(value));

}