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

layout(set = 0, binding = 1) uniform sampler2D coarse_correction;
layout(set = 0, binding = 2, r16f) uniform image2D fine_correction;
// --- End Shared Buffer Definition

void main() {
    ivec2 fine_cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 fine_texel_size = 1.0 / imageSize(fine_correction);
    vec2 UV = (vec2(fine_cell) + 0.5) * fine_texel_size;
    
    // Sample the coarse correction
    float coarse_value = texture(coarse_correction, UV).r;
    
    // Prolongate (interpolate) the correction to the fine grid
    imageStore(fine_correction, fine_cell, vec4(coarse_value));
}