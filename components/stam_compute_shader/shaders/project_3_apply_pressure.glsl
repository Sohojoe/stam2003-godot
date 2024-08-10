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

layout(set = 0, binding = 1, std430) buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) buffer VBuffer {
    float v[];
} v_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;

layout(set = 0, binding = 4, std430) readonly buffer PBuffer {
    float p[];
} p_buffer;

// layout(set = 0, binding = 5, std430) buffer DivBuffer {
//     float div[];
// } div_buffer;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint cell = idy * consts.numX + idx;

    if (s_buffer.s[cell] == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
        return;
    }

    float _h = 1.0 / max(consts.numX, consts.numY);

    u_buffer.u[cell] -= 0.5 * (p_buffer.p[cell + 1] - p_buffer.p[cell - 1]) / _h;
    v_buffer.v[cell] -= 0.5 * (p_buffer.p[cell + consts.numX] - p_buffer.p[cell - consts.numX]) / _h;

}