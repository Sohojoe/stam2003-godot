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

layout(set = 0, binding = 1, r16f) uniform image2D u;
layout(set = 0, binding = 2, r16f) uniform image2D v;
layout(set = 0, binding = 8, r16f) uniform image2D t;
layout(set = 0, binding = 11) uniform sampler2D i;

// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
// } pc;

void main() {

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint N = consts.numX -1;

    if (idx >= N || idy >= N) return;
    ivec2 cell = ivec2(idx, idy);

    // todo: add check for if cell if free or not

    if (texelFetch(i, cell, 0).r == 1.0) {
        imageStore(t, cell, vec4(1.0));
        // imageStore(u, cell, vec4(0.0));
        // imageStore(v, cell, vec4(0.0));
    }
}