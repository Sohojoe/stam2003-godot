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


layout(set = 0, binding = 1) uniform sampler3D div;
layout(set = 0, binding = 2,rgba32f) writeonly uniform image2D output_image;


// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float color_scale;
} pc;

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(consts.viewX, consts.viewY, consts.viewZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;
    vec3 input_texelSize = 1.0 / vec3(consts.numX, consts.numY, consts.numZ);
    UVW.z = (consts.numZ - 1 + 0.5) * input_texelSize.z;

    float r = 0.;
    float g = 0.;
    float b = 0.;
    vec4 finalColor = vec4(0., 0., 0., 1.);

    for (int z = 0; z < int(consts.numZ) - 1; z++) {
        float div = texture(div, UVW).r; 
        div = min(div / pc.color_scale, 1.);

        if (div < 0.0) {
            r = 0.0; g = -div; b = -div;
        } else {
            r = div; g = 0.0; b = 0.0;  //  positive divergence
        }
        finalColor.rgb += vec3(r, g, b);
        UVW.z -= input_texelSize.z;
    }
    finalColor = clamp(finalColor, 0.0, 1.0);
    imageStore(output_image, cell.xy, finalColor);
}