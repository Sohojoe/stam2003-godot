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

layout(set = 0, binding = 8) uniform sampler2D t;
layout(set=0,binding=20,rgba32f) writeonly uniform image2D output_image;


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
    vec2 viewCoord = gl_GlobalInvocationID.xy;
    ivec2 iviewCoord = ivec2(viewCoord.xy);
    ivec2 iinputCoord = ivec2((viewCoord / vec2(consts.viewX, consts.viewY)) * vec2(consts.numX, consts.numY) );
    uint idx = iinputCoord.x;
    uint idy = iinputCoord.y;
    uint N = consts.numX -1;

    if (idx >= N || idy >= N || idx < uint(1) || idy < uint(1))
    {
        imageStore(output_image, iviewCoord, vec4(0.0));
        return;
    }

    vec2 UV = viewCoord.xy / vec2(consts.viewX, consts.viewY);

    float temp = texture(t, UV).r; 
    vec4 color = get_fire_color(temp);
    imageStore(output_image, iviewCoord, color);
}
