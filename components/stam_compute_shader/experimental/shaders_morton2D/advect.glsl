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

layout(set = 0, binding = 1, std430) readonly buffer UBuffer {
    float u[];
} u_buffer;

layout(set = 0, binding = 2, std430) readonly buffer VBuffer {
    float v[];
} v_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;

layout(set = 0, binding = 4, std430) buffer TBuffer {
    float v[];
} write_buffer;

layout(set = 0, binding = 5, std430) readonly buffer ROTBuffer {
    float v[];
} read_buffer;
// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
} pc;

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
    uint N = consts.numX -1;

    if (idx >= N || idy >= N) return;

    // float dt0 = pc.dt * N;
    float dt0 = pc.dt * 64; // was N but we want constant scale at different grid sizes
    uint i = idx;
    uint j = idy;
    uint cell = morton2D(idx, idy);

    float x = i - dt0 * u_buffer.u[cell];
    float y = j - dt0 * v_buffer.v[cell];

    if (x < 0.5) x = 0.5;
    if (x > N + 0.5) x = N + 0.5;
    int i0 = int(x);
    int i1 = i0 + 1;

    if (y < 0.5) y = 0.5;
    if (y > N + 0.5) y = N + 0.5;
    int j0 = int(y);
    int j1 = j0 + 1;

    float s1 = x - float(i0);
    float s0 = 1.0 - s1;
    float t1 = y - float(j0);
    float t0 = 1.0 - t1;

    // write_buffer.v[cell] = s0 * (t0 * read_buffer.v[j0 * consts.numX + i0] + t1 * read_buffer.v[j1 * consts.numX + i0]) +
    //                    s1 * (t0 * read_buffer.v[j0 * consts.numX + i1] + t1 * read_buffer.v[j1 * consts.numX + i1]);
    uint cell_1 = morton2D(i0, j0);
    uint cell_2 = morton2D(i0, j1);
    uint cell_3 = morton2D(i1, j0);
    uint cell_4 = morton2D(i1, j1);
    write_buffer.v[cell] = s0 * (t0 * read_buffer.v[cell_1] + t1 * read_buffer.v[cell_2]) +
                       s1 * (t0 * read_buffer.v[cell_3] + t1 * read_buffer.v[cell_4]);
}