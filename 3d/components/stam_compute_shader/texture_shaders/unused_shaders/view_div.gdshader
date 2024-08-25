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

uniform float color_scale;
uniform sampler2D div_texture: filter_nearest;

void fragment() {
    float div = texture(div_texture, UV).r; 
    div = min(div / color_scale, 1.);

    float r = 0.;
    float g = 0.;
    float b = 0.;

    if (div < 0.0) {
        r = 0.0; g = -div; b = -div;
    } else {
        r = div; g = div; b = 0.0;  //  positive divergence
    }
    COLOR = vec4(r, g, b, 1.0);
}

