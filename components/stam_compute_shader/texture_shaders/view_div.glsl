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

layout(set = 0, binding = 5) uniform sampler2D div;
layout(set=0,binding=20,rgba32f) writeonly uniform image2D output_image;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float color_scale;
} pc;

void main() {
    vec2 viewCoord=gl_GlobalInvocationID.xy;
    ivec2 iviewCoord=ivec2(viewCoord.xy);
    ivec2 iinputCoord = ivec2((viewCoord / vec2(consts.viewX, consts.viewY)) * vec2(consts.numX, consts.numY) );
    uint idx = iinputCoord.x;
    uint idy = iinputCoord.y;
    uint N = consts.numX -1;

    if (idx > N || idy > N) return;

    vec2 UV = viewCoord.xy / vec2(consts.viewX, consts.viewY);
    float div = texture(div, UV).r; 
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