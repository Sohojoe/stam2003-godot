#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    int numX;
    int numY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 1, std430) readonly buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) readonly buffer VBuffer {
    float v[];
} v_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;

// layout(set = 0, binding = 4, std430) buffer PBuffer {
//     float p[];
// } p_buffer;

layout(set = 0, binding = 5, std430) buffer DivBuffer {
    float div[];
} div_buffer;

// layout(set = 0, binding = 6, std430) readonly buffer ROUBuffer {
//     float u[];
// } ro_u_buffer;

// layout(set = 0, binding = 7, std430) readonly buffer ROVBuffer {
//     float v[];
// } ro_v_buffer;

// layout(set = 0, binding = 8, std430) buffer TBuffer {
//     float t[];
// } t_buffer;

// layout(set = 0, binding = 9, std430) readonly buffer ROTBuffer {
//     float t[];
// } ro_t_buffer;

// layout(set = 0, binding = 10, std430) readonly buffer PBufferPrev {
//     float p[];
// } p_buffer_prev;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint cell = idy * consts.numX + idx;

    // compute divergence
    if (s_buffer.s[cell] == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
        return;
    }

    uint cell_l	= cell - 1;
    uint cell_r	= cell + 1;
    uint cell_u	= cell - consts.numX;
    uint cell_d	= cell + consts.numX;

    div_buffer.div[cell] = 0.5 * (
        u_buffer.u[cell_r] -
        u_buffer.u[cell_l] + 
        v_buffer.v[cell_d] - 
        v_buffer.v[cell_u]);

}