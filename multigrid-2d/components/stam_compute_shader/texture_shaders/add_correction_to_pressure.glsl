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

layout(set = 0, binding = 1) uniform sampler2D pressure;
layout(set = 0, binding = 2) uniform sampler2D correction;
layout(set = 0, binding = 3, r32f) uniform image2D updated_pressure;
// --- End Shared Buffer Definition

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 texelSize = 1.0 / imageSize(updated_pressure);
    vec2 UV = (vec2(cell) + 0.5) * texelSize;

    // Read the current pressure and correction values
    float p = texture(pressure, UV).r;
    float c = texture(correction, UV).r;

    // Add the correction to the pressure
    float new_p = p + c;

    // Store the updated pressure
    imageStore(updated_pressure, cell, vec4(new_p, 0.0, 0.0, 0.0));
}
