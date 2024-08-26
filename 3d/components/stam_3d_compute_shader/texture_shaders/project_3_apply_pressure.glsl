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

layout(set = 0, binding = 1) uniform sampler3D p;
layout(set = 0, binding = 2) uniform sampler3D uvwt_in;
layout(set = 0, binding = 3, rgba16f) uniform image3D uvwt_out;
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

    // if (texelFetch(s, cell, 0).r == 0.0 || idx == 0 || idx >= consts.numX - 1 || idy == 0 || idy >= consts.numY - 1) {
    //     return;
    // }
    vec4 uvwt = texelFetch(uvwt_in, cell, 0);
    bool skip = uvwt.z == 1.0;

    vec3 cell_l = UVW + left * texelSize;
    vec3 cell_r = UVW + right * texelSize;
    vec3 cell_u = UVW + up * texelSize;
    vec3 cell_d = UVW + down * texelSize;
    vec3 cell_b = UVW + backwards * texelSize;
    vec3 cell_f = UVW + forwards * texelSize;

    // float _h = 1.0 / max(consts.numX, consts.numY);
    float _h = 1.0 / 64;

    uvwt.x -= 0.5 * (texture(p, cell_r).r - texture(p, cell_l).r) / _h;
    uvwt.y -= 0.5 * (texture(p, cell_d).r - texture(p, cell_u).r) / _h;
    uvwt.z -= 0.5 * (texture(p, cell_b).r - texture(p, cell_f).r) / _h;
    
    uvwt.x = skip ? 0 : uvwt.x;
    uvwt.y = skip ? 0 : uvwt.y;
    uvwt.z = skip ? 0 : uvwt.z;

    imageStore(uvwt_out, cell, uvwt);
}