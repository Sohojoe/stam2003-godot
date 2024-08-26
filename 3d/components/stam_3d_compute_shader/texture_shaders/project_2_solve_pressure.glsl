#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    uint numZ;
    uint viewX;
    uint viewY;
    uint viewZ;
    float h;
    float h2;
} consts;


layout(set = 0, binding = 3) uniform sampler3D s;
layout(set = 0, binding = 4, r16f) uniform image3D p;
layout(set = 0, binding = 5) uniform sampler3D div;
layout(set = 0, binding = 10) uniform sampler3D p_prev;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int _add_params_here;
// } pc;

const vec3 up = vec3(0.0, -1.0, 0.0);
const vec3 down = vec3(0.0, 1.0, 0.0);
const vec3 left = vec3(-1.0, 0.0, 0.0);
const vec3 right = vec3(1.0, 0.0, 0.0);
const vec3 backwards = vec3(0.0, 0.0, -1.0);
const vec3 forwards = vec3(0.0, 0.0, 1.0);

void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    uint numZ = consts.numZ;
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(numX, numY, numZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;

    // note: we can skip edge check as we use texture boundary
    // bool skip = (idx == 0 || idx >= numX - 1 || idy == 0 || idy >= numY - 1) || texelFetch(s, cell, 0).r == 0.0;
    // bool skip = (texelFetch(s, cell, 0).r == 0.0);

    float div_value = texelFetch(div, cell, 0).r;
    float p_l = texture(p_prev, UVW + left * texelSize).r;
    float p_r = texture(p_prev, UVW + right * texelSize).r;
    float p_u = texture(p_prev, UVW + up * texelSize).r;
    float p_d = texture(p_prev, UVW + down * texelSize).r;
    float p_b = texture(p_prev, UVW + backwards * texelSize).r;
    float p_f = texture(p_prev, UVW + forwards * texelSize).r;

    // float value = skip ? 0.0 : (div_value + p_l + p_r + p_u + p_d) * 0.25;
    float value = (div_value + p_l + p_r + p_u + p_d + p_b + p_f) * 0.16666666666666666666666666666667;

    // if (!skip) {
    //     imageStore(p, cell, vec4(value));
    // }
    imageStore(p, cell, vec4(value));
}