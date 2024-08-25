#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 1) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    uint viewX;
    uint viewY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 4, r16f) uniform image2D p;

// --- End Shared Buffer Definition


void main() {
    uint i = gl_GlobalInvocationID.x;

    uint numY = consts.numY;
    uint numX = consts.numX;
    uint num_cells_y = numY - 1;
    uint num_cells_x = numX - 1;

    // top
    float value = imageLoad(p, ivec2(i, 1)).r;
    imageStore(p, ivec2(i, 0), vec4(value));
    //  bottom
    value = imageLoad(p, ivec2(i, num_cells_y - 1)).r;
    imageStore(p, ivec2(i, num_cells_y), vec4(value));
    // left
    value = imageLoad(p, ivec2(1, i)).r;
    imageStore(p, ivec2(0, i), vec4(value));
    // right
    value = imageLoad(p, ivec2(num_cells_x - 1, i)).r;
    imageStore(p, ivec2(num_cells_x, i), vec4(value));

    // corners
    value = imageLoad(p, ivec2(1, 1)).r;
    imageStore(p, ivec2(0, 0), vec4(value));
    value = imageLoad(p, ivec2(num_cells_x - 1, 1)).r;
    imageStore(p, ivec2(num_cells_x, 0), vec4(value));
    value = imageLoad(p, ivec2(1, num_cells_y - 1)).r;
    imageStore(p, ivec2(0, num_cells_y), vec4(value));
    value = imageLoad(p, ivec2(num_cells_x - 1, num_cells_y - 1)).r;
    imageStore(p, ivec2(num_cells_x, num_cells_y), vec4(value));
}