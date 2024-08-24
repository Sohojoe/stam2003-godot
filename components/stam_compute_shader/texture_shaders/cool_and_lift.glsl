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

layout(set = 0, binding = 1) uniform sampler2D uvst_in;
layout(set = 0, binding = 2, rgba16f) uniform image2D uvst_out;

// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
    float add_perturbance_probability;
    float seed;
    // float wind_x;
    // float wind_y;
} pc;


float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233)) + pc.seed) * 43758.5453);
}

void main() {

    uint idx = gl_GlobalInvocationID.x;
    uint idy = gl_GlobalInvocationID.y;
    // uint N = consts.numX -1;

    // if (idx >= N || idy >= N) return;

    float dt = pc.dt;
	float fire_cooling = 1.2 * dt;
	float smoke_cooling = 0.3 * dt;
	// const float lift = (3.0 *60.) * dt;
	const float lift = 3.0;
	float acceleration = 6.0 * dt;
	float normed_1 = 1 * (60.0 * dt);
	const float perb_step = 3;


    ivec2 cell = ivec2(idx, idy);

    vec4 uvst = texelFetch(uvst_in, cell, 0);
    float u_val = uvst.x;
    float v_val = uvst.y;
    float s_val = uvst.z;
    float t_val = uvst.w;

    float cooling = (t_val < 0.3) ? smoke_cooling : fire_cooling;
    t_val = max(t_val - cooling, 0.0);

    float target_v = t_val * lift;
    v_val += (target_v - v_val) * acceleration;

    if (t_val > 0.9 && pc.add_perturbance_probability > 0) {
        float chance = (1.0 - (t_val -0.9) * 10.0) * rand(gl_GlobalInvocationID.xy);
        if (chance > 1-(pc.add_perturbance_probability * normed_1)) {
            float u_perb = rand(vec2(gl_GlobalInvocationID.xy + vec2(2, 1)));
            float v_perb = rand(vec2(gl_GlobalInvocationID.xy + vec2(1, 2)));
            u_perb = (u_perb < 0.333) ? -perb_step : (u_perb > 0.666) ? perb_step : 0.0;
            v_perb = (v_perb < 0.333) ? -perb_step : (v_perb > 0.666) ? perb_step : 0.0;
            u_val += u_perb;
            v_val += v_perb;
        }
    }
    imageStore(uvst_out, cell, vec4(u_val, v_val, s_val, t_val));
}