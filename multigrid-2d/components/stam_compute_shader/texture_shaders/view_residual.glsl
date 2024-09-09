#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

// --- Begin Shared Buffer Definition
layout(set = 0, binding = 1) uniform sampler2D residual;
layout(set = 0, binding = 2,rgba32f) writeonly uniform image2D output_image;

// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float color_scale;
} pc;

const float PI = 3.14159265359;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / imageSize(output_image);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

    float value = texture(residual, UV).r; 
	value = clamp(value / pc.color_scale, -1., 1.);

    float r = 0.;
    float g = 0.;
    float b = 0.;

    if (value < 0.0) {
        r = -value; g = 0.0; b = 0.0;
    } else {
        r = 0.0; g = value; b = 0.0;  //  positive divergence
    }
    vec4 color = vec4(r, g, b, 1.0);
    imageStore(output_image, cell, color);
}