#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

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



layout(set = 0, binding = 1) uniform sampler3D read_texture;
layout(set = 0, binding = 2, rgba16f) uniform writeonly image3D write_texture;

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

const vec3 up = vec3(0.0, -1.0, 0.0);
const vec3 down = vec3(0.0, 1.0, 0.0);
const vec3 left = vec3(-1.0, 0.0, 0.0);
const vec3 right = vec3(1.0, 0.0, 0.0);
const vec3 backwards = vec3(0.0, 0.0, -1.0);
const vec3 forwards = vec3(0.0, 0.0, 1.0);

void main() {
    uint numX = consts.numX;
    uint numY = consts.numY;
    uint numZ = consts.numZ;
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(numX, numY, numZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;
    // float a = pc.dt * 64 * 64 * pc.diff;
    vec4 a = pc.dt * 64 * 64 * pc.diff;

    vec4 centerValue = texture(read_texture, UVW);
    vec4 leftValue = texture(read_texture, UVW + left * texelSize);
    vec4 rightValue = texture(read_texture, UVW + right * texelSize);
    vec4 upValue = texture(read_texture, UVW + up * texelSize);
    vec4 downValue = texture(read_texture, UVW + down * texelSize);
    vec4 backwardsValue = texture(read_texture, UVW + backwards * texelSize);
    vec4 forwardsValue = texture(read_texture, UVW + forwards * texelSize);

    bool skip = centerValue.b == 1.0;

    vec4 value = skip ? centerValue : (
        centerValue + a * (
            leftValue + rightValue + 
            upValue + downValue +
            backwardsValue + forwardsValue
            )) / (1 + 6 * a);
    imageStore(write_texture, cell, value);
}