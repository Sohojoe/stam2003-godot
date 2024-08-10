#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;


// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 1, std430) buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) buffer VBuffer {
    float v[];
} v_buffer;

layout(set = 0, binding = 8, std430) buffer TBuffer {
    float t[];
} t_buffer;

layout(set = 0, binding = 11, std430) readonly buffer IBuffer {
    float i[];
} i_buffer;

// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
// } pc;

void main() {

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint N = consts.numX -1;

    if (idx >= N || idy >= N) return;
    uint cell = idy * consts.numX + idx;

    // todo: add check for if cell if free or not

    if (i_buffer.i[cell] == 1.0) {
        t_buffer.t[cell] = 1.0;
        u_buffer.u[cell] = 0.0;
        v_buffer.v[cell] = 0.0;
    }
}