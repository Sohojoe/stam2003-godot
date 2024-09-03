#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0, rgba16f) uniform writeonly image2D write_texture;
// --- End Shared Buffer Definition

void main() {
    imageStore(write_texture, ivec2(gl_GlobalInvocationID.xy), vec4(0));
}