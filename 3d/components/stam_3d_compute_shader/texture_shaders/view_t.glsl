#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

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
vec4 get_fire_color(float val) {
    val = clamp(val, 0.0, 1.0);
    float r, g, b, a;
	a = 1.;
    if (val < 0.3) {
        float _s = val / 0.3;
        r = 0.2 * _s;
        g = 0.2 * _s;
        b = 0.2 * _s;
        a = 0.75 * _s;
    } else if (val < 0.5) {
        float _s = (val - 0.3) / 0.2;
        r = 0.2 + 0.8 * _s;
        g = 0.1;
        b = 0.1;
        a = .75;
    } else {
        float _s = (val - 0.5) / 0.48;
        r = 1.0;
        g = _s;
        b = 0.0;
    }
    return vec4(r, g, b, a);
}

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    cell.z = int(consts.viewZ / 2);
    vec3 texelSize = 1.0 / vec3(consts.viewX, consts.viewY, consts.viewZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;

    float temp = texture(uvwt_in, UVW).a; 
    vec4 color = get_fire_color(temp);

    imageStore(output_image, cell.xy, color);
}
