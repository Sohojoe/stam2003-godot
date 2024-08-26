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


layout(set = 0, binding = 1) uniform sampler3D uvwt_in;
layout(set = 0, binding = 2) uniform sampler3D s;
layout(set = 0, binding = 3, r16f) uniform image3D p;
layout(set = 0, binding = 4, r16f) uniform image3D div;

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

    vec4 uvwt = texelFetch(uvwt_in, cell, 0);

    bool skip = texelFetch(s, cell, 0).r == 1.0;

    vec3 cell_l = UVW + left * texelSize;
    vec3 cell_r = UVW + right * texelSize;
    vec3 cell_u = UVW + up * texelSize;
    vec3 cell_d = UVW + down * texelSize;
    vec3 cell_b = UVW + backwards * texelSize;
    vec3 cell_f = UVW + forwards * texelSize;

    // float _h = 1.0 / max(consts.numX, consts.numY);
    const float _h = 1.0 / 64;
    float value = -0.5 * _h * (
        texture(uvwt_in, cell_r).x -
        texture(uvwt_in, cell_l).x + 
        texture(uvwt_in, cell_d).y - 
        texture(uvwt_in, cell_u).y +
        texture(uvwt_in, cell_b).z - 
        texture(uvwt_in, cell_f).z);

    value = skip ? 0 : value;
    imageStore(div, cell, vec4(value));
    imageStore(p, cell, vec4(0.0));
}