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
layout(set = 0, binding = 2, rgba16f) uniform writeonly image2D write_texture;

// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    vec4 diff;
    float dt;
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

const vec2 up = vec2(0.0, -1.0);
const vec2 down = vec2(0.0, 1.0);
const vec2 left = vec2(-1.0, 0.0);
const vec2 right = vec2(1.0, 0.0);

void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / vec2(numX, numY);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;
    // float a = pc.dt * 64 * 64 * pc.diff;
    vec4 a = pc.dt * 64 * 64 * pc.diff;

    vec4 centerValue = texture(read_texture, UV);
    vec4 leftValue = texture(read_texture, UV + left * texelSize);
    vec4 rightValue = texture(read_texture, UV + right * texelSize);
    vec4 upValue = texture(read_texture, UV + up * texelSize);
    vec4 downValue = texture(read_texture, UV + down * texelSize);

    bool skip = centerValue.b == 0.0;

    vec4 value = skip ? centerValue : (centerValue + a * (leftValue + rightValue + upValue + downValue)) / (1 + 4 * a);
    value.b = centerValue.b;
    imageStore(write_texture, cell, value);
}