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
layout(set = 0, binding = 1, std430) readonly buffer ReadBuffer {
    float u[];
} read_buffer;

layout(set = 0, binding = 2, std430) buffer WriteBuffer {
    float u[];
} write_buffer;

layout(set = 0, binding = 3, std430) readonly buffer SBuffer {
    float s[];
} s_buffer;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
    float diff;
} pc;


// void diffuse ( int N, int b, float * x, float * x0, float diff, float dt )
// {
// int i, j, k;
//     float a=dt*diff*N*N;
// for ( k=0 ; k<20 ; k++ ) {
// for ( i=1 ; i<=N ; i++ ) {
// for ( j=1 ; j<=N ; j++ ) {
// x[IX(i,j)] = (x0[IX(i,j)] + a*(x[IX(i-1,j)]+x[IX(i+1,j)]+
// } }
//        set_bnd ( N, b, x );
//     }
// }

void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    // float a = pc.dt * pc.diff * numX * numX;
    float a = pc.dt * 64 * 64 * pc.diff;

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    uint cell = idy * consts.numX + idx;

    if (s_buffer.s[cell] == 0.0 || idx == 0 || idx >= numX - 1 || idy == 0 || idy >= numY - 1) {
        return;
    }    
    uint cell_l = cell - 1;
    uint cell_r = cell + 1;
    uint cell_u = cell - numX;
    uint cell_d = cell + numX;

    write_buffer.u[cell] = (read_buffer.u[cell] + a * (
        read_buffer.u[cell_l] + 
        read_buffer.u[cell_r] + 
        read_buffer.u[cell_u] + 
        read_buffer.u[cell_d]
        )) / (1 + 4 * a);
}