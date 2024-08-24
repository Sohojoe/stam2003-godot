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

layout(set = 0, binding = 1) uniform sampler2D divps_prev;
// layout(set = 0, binding = 2) uniform sampler2D s;
layout(set = 0, binding = 3, rgba16f) uniform image2D divps_out;
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

    // note: we can skip edge check as we do boundary pass after this.
    // bool skip = (idx == 0 || idx >= numX - 1 || idy == 0 || idy >= numY - 1) || texelFetch(s, cell, 0).r == 0.0;
    // bool skip = (texelFetch(s, cell, 0).r == 0.0);

    vec4 divps = texelFetch(divps_prev, cell, 0);
    float div_value = divps.x;
    float p_l = texture(divps_prev, UV + left * texelSize).y;
    float p_r = texture(divps_prev, UV + right * texelSize).y;
    float p_u = texture(divps_prev, UV + up * texelSize).y;
    float p_d = texture(divps_prev, UV + down * texelSize).y;

    // float value = skip ? 0.0 : (div_value + p_l + p_r + p_u + p_d) * 0.25;
    float value = (div_value + p_l + p_r + p_u + p_d) * 0.25;
    divps.y = value;
    // if (!skip) {
    //     imageStore(p, cell, vec4(value));
    // }
    imageStore(divps_out, cell, divps);
}
