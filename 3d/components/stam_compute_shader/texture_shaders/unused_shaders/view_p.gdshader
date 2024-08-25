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
uniform sampler2D p_texture: filter_nearest;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void fragment() {
    float p = texture(p_texture, UV).r; 
	p = min(p / color_scale, 1.);

    // Calculate magnitude and direction
    float magnitude = sqrt(p * p + p * p);
    float direction = atan(p, p);  // Range from -PI to PI

    // Normalize direction to [0, 1] range for hue
    float hue = (direction + PI) / (2.0 * PI);
    float saturation = 1.0;
    float value = magnitude;  // Assuming magnitude is already normalized, otherwise, you may need to normalize it

    // Convert HSV to RGB
    vec3 rgb = hsv2rgb(vec3(hue, saturation, value));
    COLOR = vec4(rgb, 1.0);
}

