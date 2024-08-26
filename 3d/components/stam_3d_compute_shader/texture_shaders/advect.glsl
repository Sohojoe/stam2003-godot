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

layout(set = 0, binding = 1) uniform sampler3D read_texture;
layout(set = 0, binding = 2, rgba16f) uniform writeonly image3D write_texture;
// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
} pc;


void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    uint numZ = consts.numZ;
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(numX, numY, numZ);
    // vec2 UV = (vec2(cell) + 0.5) * texelSize;

    // uint N = consts.numX -1;
    // float dt0 = pc.dt * N;
    float dt0 = pc.dt * 64; // was N but we want constant scale at different grid sizes

    vec4 cell_value = texelFetch(read_texture, cell, 0);
    vec3 xyz = vec3(cell) - dt0 * cell_value.xyz;

    vec4 value = texture(read_texture, (xyz + 0.5) * texelSize);

    imageStore(write_texture, cell, value);

}