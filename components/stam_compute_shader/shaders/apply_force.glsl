#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    int numX;
    int numY;
} consts;

layout(set = 0, binding = 1, std430) buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) buffer VBuffer {
    float v[];
} v_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;

// layout(set = 0, binding = 4, std430) buffer PBuffer {
//     float p[];
// } p_buffer;

// layout(set = 0, binding = 5, std430) buffer DivBuffer {
//     float div[];
// } div_buffer;
// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float x_vel_step; 
    float y_vel_step; 
} pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint index = idy * consts.numX + idx;
    // uint index = idy * 102 + idx;

    if (idx > 0 && idy < consts.numY - 1) {
    // if (idx > 0 && idy < 102 - 1) {
        if (s_buffer.s[index] != 0.0 && s_buffer.s[index - 1] != 0.0) {
            u_buffer.u[index] += pc.x_vel_step; 
            v_buffer.v[index] += pc.y_vel_step;
        }
    }
}