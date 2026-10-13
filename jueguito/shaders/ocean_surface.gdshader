// Océano de prototipo para sectores Terrain3D.
// La malla aporta en COLOR.r profundidad (0 normal, 1 profunda) y en COLOR.g
// cercanía a costa. La espuma se genera proceduralmente: no necesita textura
// dedicada y solo aparece en el borde costero.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_normal : hint_normal, repeat_enable;
uniform sampler2D wave_height : repeat_enable;
uniform sampler2D foam_texture : repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.14, 0.58, 0.82, 0.55);
uniform vec4 deep_color : source_color = vec4(0.03, 0.22, 0.54, 0.82);
uniform vec4 foam_color : source_color = vec4(0.90, 0.97, 1.0, 0.94);
uniform float wave_tiling = 18.0;
uniform float detail_tiling = 31.0;
uniform float wave_speed = 0.018;
uniform float displacement_strength = 0.16;
uniform float normal_strength = 0.72;
uniform float foam_amount = 0.58;
uniform float foam_tiling = 22.0;
uniform float foam_speed = 0.012;
uniform vec3 sea_haze_color : source_color = vec3(0.65, 0.73, 0.79);
uniform float sea_haze_strength : hint_range(0.0, 1.0) = 0.38;
uniform float sea_haze_begin = 140.0;
uniform float sea_haze_end = 1050.0;
uniform bool sea_haze_enabled = true;

void vertex() {
	vec2 large_uv = UV * wave_tiling + vec2(TIME * wave_speed, TIME * wave_speed * 0.55);
	vec2 detail_uv = UV * detail_tiling + vec2(-TIME * wave_speed * 0.72, TIME * wave_speed * 0.92);
	float large_wave = texture(wave_height, large_uv).r;
	float detail_wave = 0.5;
	if (COLOR.g > 0.02) {
		detail_wave = texture(wave_height, detail_uv).r;
	}
	VERTEX.y += ((large_wave - 0.5) * 0.72 + (detail_wave - 0.5) * 0.28) * displacement_strength;
}

void fragment() {
	vec2 large_uv = UV * wave_tiling + vec2(TIME * wave_speed, TIME * wave_speed * 0.55);
	vec2 detail_uv = UV * detail_tiling + vec2(-TIME * wave_speed * 0.72, TIME * wave_speed * 0.92);
	float shore = clamp(COLOR.g, 0.0, 1.0);
	float declared_depth = clamp(COLOR.r, 0.0, 1.0);
	float depth_factor = max(declared_depth, 1.0 - shore);
	vec3 normal_a = texture(wave_normal, large_uv).rgb;
	NORMAL_MAP = normal_a;
	float foam_mask = 0.0;
	if (shore > 0.02) {
		vec3 normal_b = texture(wave_normal, detail_uv).rgb;
		NORMAL_MAP = mix(normal_a, normal_b, 0.42);
		float breakup = texture(wave_height, detail_uv * 0.73).r;
		vec2 foam_uv_a = UV * foam_tiling + vec2(TIME * foam_speed, -TIME * foam_speed * 0.34);
		vec2 foam_uv_b = UV * foam_tiling * 0.63 + vec2(-TIME * foam_speed * 0.52, TIME * foam_speed * 0.41);
		float foam_detail = mix(texture(foam_texture, foam_uv_a).r, texture(foam_texture, foam_uv_b).r, 0.38);
		float foam_pattern = mix(breakup, foam_detail, foam_amount);
		foam_mask = smoothstep(0.34, 0.76, shore * (0.54 + foam_pattern * 0.86));
	}
	NORMAL_MAP_DEPTH = normal_strength;

	// Efecto Fresnel para mayor transparencia cerca de la cámara y reflejo en ángulo rasante
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 water = mix(shallow_color, deep_color, depth_factor);

	vec3 base_albedo = mix(water.rgb, water.rgb * 1.15 + vec3(0.02, 0.05, 0.08), fresnel * 0.35);
	ALBEDO = mix(base_albedo, foam_color.rgb, foam_mask);
	ROUGHNESS = mix(mix(0.10, 0.22, fresnel * 0.5), 0.58, foam_mask);
	SPECULAR = mix(mix(0.92, 1.0, fresnel), 0.35, foam_mask);
	
	float adapt_alpha = clamp(water.a + fresnel * 0.28, 0.0, 0.95);
	ALPHA = max(adapt_alpha, foam_mask * foam_color.a);
	// Extra maritime haze affects the ocean only; nearby beach stays clear.
	float haze = sea_haze_enabled ? smoothstep(sea_haze_begin, sea_haze_end, length(VERTEX)) * sea_haze_strength : 0.0;
	// Keep Godot's environment fog active (writing FOG would replace it).
	ALBEDO *= 1.0 - haze;
	SPECULAR *= 1.0 - haze;
	EMISSION = sea_haze_color * haze;
}
