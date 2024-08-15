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

layout(set = 0, binding = 1, std430) buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) buffer VBuffer {
    float v[];
} v_buffer;

// layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
//     float s[];
// } s_buffer;

// layout(set = 0, binding = 4, std430) buffer PBuffer {
//     float p[];
// } p_buffer;

// layout(set = 0, binding = 5, std430) buffer DivBuffer {
//     float div[];
// } div_buffer;
// --- End Shared Buffer Definition

// layout(push_constant, std430) uniform Params {
//     int b;
//     int which_buffer; // 0 for h, 1 for v, 2 for p, 3 for div
// } pc;

uint morton2D(uint x, uint y) {
    x = (x | (x << 8)) & 0x00FF00FF;
    x = (x | (x << 4)) & 0x0F0F0F0F;
    x = (x | (x << 2)) & 0x33333333;
    x = (x | (x << 1)) & 0x55555555;

    y = (y | (y << 8)) & 0x00FF00FF;
    y = (y | (y << 4)) & 0x0F0F0F0F;
    y = (y | (y << 2)) & 0x33333333;
    y = (y | (y << 1)) & 0x55555555;

    return x | (y << 1);
}

void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;

    // early return if we are on not the boundary
    if (idx != 0 && idx != consts.numX - 1 && idy != 0 && idy != consts.numY - 1) {
        return;
    }

    uint cell = morton2D(idx, idy);

    uint numY = consts.numY;
    uint numX = consts.numX;
    uint num_cells_y = numY - 1;
    uint num_cells_x = numX - 1;

    bool is_left_boundary = (idx == 0);
    bool is_right_boundary = (idx == num_cells_x);
    bool is_top_boundary = (idy == 0);
    bool is_bottom_boundary = (idy == num_cells_y);

    uint cell_l	= morton2D(idx-1, idy);
    uint cell_r	= morton2D(idx+1, idy);
    uint cell_u	= morton2D(idx, idy-1);
    uint cell_d	= morton2D(idx, idy+1);    

    if (is_left_boundary) {
        if (u_buffer.u[cell_r] < 0) {
            u_buffer.u[cell] = u_buffer.u[cell_r];
        } else {
            u_buffer.u[cell] = 0;
        }
        v_buffer.v[cell] = v_buffer.v[cell_r];
    } else if (is_right_boundary) {
        if (u_buffer.u[cell_l] > 0) {
    		u_buffer.u[cell] = u_buffer.u[cell_l];
        } else {
            u_buffer.u[cell] = 0;
        }
		v_buffer.v[cell] = v_buffer.v[cell_l];
    }
    if (is_top_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_d];
        v_buffer.v[cell] = v_buffer.v[cell_d];
    } else if (is_bottom_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_u];
        v_buffer.v[cell] = v_buffer.v[cell_u];
    }

    // Handle corners    
    uint cell_dr = morton2D(idx+1, idy+1);
    uint cell_ur = morton2D(idx+1, idy-1);
    uint cell_dl = morton2D(idx-1, idy+1);
    uint cell_ul = morton2D(idx-1, idy-1);
    if (is_left_boundary && is_top_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_dr]; 
        v_buffer.v[cell] = v_buffer.v[cell_dr]; 
    } else if (is_left_boundary && is_bottom_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_ur]; 
        v_buffer.v[cell] = v_buffer.v[cell_ur]; 
    } else if (is_right_boundary && is_top_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_dl]; 
        v_buffer.v[cell] = v_buffer.v[cell_dl]; 
    } else if (is_right_boundary && is_bottom_boundary) {
        u_buffer.u[cell] = u_buffer.u[cell_ul];
        v_buffer.v[cell] = v_buffer.v[cell_ul];
    }
}