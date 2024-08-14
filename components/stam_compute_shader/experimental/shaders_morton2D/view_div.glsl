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

layout(set = 0, binding = 5, std430) readonly buffer DivBuffer {
    float div[];
} div_buffer;

layout(set=0,binding=20,rgba32f) writeonly uniform image2D output_image;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float color_scale;
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
    vec2 viewCoord=gl_GlobalInvocationID.xy;
    ivec2 iviewCoord=ivec2(viewCoord.xy);
    ivec2 iinputCoord = ivec2((viewCoord / vec2(consts.viewX, consts.viewY)) * vec2(consts.numX, consts.numY) );
    uint idx = iinputCoord.x;
    uint idy = iinputCoord.y;
    uint N = consts.numX -1;

    if (idx > N || idy > N) return;

    uint cell = morton2D(idx, idy);
    float div = div_buffer.div[cell];
    div = min(div / pc.color_scale, 1.);

    float r = 0.;
    float g = 0.;
    float b = 0.;

    if (div < 0.0) {
        r = 0.0; g = -div; b = -div;
    } else {
        r = div; g = div; b = 0.0;  //  positive divergence
    }
    vec4 color = vec4(r, g, b, 1.0);
    imageStore(output_image, iviewCoord, color);
}