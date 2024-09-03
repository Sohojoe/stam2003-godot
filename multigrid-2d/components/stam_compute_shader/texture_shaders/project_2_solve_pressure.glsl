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

const vec2 up = vec2(0.0, -1.0);
const vec2 down = vec2(0.0, 1.0);
const vec2 left = vec2(-1.0, 0.0);
const vec2 right = vec2(1.0, 0.0);

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / imageSize(p);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

    // note: we can skip edge check as we use texture boundary
    // bool skip = (idx == 0 || idx >= numX - 1 || idy == 0 || idy >= numY - 1) || texelFetch(s, cell, 0).r == 0.0;
    // bool skip = (texelFetch(s, cell, 0).r == 0.0);

    float div_value = texelFetch(div, cell, 0).r;
    float p_l = texture(p_prev, UV + left * texelSize).r;
    float p_r = texture(p_prev, UV + right * texelSize).r;
    float p_u = texture(p_prev, UV + up * texelSize).r;
    float p_d = texture(p_prev, UV + down * texelSize).r;

    // float value = skip ? 0.0 : (div_value + p_l + p_r + p_u + p_d) * 0.25;
    float value = (div_value + p_l + p_r + p_u + p_d) * 0.25;

    // if (!skip) {
    //     imageStore(p, cell, vec4(value));
    // }
    imageStore(p, cell, vec4(value));
}