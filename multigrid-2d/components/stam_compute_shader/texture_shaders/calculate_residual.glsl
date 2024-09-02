#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0, std430) readonly buffer ConstBuffer {
    uint numX;
    uint numY;
    uint viewX;
    uint viewY;
    float h;
    float h2;
} consts;

layout(set = 0, binding = 1) uniform sampler2D s;
layout(set = 0, binding = 2) uniform sampler2D p; // Current pressure field
layout(set = 0, binding = 3) uniform sampler2D div; // Divergence (b)
layout(set = 0, binding = 4, r16f) uniform image2D residual; // Residual output

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

    float div_value = texelFetch(div, cell, 0).r;
    float p_c = texture(p, UV).r;
    float p_l = texture(p, UV + left * texelSize).r;
    float p_r = texture(p, UV + right * texelSize).r;
    float p_u = texture(p, UV + up * texelSize).r;
    float p_d = texture(p, UV + down * texelSize).r;

    // Calculate Laplacian of pressure (Ax)
    float laplacian = (p_l + p_r + p_u + p_d - 4.0 * p_c) / (consts.h * consts.h);

    // Calculate residual (r = b - Ax)
    float residual_value = div_value - laplacian;

    // Store residual
    imageStore(residual, cell, vec4(residual_value));
}