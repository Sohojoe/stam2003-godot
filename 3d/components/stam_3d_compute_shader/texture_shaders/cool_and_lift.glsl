#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;


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
layout(set = 0, binding = 2, rgba16f) uniform image3D uvwt_out;

// --- End Shared Buffer Definition

layout(push_constant, std430) uniform Params {
    float dt;
    float add_perturbance_probability;
    float seed;
    // float wind_x;
    // float wind_y;
} pc;


float rand(vec3 co) {
    return fract(sin(dot(co.xyz, vec3(12.9898, 78.233, 45.164)) + pc.seed) * 43758.5453);
}

void main() {

    // uint idx = gl_GlobalInvocationID.x;
    // uint idy = gl_GlobalInvocationID.y;
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


    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);

    vec4 uvwt = texelFetch(uvwt_in, cell, 0);
    float u_val = uvwt.x;
    float v_val = uvwt.y;
    float w_val = uvwt.z;
    float t_val = uvwt.w;

    float cooling = (t_val < 0.3) ? smoke_cooling : fire_cooling;
    t_val = max(t_val - cooling, 0.0);

    float target_v = t_val * lift;
    float v_diff = (target_v - v_val) * acceleration;
    v_diff = max(v_diff, 0.0);
    v_val += v_diff;

    if (t_val > 0.9 && pc.add_perturbance_probability > 0) {
        float chance = (1.0 - (t_val -0.9) * 10.0) * rand(gl_GlobalInvocationID.xyz);
        if (chance > 1-(pc.add_perturbance_probability * normed_1)) {
            float u_perb = rand(vec3(gl_GlobalInvocationID.xyz + vec3(0, 1, 2)));
            float v_perb = rand(vec3(gl_GlobalInvocationID.xyz + vec3(2, 0, 1)));
            float w_perb = rand(vec3(gl_GlobalInvocationID.xyz + vec3(1, 2, 0)));
            u_perb = (u_perb < 0.333) ? -perb_step : (u_perb > 0.666) ? perb_step : 0.0;
            v_perb = (v_perb < 0.333) ? -perb_step : (v_perb > 0.666) ? perb_step : 0.0;
            w_perb = (w_perb < 0.333) ? -perb_step : (w_perb > 0.666) ? perb_step : 0.0;
            u_val += u_perb;
            v_val += v_perb;
            w_val += w_perb;
        }
    }
    imageStore(uvwt_out, cell, vec4(u_val, v_val, w_val, t_val));
}