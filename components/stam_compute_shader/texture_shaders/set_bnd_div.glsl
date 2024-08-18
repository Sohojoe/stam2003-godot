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

layout(set = 0, binding = 5, r32f) uniform image2D div;
// --- End Shared Buffer Definition

void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;

    // early return if we are on not the boundary
    if (idx != 0 && idx != consts.numX - 1 && idy != 0 && idy != consts.numY - 1) {
        return;
    }

    ivec2 cell = ivec2(idx, idy);

    uint numY = consts.numY;
    uint numX = consts.numX;
    uint num_cells_y = numY - 1;
    uint num_cells_x = numX - 1;

    bool is_left_boundary = (idx == 0);
    bool is_right_boundary = (idx == num_cells_x);
    bool is_top_boundary = (idy == 0);
    bool is_bottom_boundary = (idy == num_cells_y);

    ivec2 cell_l = ivec2(idx-1, idy);
    ivec2 cell_r = ivec2(idx+1, idy);
    ivec2 cell_u = ivec2(idx, idy-1);
    ivec2 cell_d = ivec2(idx, idy+1);

    float value = 0.0;

    if (is_left_boundary) {
        value = imageLoad(div, cell_r).r;
    } else if (is_right_boundary) {
		value = imageLoad(div, cell_l).r;
    }
    if (is_top_boundary) {
        value = imageLoad(div, cell_d).r;
    } else if (is_bottom_boundary) {
        value = imageLoad(div, cell_u).r;
    }

    // Handle corners
    if (is_left_boundary && is_top_boundary) {
        value = imageLoad(div, ivec2(idx + 1, idy + 1)).r;
    } else if (is_left_boundary && is_bottom_boundary) {
        value = imageLoad(div, ivec2(idx + 1, idy - 1)).r;
    } else if (is_right_boundary && is_top_boundary) {
        value = imageLoad(div, ivec2(idx - 1, idy + 1)).r;
    } else if (is_right_boundary && is_bottom_boundary) {
        value = imageLoad(div, ivec2(idx - 1, idy - 1)).r;
    }

    imageStore(div, cell, vec4(value));
}