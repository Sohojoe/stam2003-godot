#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    uint viewX;
    uint viewY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 1) uniform sampler2D fine_grid; // Fine grid with linear filtering
layout(set = 0, binding = 2, r16f) uniform image2D coarse_grid; // Coarse grid output


void main() {
    ivec2 coarse_cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 coarse_texel_size = 1.0 / imageSize(coarse_grid);
    vec2 UV = (vec2(coarse_cell) + 0.5) * coarse_texel_size;

    // Sample the fine grid using linear filtering
    float restricted_value = texture(fine_grid, UV).r;

    // Store the result in the coarse grid
    imageStore(coarse_grid, coarse_cell, vec4(restricted_value));
}