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

layout(set = 0, binding = 1) uniform sampler2D p;
layout(set = 0, binding = 2) uniform sampler2D uvst_in;
layout(set = 0, binding = 3, rgba16f) uniform image2D uvst_out;
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
    vec4 uvst = texelFetch(uvst_in, cell, 0);
    bool skip = uvst.z == 1.0;

    vec2 cell_l = UV + left * texelSize;
    vec2 cell_r = UV + right * texelSize;
    vec2 cell_u = UV + up * texelSize;
    vec2 cell_d = UV + down * texelSize;

    // float _h = 1.0 / max(consts.numX, consts.numY);
    float _h = 1.0 / 64;

    uvst.x -= 0.5 * (texture(p, cell_r).r - texture(p, cell_l).r) / _h;
    uvst.y -= 0.5 * (texture(p, cell_d).r - texture(p, cell_u).r) / _h;

    uvst.x = skip ? 0 : uvst.x;
    uvst.y = skip ? 0 : uvst.y;

    imageStore(uvst_out, cell, uvst);
}