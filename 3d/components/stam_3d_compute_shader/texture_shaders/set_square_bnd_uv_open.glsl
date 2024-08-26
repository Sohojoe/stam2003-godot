#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 1) in;

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


layout(set = 0, binding = 1, rgba16f) uniform image2D uvwt;

void main() {
    uint i = gl_GlobalInvocationID.x;

    uint numY = consts.numY;
    uint numX = consts.numX;
    uint num_cells_y = numY - 1;
    uint num_cells_x = numX - 1;

    // left
    vec4 val = imageLoad(uvwt, ivec2(1, i));
    val.r = val.r < 0 ? val.r : 0;
    // var.b = 0.0; // set boundary state to 0
    imageStore(uvwt, ivec2(0, i), val);
    // right
    val = imageLoad(uvwt, ivec2(num_cells_x - 1, i));
    val.r = val.r > 0 ? val.r : 0;
    // var.b = 0.0; // set boundary state to 0
    imageStore(uvwt, ivec2(num_cells_x, i), val);
    // top
    val = imageLoad(uvwt, ivec2(i, 1));
    val.g = val.g < 0 ? val.g : 0;
    // var.b = 0.0; // set boundary state to 0
    imageStore(uvwt, ivec2(i, 0), val);
    // bottom
    val = imageLoad(uvwt, ivec2(i, num_cells_y - 1));
    val.g = val.g > 0 ? val.g : 0;
    // var.b = 0.0; // set boundary state to 0
    imageStore(uvwt, ivec2(i, num_cells_y), val);
    // corners
    // u_val = imageLoad(u, ivec2(1, 1)).r;
    // v_val = imageLoad(v, ivec2(1, 1)).r;
    // imageStore(u, ivec2(0, 0), vec4(u_val));
    // imageStore(v, ivec2(0, 0), vec4(v_val));
    // u_val = imageLoad(u, ivec2(num_cells_x - 2, 2)).r;
    // v_val = imageLoad(v, ivec2(num_cells_x - 2, 2)).r;
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