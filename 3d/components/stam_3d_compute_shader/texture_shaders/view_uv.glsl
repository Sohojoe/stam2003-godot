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


layout(set = 0, binding = 1) uniform sampler3D uvwt_in;
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
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(consts.viewX, consts.viewY, consts.viewZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;
    vec3 input_texelSize = 1.0 / vec3(consts.numX, consts.numY, consts.numZ);
    UVW.z = (consts.numZ - 1 + 0.5) * input_texelSize.z;

    vec4 finalColor = vec4(0., 0., 0., 1.);

    for (int z = 0; z < int(consts.numZ) - 1; z++) {
        // float u_val = texture(uvwt_in, UVW).x; 
        // float v_val = texture(uvwt_in, UVW).y; 
        // u_val = min(u_val / pc.color_scale, 1.);
        // v_val = min(v_val / pc.color_scale, 1.);

        // // Calculate magnitude and direction
        // float magnitude = sqrt(u_val * u_val + v_val * v_val);
        // float direction = atan(v_val, u_val);  // Range from -PI to PI

        // // Normalize direction to [0, 1] range for hue
        // float hue = (direction + PI) / (2.0 * PI);
        // float saturation = 1.0;
        // float value = magnitude;  // Assuming magnitude is already normalized, otherwise, you may need to normalize it

        // // Convert HSV to RGB
        // finalColor.rgb += hsv2rgb(vec3(hue, saturation, value));
        vec3 uvw = texture(uvwt_in, UVW).xyz;
        uvw = min(uvw / pc.color_scale, 1.);
        // finalColor.rgb += hsv2rgb(vec3(uvw.x, 1., uvw.z));
        finalColor.rgb += uvw;
    }
    finalColor = clamp(finalColor, -1.0, 1.0);
    finalColor.rgb += 1.;
    finalColor.rgb *= 0.5;
    imageStore(output_image, cell.xy, finalColor);
}