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

layout(set = 0, binding = 1, r16f) uniform image2D u;
layout(set = 0, binding = 2, r16f) uniform image2D v;

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

    float u_val = 0.0;
    float v_val = 0.0;

    if (is_left_boundary) {
        float u_val_r = imageLoad(u, cell_r).r;
        if (u_val_r < 0) {
            u_val =  u_val_r;
        } else {
            u_val =  0;
        }
        v_val = imageLoad(v, cell_r).r;
    } else if (is_right_boundary) {
        float u_val_l = imageLoad(u, cell_l).r;
        if (u_val_l > 0) {
    		u_val = u_val_l;
        } else {
            u_val =  0;
        }
		v_val = imageLoad(v, cell_l).r;
    }
    if (is_top_boundary) {
        u_val = imageLoad(u, cell_d).r;
        v_val = imageLoad(v, cell_d).r;
    } else if (is_bottom_boundary) {
        u_val = imageLoad(u, cell_u).r;
        v_val = imageLoad(v, cell_u).r;
    }

    // Handle corners    
    if (is_left_boundary && is_top_boundary) {
        u_val = imageLoad(u, ivec2(idx + 1, idy + 1)).r;
        v_val = imageLoad(v, ivec2(idx + 1, idy + 1)).r;
    } else if (is_left_boundary && is_bottom_boundary) {
        u_val = imageLoad(u, ivec2(idx + 1, idy - 1)).r;
        v_val = imageLoad(v, ivec2(idx + 1, idy - 1)).r;
    } else if (is_right_boundary && is_top_boundary) {
        u_val = imageLoad(u, ivec2(idx - 1, idy + 1)).r;
        v_val = imageLoad(v, ivec2(idx - 1, idy + 1)).r;
    } else if (is_right_boundary && is_bottom_boundary) {
        u_val = imageLoad(u, ivec2(idx - 1, idy - 1)).r;
        v_val = imageLoad(v, ivec2(idx - 1, idy - 1)).r;
    }

    imageStore(u, cell, vec4(u_val));
    imageStore(v, cell, vec4(v_val));
}