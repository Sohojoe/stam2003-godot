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

uint morton2D(uint x, uint y) {
    x = (x | (x << 8)) & 0x00FF00FF;
    x = (x | (x << 4)) & 0x0F0F0F0F;
    x = (x | (x << 2)) & 0x33333333;
    x = (x | (x << 1)) & 0x55555555;

    y = (y | (y << 8)) & 0x00FF00FF;
    y = (y | (y << 4)) & 0x0F0F0F0F;
    y = (y | (y << 2)) & 0x33333333;
    y = (y | (y << 1)) & 0x55555555;

    return x | (y << 1);
}

void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint index = morton2D(idx, idy);
    uint s_cell = idy * consts.numX + idx;
    uint s_cell_left = s_cell-1;


    if (idx > 0 && idy < consts.numY - 1) {
    // if (idx > 0 && idy < 102 - 1) {
        if (s_buffer.s[s_cell] != 0.0 && s_buffer.s[s_cell_left] != 0.0) {
            u_buffer.u[index] += pc.x_vel_step; 
            v_buffer.v[index] += pc.y_vel_step;
        }
    }
}