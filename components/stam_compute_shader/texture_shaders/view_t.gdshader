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

uniform sampler2D uvst_in: filter_nearest;


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
    float temp = texture(uvst_in, UV).a; 
    COLOR = get_fire_color(temp);
}

