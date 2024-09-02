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
    vec2 texelSize = 1.0 / vec2(consts.viewX, consts.viewY);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

    float p = texture(residual, UV).r; 
	p = min(p / pc.color_scale, 1.);

    // Calculate magnitude and direction
    float magnitude = sqrt(p * p + p * p);
    float direction = atan(p, p);  // Range from -PI to PI

    // Normalize direction to [0, 1] range for hue
    float hue = (direction + PI) / (2.0 * PI);
    float saturation = 1.0;
    float value = magnitude;  // Assuming magnitude is already normalized, otherwise, you may need to normalize it

    // Convert HSV to RGB
    vec3 rgb = hsv2rgb(vec3(hue, saturation, value));
    vec4 color = vec4(rgb, 1.0);
    imageStore(output_image, cell, color);
}