shader_type sky;
render_mode use_half_res_pass;

// Clouds use the screen's half-resolution pass, independent of cubemap resolution.
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 zenith_color : source_color = vec3(0.22, 0.40, 0.63);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.73, 0.79);
uniform vec3 cloud_light : source_color = vec3(0.95, 0.94, 0.88);
uniform vec3 cloud_shadow : source_color = vec3(0.50, 0.59, 0.68);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.50;
uniform float cloud_scale : hint_range(0.1, 4.0) = 0.65;
uniform vec2 cloud_offset = vec2(0.19, 0.37);
uniform vec2 wind_velocity = vec2(5.66, 1.98);
uniform float cloud_layer_height = 900.0;

vec3 atmosphere(vec3 dir) {
	float elevation = pow(clamp(dir.y, 0.0, 1.0), 0.45);
	vec3 color = mix(horizon_color, zenith_color, elevation);
	if (LIGHT0_ENABLED) {
		float facing_sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		color += LIGHT0_COLOR * pow(facing_sun, 32.0) * 0.13;
		color += LIGHT0_COLOR * smoothstep(0.99982, 0.99995, facing_sun) * 1.8;
	}
	return color;
}

vec4 cloud_layer(vec3 dir) {
	vec4 cloud = vec4(0.0);
	if (dir.y > 0.12) {
		// A distant horizontal layer; perspective compresses it near the horizon.
		vec2 flow = wind_velocity * TIME / cloud_layer_height;
		vec2 uv = (dir.xz / dir.y - flow) * cloud_scale + cloud_offset;
		float broad = texture(cloud_noise, uv).r;
		float detail = texture(cloud_noise, uv * 2.13 + vec2(0.31, 0.73)).r;
		float density = broad * 0.82 + detail * 0.18;
		float threshold = mix(0.80, 0.30, cloud_coverage);
		float clouds = smoothstep(threshold, threshold + 0.14, density);
		// Clear horizon band: no frozen projection producing downward streaks.
		clouds *= smoothstep(0.12, 0.23, dir.y);
		vec3 cloud_color = mix(cloud_shadow, cloud_light, smoothstep(threshold, threshold + 0.25, density));
		cloud = vec4(cloud_color, clouds * 0.90);
	}
	return cloud;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// Small, inexpensive lighting map. Clouds are drawn only for the visible sky.
		COLOR = atmosphere(EYEDIR);
	} else if (AT_HALF_RES_PASS) {
		vec4 cloud = cloud_layer(EYEDIR);
		COLOR = cloud.rgb;
		ALPHA = cloud.a;
	} else {
		COLOR = mix(atmosphere(EYEDIR), HALF_RES_COLOR.rgb, HALF_RES_COLOR.a);
	}
}
