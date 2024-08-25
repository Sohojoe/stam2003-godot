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

layout(set = 0, binding = 1) uniform sampler2D uvst_in;
layout(set = 0, binding = 2, rgba16f) uniform image2D uvst_out;
layout(set = 0, binding = 3) uniform sampler2D i;

// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
// } pc;

void main() {

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    // uint N = consts.numX -1;

    // if (idx >= N || idy >= N) return;
    ivec2 cell = ivec2(idx, idy);

    // todo: add check for if cell if free or not

    if (texelFetch(i, cell, 0).r == 1.0) {
        vec4 uvst = texture(uvst_in, cell);
        uvst.a = 1.0;
        imageStore(uvst_out, cell, uvst);
    }
}