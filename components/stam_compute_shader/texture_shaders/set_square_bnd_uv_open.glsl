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

layout(set = 0, binding = 1, r16f) uniform image2D u;
layout(set = 0, binding = 2, r16f) uniform image2D v;

void main() {
    uint i = gl_GlobalInvocationID.x;

    uint numY = consts.numY;
    uint numX = consts.numX;
    uint num_cells_y = numY - 1;
    uint num_cells_x = numX - 1;

    // left
    float u_val = imageLoad(u, ivec2(1, i)).r;
    u_val = u_val < 0 ? u_val : 0;
    float v_val = imageLoad(v, ivec2(1, i)).r;
    imageStore(u, ivec2(0, i), vec4(u_val));
    imageStore(v, ivec2(0, i), vec4(v_val));
    // right
    u_val = imageLoad(u, ivec2(num_cells_x - 1, i)).r;
    u_val = u_val > 0 ? u_val : 0;
    v_val = imageLoad(v, ivec2(num_cells_x - 1, i)).r;
    imageStore(u, ivec2(num_cells_x, i), vec4(u_val));
    imageStore(v, ivec2(num_cells_x, i), vec4(v_val));
    // top
    u_val = imageLoad(u, ivec2(i, 1)).r;
    v_val = imageLoad(v, ivec2(i, 1)).r;
    v_val = v_val < 0 ? v_val : 0;
    imageStore(u, ivec2(i, 0), vec4(u_val));
    imageStore(v, ivec2(i, 0), vec4(v_val));
    // bottom
    u_val = imageLoad(u, ivec2(i, num_cells_y - 1)).r;
    v_val = imageLoad(v, ivec2(i, num_cells_y - 1)).r;
    v_val = v_val > 0 ? v_val : 0;
    imageStore(u, ivec2(i, num_cells_y), vec4(u_val));
    imageStore(v, ivec2(i, num_cells_y), vec4(v_val));
    // corners
    // u_val = imageLoad(u, ivec2(1, 1)).r;
    // v_val = imageLoad(v, ivec2(1, 1)).r;
    // imageStore(u, ivec2(0, 0), vec4(u_val));
    // imageStore(v, ivec2(0, 0), vec4(v_val));
    // u_val = imageLoad(u, ivec2(num_cells_x - 1, 1)).r;
    // v_val = imageLoad(v, ivec2(num_cells_x - 1, 1)).r;
    // imageStore(u, ivec2(num_cells_x, 0), vec4(u_val));
    // imageStore(v, ivec2(num_cells_x, 0), vec4(v_val));
    // u_val = imageLoad(u, ivec2(1, num_cells_y - 1)).r;
    // v_val = imageLoad(v, ivec2(1, num_cells_y - 1)).r;
    // imageStore(u, ivec2(0, num_cells_y), vec4(u_val));
    // imageStore(v, ivec2(0, num_cells_y), vec4(v_val));
    // u_val = imageLoad(u, ivec2(num_cells_x - 1, num_cells_y - 1)).r;
    // v_val = imageLoad(v, ivec2(num_cells_x - 1, num_cells_y - 1)).r;
    // imageStore(u, ivec2(num_cells_x, num_cells_y), vec4(u_val));
    // imageStore(v, ivec2(num_cells_x, num_cells_y), vec4(v_val));
}