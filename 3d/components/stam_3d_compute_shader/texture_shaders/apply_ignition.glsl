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
layout(set = 0, binding = 2, rgba16f) uniform image3D uvwt_out;
layout(set = 0, binding = 3) uniform sampler3D i;

// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
// } pc;

void main() {
    // uint idx = gl_GlobalInvocationID.x;
    // uint idy = gl_GlobalInvocationID.y;
    // uint N = consts.numX -1;

    // if (idx >= N || idy >= N) return;
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(consts.numX, consts.numY, consts.numZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;

    if (texelFetch(i, cell, 0).r == 1.0) {
        vec4 uvwt = texture(uvwt_in, UVW);
        // uvwt.a = 1.0;
        uvwt = vec4(0.0, 0.0, 0.0, 1.0);
        imageStore(uvwt_out, cell, uvwt);
    }
}