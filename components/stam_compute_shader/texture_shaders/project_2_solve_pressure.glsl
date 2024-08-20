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

layout(set = 0, binding = 3) uniform sampler2D s;
layout(set = 0, binding = 4, r16f) uniform image2D p;
layout(set = 0, binding = 5) uniform sampler2D div;
layout(set = 0, binding = 10) uniform sampler2D p_prev;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    ivec2 cell = ivec2(idx, idy);

    if (texelFetch(s, cell, 0).r == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
        // p_buffer.p[cell] = 0.0;
        return;
    }

    ivec2 cell_l = ivec2(idx-1, idy);
    ivec2 cell_r = ivec2(idx+1, idy);
    ivec2 cell_u = ivec2(idx, idy-1);
    ivec2 cell_d = ivec2(idx, idy+1);

    float value = (
        texelFetch(div, cell, 0).r + 
        texelFetch(p_prev, cell_l, 0).r + 
        texelFetch(p_prev, cell_r, 0).r + 
        texelFetch(p_prev, cell_u, 0).r + 
        texelFetch(p_prev, cell_d, 0).r
    ) * 0.25;

    imageStore(p, cell, vec4(value));

}
