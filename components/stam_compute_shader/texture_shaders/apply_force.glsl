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

layout(set = 0, binding = 1, r32f) uniform image2D u;
layout(set = 0, binding = 2, r32f) uniform image2D v;
layout(set = 0, binding = 3) uniform sampler2D s;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float x_vel_step; 
    float y_vel_step; 
} pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    ivec2 cell = ivec2(idx, idy);
    ivec2 cell_left = ivec2(idx-1, idy);

    if (idx > 0 && idy < consts.numY - 1) {
    // if (idx > 0 && idy < 102 - 1) {
        if (texelFetch(s, cell, 0).r != 0.0 && texelFetch(s, cell_left, 0).r  != 0.0) {
            float u_val = imageLoad(u, cell).r + pc.x_vel_step;
            float v_val = imageLoad(v, cell).r + pc.y_vel_step;
            imageStore(u, cell, vec4(u_val));
            imageStore(v, cell, vec4(v_val));
        }
    }
}