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

const vec2 up = vec2(0.0, -1.0);
const vec2 down = vec2(0.0, 1.0);
const vec2 left = vec2(-1.0, 0.0);
const vec2 right = vec2(1.0, 0.0);

void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / vec2(numX, numY);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

    // if (texelFetch(s, cell, 0).r == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
    //     return;
    // }
    bool skip = (texelFetch(s, cell, 0).r == 0.0);

    vec2 cell_l = UV + left * texelSize;
    vec2 cell_r = UV + right * texelSize;
    vec2 cell_u = UV + up * texelSize;
    vec2 cell_d = UV + down * texelSize;

    // float _h = 1.0 / max(consts.numX, consts.numY);
    float _h = 1.0 / 64;

    float u_val = imageLoad(u, cell).r;
    float v_val = imageLoad(v, cell).r;

    u_val -= 0.5 * (texture(p, cell_r).r - texture(p, cell_l).r) / _h;
    v_val -= 0.5 * (texture(p, cell_d).r - texture(p, cell_u).r) / _h;

    u_val = skip ? 0 : u_val;
    v_val = skip ? 0 : v_val;

    imageStore(u, cell, vec4(u_val));
    imageStore(v, cell, vec4(v_val));
}