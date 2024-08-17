shader_type canvas_item;

global uniform float dt;
global uniform vec2 grid_size;
global uniform float h;
global uniform float h2;
global uniform uint numX;
global uniform uint numY;
global uniform uint viewX;
global uniform uint viewY;
global uniform vec2 view_ratio;
global uniform vec2 view_size;

uniform float[4096] t;
uniform sampler2D i_texture;


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

void fragment() {
    vec2 viewCoord=UV * view_size;
    uvec2 iviewCoord=uvec2(viewCoord.xy);
    uvec2 iinputCoord = uvec2(viewCoord * view_ratio);

    float temp = texture(i_texture, UV).r; 
    COLOR = get_fire_color(temp);

    uint idx = iinputCoord.x;
    uint idy = iinputCoord.y;
    uint N = numX -uint(1);

    if (idx >= N || idy >= N || idx < uint(1) || idy < uint(1))
    {
        COLOR = vec4(0.0);
    }
    else
    {
        uint cell = idy * numX + idx;
        float temp = t[cell];
        COLOR = get_fire_color(temp);
    }
}

