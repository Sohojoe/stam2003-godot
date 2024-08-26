#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

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


layout(set = 0, binding = 1) uniform sampler2D div;
layout(set = 0, binding = 2,rgba32f) writeonly uniform image2D output_image;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float color_scale;
} pc;

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / vec2(consts.viewX, consts.viewY);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

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
    imageStore(output_image, cell, color);
}