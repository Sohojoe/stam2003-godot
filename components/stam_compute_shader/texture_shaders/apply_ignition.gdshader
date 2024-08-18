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

uniform sampler2D i_buffer: filter_nearest;

void fragment() {
    float i = texture(i_buffer, UV).r; 
    if (i == 1.0) {
        COLOR = vec4(1.0);
    } else {
        COLOR = vec4(0.0);
    }
}