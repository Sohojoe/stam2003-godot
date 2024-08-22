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
layout(set = 0, binding = 3) uniform sampler2D s;
layout(set = 0, binding = 4) uniform sampler2D p;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;


void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    ivec2 cell = ivec2(idx, idy);

    // if (texelFetch(s, cell, 0).r == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
    //     return;
    // }
    bool skip = (texelFetch(s, cell, 0).r == 0.0);

    ivec2 cell_l = ivec2(idx-1, idy);
    ivec2 cell_r = ivec2(idx+1, idy);
    ivec2 cell_u = ivec2(idx, idy-1);
    ivec2 cell_d = ivec2(idx, idy+1);

    // float _h = 1.0 / max(consts.numX, consts.numY);
    float _h = 1.0 / 64;

    float u_val = imageLoad(u, cell).r;
    float v_val = imageLoad(v, cell).r;

    u_val -= 0.5 * (texelFetch(p, cell_r, 0).r - texelFetch(p, cell_l, 0).r) / _h;
    v_val -= 0.5 * (texelFetch(p, cell_d, 0).r - texelFetch(p, cell_u, 0).r) / _h;

    u_val = skip ? 0 : u_val;
    v_val = skip ? 0 : v_val;

    imageStore(u, cell, vec4(u_val));
    imageStore(v, cell, vec4(v_val));
}