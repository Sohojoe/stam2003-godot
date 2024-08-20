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


layout(set = 0, binding = 1) uniform sampler2D read_texture;
layout(set = 0, binding = 2) uniform writeonly image2D write_texture;
layout(set = 0, binding = 3) uniform sampler2D s;

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
//    x[IX(i,j-1)]+x[IX(i,j+1)]))/(1+4*a);
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
    ivec2 cell = ivec2(idx, idy);

    if (texelFetch(s, cell, 0).r == 0.0 || idx == 0 || idx >= numX - 1 || idy == 0 || idy >= numY - 1) {
        return;
    }    
    ivec2 cell_l = ivec2(idx-1, idy);
    ivec2 cell_r = ivec2(idx+1, idy);
    ivec2 cell_u = ivec2(idx, idy-1);
    ivec2 cell_d = ivec2(idx, idy+1);

    float value = (texelFetch(read_texture, cell, 0).r + a * (
        texelFetch(read_texture, cell_l, 0).r + 
        texelFetch(read_texture, cell_r, 0).r + 
        texelFetch(read_texture, cell_u, 0).r + 
        texelFetch(read_texture, cell_d, 0).r
        )) / (1 + 4 * a);

    imageStore(write_texture, cell, vec4(value));
}