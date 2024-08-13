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

// layout(set = 0, binding = 1, std430) buffer UBuffer {
//     float u[];
// } u_buffer;

// layout(set = 0, binding = 2, std430) buffer VBuffer {
//     float v[];
// } v_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;

layout(set = 0, binding = 4, std430) buffer PBuffer {
    float p[];
} p_buffer;

layout(set = 0, binding = 5, std430) readonly buffer DivBuffer {
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

layout(set = 0, binding = 10, std430) readonly buffer PBufferPrev {
    float p[];
} p_buffer_prev;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint cell = idy * consts.numX + idx;

    if (s_buffer.s[cell] == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
        // p_buffer.p[cell] = 0.0;
        return;
    }
    p_buffer.p[cell] = (
        div_buffer.div[cell] + 
        p_buffer_prev.p[cell - 1] + 
        p_buffer_prev.p[cell + 1] + 
        p_buffer_prev.p[cell - consts.numX] + 
        p_buffer_prev.p[cell + consts.numX]
    ) * 0.25;
}


// reference: 
// uint morton2D(uint x, uint y) {
//     uint morton = 0;
//     for (uint i = 0; i < 32; ++i) { // Assuming 32-bit integers
//         morton |= ((x & (1 << i)) << i) | ((y & (1 << i)) << (i + 1));
//     }
//     return morton;
// }
// uint morton2D(uint x, uint y) {
//     x = (x | (x << 8)) & 0x00FF00FF;
//     x = (x | (x << 4)) & 0x0F0F0F0F;
//     x = (x | (x << 2)) & 0x33333333;
//     x = (x | (x << 1)) & 0x55555555;

//     y = (y | (y << 8)) & 0x00FF00FF;
//     y = (y | (y << 4)) & 0x0F0F0F0F;
//     y = (y | (y << 2)) & 0x33333333;
//     y = (y | (y << 1)) & 0x55555555;

//     return x | (y << 1);
// }


// uint morton3D(uint x, uint y, uint z) {
//     uint morton = 0;
//     for (uint i = 0; i < 21; ++i) { // Assuming 21 bits for each coordinate (since 21*3=63 < 64)
//         morton |= ((x & (1 << i)) << (2 * i)) | 
//                  ((y & (1 << i)) << (2 * i + 1)) | 
//                  ((z & (1 << i)) << (2 * i + 2));
//     }
//     return morton;
// }

// void main() {
//     uint idx = gl_GlobalInvocationID.x;
//     uint idy = gl_GlobalInvocationID.y;
//     uint cell = morton2D(idx, idy);

//     if (s_buffer.s[cell] == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
//         return;
//     }
//     p_buffer.p[cell] = (
//         div_buffer.div[cell] + 
//         p_buffer_prev.p[morton2D(idx-1, idy)] + 
//         p_buffer_prev.p[morton2D(idx+1, idy)] + 
//         p_buffer_prev.p[morton2D(idx, idy-1)] + 
//         p_buffer_prev.p[morton2D(idx, idy+1)]
//     ) * 0.25;
// }