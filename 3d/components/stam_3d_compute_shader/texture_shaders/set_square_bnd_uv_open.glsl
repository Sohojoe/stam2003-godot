#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

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


layout(set = 0, binding = 1, rgba16f) uniform image3D uvwt;

void main() {
    uvec3 id = gl_GlobalInvocationID;
    uint face = id.z;
    uint x = id.x;
    uint y = id.y;

    int numX = int(consts.numX);
    int numY = int(consts.numY);
    int numZ = int(consts.numZ);
    int num_cells_x = numX - 1;
    int num_cells_y = numY - 1;
    int num_cells_z = numZ - 1;

    if (x >= numX || y >= numY) return;

    vec4 val;
    ivec3 readPos, writePos;
    uint component = face / 2; // 0 for x, 1 for y, 2 for z
    bool isPositiveFace = (face % 2) == 1;

    // Set read and write positions
    readPos = ivec3(x, y, 0);
    writePos = readPos;
    readPos[component] = isPositiveFace ? num_cells_x - 1 : 1;
    writePos[component] = isPositiveFace ? num_cells_x : 0;

    // Read, modify, and write
    val = imageLoad(uvwt, readPos);
    val[component] = isPositiveFace ? (val[component] > 0 ? val[component] : 0)
                                    : (val[component] < 0 ? val[component] : 0);
    imageStore(uvwt, writePos, val);
}