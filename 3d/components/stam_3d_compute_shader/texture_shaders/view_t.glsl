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

vec4 get_fire_color_3d(float val) {
    val = clamp(val, 0.0, 1.0);
    float r, g, b, a;
	a = 1.;
    if (val < 0.3) {
        float _s = val / 0.3;
        r = 0.2 * _s;
        g = 0.2 * _s;
        b = 0.2 * _s;
        a = 0.1 * _s;
    } else if (val < 0.5) {
        float _s = (val - 0.3) / 0.2;
        r = 0.2 + 0.8 * _s;
        g = 0.1;
        b = 0.1;
        a = .1 + _s;
    } else {
        float _s = (val - 0.5) / 0.48;
        r = 1.0;
        g = _s;
        b = 0.0;
    }
    return vec4(r, g, b, a);
}

// --- experimental
// const float PI = 3.14159265358979323846264338327950288419716939937510;
// const float SPEED_OF_LIGHT = 299792458.; // METER / SECOND
// const float BOLTZMANN_CONSTANT = 1.3806485279e-23; // * JOULE / KELVIN;
// const float STEPHAN_BOLTZMANN_CONSTANT = 5.670373e-8; // * WATT / (METER*METER* KELVIN*KELVIN*KELVIN*KELVIN);
// const float PLANCK_CONSTANT = 6.62607004e-34; //* JOULE * SECOND;

// // see Lawson 2004, "The Blackbody Fraction, Infinite Series and Spreadsheets"
// // we only do a single iteration with n=1, because it doesn't have a noticeable effect on output
// float solve_black_body_fraction_below_wavelength(float wavelength, float temperature){ 
// 	const float iterations = 2.;
// 	const float h = PLANCK_CONSTANT;
// 	const float k = BOLTZMANN_CONSTANT;
// 	const float c = SPEED_OF_LIGHT;

// 	float L = wavelength;
// 	float T = temperature;

// 	float C2 = h*c/k;
// 	float z = C2 / (L*T);
	
// 	return 15.*(z*z*z + 3.*z*z + 6.*z + 6.) * exp(-z)/(PI*PI*PI*PI);
// }
// float solve_black_body_fraction_between_wavelengths(float lo, float hi, float temperature){
// 	return 	solve_black_body_fraction_below_wavelength(hi, temperature) - 
// 			solve_black_body_fraction_below_wavelength(lo, temperature);
// }
// // This calculates the radiation (in watts/m^2) that's emitted 
// // by a single object using the Stephan-Boltzmann equation
// float get_black_body_emissive_flux(float temperature){
//     float T = temperature;
//     return STEPHAN_BOLTZMANN_CONSTANT * T*T*T*T;
// }

// float calculate_opacity(float temperature, float smoke_start_temperature, float fire_start_temperature) {
//     if (temperature <= smoke_start_temperature) {
//         // Below smoke temperature: no smoke or fire, fully transparent
//         return 0.0; // No opacity
//     } else if (temperature < fire_start_temperature) {
//         // Between smoke start and fire start: smoke, increasing opacity
//         // Gradually increase opacity from 0 to 0.5
//         return 0.0; // No opacity
//         return mix(0.0, 0.5, (temperature - smoke_start_temperature) / (fire_start_temperature - smoke_start_temperature));
//     } else {
//         // Above fire start: fire, high opacity
//         return 1.0; // Full opacity
//     }
// }

// vec4 get_fire_color_3d_new(float val) {
//     // float T = val*1370.+273.15; // from freezing to the melting point of steel
//     // float min_temperature = 293.15; // Room temperature in Kelvin
//     float min_temperature = 790.0; // Room temperature in Kelvin
//     // float max_temperature = 1773.15; // High fire temperature in Kelvin
//     float max_temperature = 1500.15; // High fire temperature in Kelvin
//     float T = mix(min_temperature, max_temperature, val); // Interpolate temperature based on normalized value
//     float I = get_black_body_emissive_flux(T); // WATT/(METER*METER)
//     vec3 color = I * vec3(
//       solve_black_body_fraction_between_wavelengths(600e-9, 700e-9, T),
//       solve_black_body_fraction_between_wavelengths(500e-9, 600e-9, T),
//       solve_black_body_fraction_between_wavelengths(400e-9, 500e-9, T)
//     );
//     color = 1.0 - exp2( color * -1.0f ); // simple tonemap
//     color = pow( color, vec3(1.0/2.2) );
//     float smoke_start_temperature = 600.0; // Start of smoke temperature in Kelvin
//     float fire_start_temperature = 1200.0; // Start of fire temperature in Kelvin
//     float opacity = calculate_opacity(T, smoke_start_temperature, fire_start_temperature);
//     return vec4(color, opacity);
// }


void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID.xyz);
    vec3 texelSize = 1.0 / vec3(consts.viewX, consts.viewY, consts.viewZ);
    vec3 UVW = (vec3(cell) + 0.5) * texelSize;
    vec3 input_texelSize = 1.0 / vec3(consts.numX, consts.numY, consts.numZ);
    UVW.z = (consts.numZ - 1 + 0.5) * input_texelSize.z;

    vec4 finalColor = vec4(0.0);
    float max_temp = 0.0;
    vec4 add_smoke;
    vec4 fire_color;

    for (int z = 0; z < int(consts.numZ) - 1; z++) {
        float temp = texture(uvwt_in, UVW).a;
        vec4 color = get_fire_color_3d(temp);

        // Back-to-front blending with proper opacity accumulation
        add_smoke.rgb = color.rgb * color.a + finalColor.rgb * (1.0 - color.a);
        add_smoke.a = color.a + finalColor.a * (1.0 - color.a);
        if (max_temp < 0.5) {
            finalColor = add_smoke;
            // max_temp = 0;
        } else if (temp > max_temp) {
            finalColor = color;
            max_temp = temp;
        }

        finalColor = clamp(finalColor, 0.0, 1.0);
        UVW.z -= input_texelSize.z;
    }

    imageStore(output_image, cell.xy, finalColor);
}
