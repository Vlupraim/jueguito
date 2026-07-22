// Océano de prototipo para sectores Terrain3D.
// La malla aporta en COLOR.r profundidad (0 normal, 1 profunda) y en COLOR.g
// cercanía a costa. La espuma se genera proceduralmente: no necesita textura
// dedicada y solo aparece en el borde costero.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_normal : hint_normal, repeat_enable;
uniform sampler2D wave_height : repeat_enable;
uniform sampler2D foam_texture : repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.08, 0.43, 0.63, 0.62);
uniform vec4 deep_color : source_color = vec4(0.015, 0.12, 0.30, 0.88);
uniform vec4 foam_color : source_color = vec4(0.90, 0.97, 1.0, 0.94);
uniform float wave_tiling = 18.0;
uniform float detail_tiling = 31.0;
uniform float wave_speed = 0.018;
uniform float displacement_strength = 0.16;
uniform float normal_strength = 0.72;
uniform float foam_amount = 0.58;
uniform float foam_tiling = 22.0;
uniform float foam_speed = 0.012;

void vertex() {
	vec2 large_uv = UV * wave_tiling + vec2(TIME * wave_speed, TIME * wave_speed * 0.55);
	vec2 detail_uv = UV * detail_tiling + vec2(-TIME * wave_speed * 0.72, TIME * wave_speed * 0.92);
	float large_wave = texture(wave_height, large_uv).r;
	float detail_wave = texture(wave_height, detail_uv).r;
	VERTEX.y += ((large_wave - 0.5) * 0.72 + (detail_wave - 0.5) * 0.28) * displacement_strength;
}

void fragment() {
	vec2 large_uv = UV * wave_tiling + vec2(TIME * wave_speed, TIME * wave_speed * 0.55);
	vec2 detail_uv = UV * detail_tiling + vec2(-TIME * wave_speed * 0.72, TIME * wave_speed * 0.92);
	vec3 normal_a = texture(wave_normal, large_uv).rgb;
	vec3 normal_b = texture(wave_normal, detail_uv).rgb;
	NORMAL_MAP = mix(normal_a, normal_b, 0.42);
	NORMAL_MAP_DEPTH = normal_strength;

	float shore = clamp(COLOR.g, 0.0, 1.0);
	float declared_depth = clamp(COLOR.r, 0.0, 1.0);
	float depth_factor = max(declared_depth, 1.0 - shore);
	float breakup = texture(wave_height, detail_uv * 0.73).r;
	vec2 foam_uv_a = UV * foam_tiling + vec2(TIME * foam_speed, -TIME * foam_speed * 0.34);
	vec2 foam_uv_b = UV * foam_tiling * 0.63 + vec2(-TIME * foam_speed * 0.52, TIME * foam_speed * 0.41);
	float foam_detail = mix(texture(foam_texture, foam_uv_a).r, texture(foam_texture, foam_uv_b).r, 0.38);
	float foam_pattern = mix(breakup, foam_detail, foam_amount);
	float foam_mask = smoothstep(0.34, 0.76, shore * (0.54 + foam_pattern * 0.86));

	vec4 water = mix(shallow_color, deep_color, depth_factor);
	ALBEDO = mix(water.rgb, foam_color.rgb, foam_mask);
	ROUGHNESS = mix(0.16, 0.58, foam_mask);
	SPECULAR = mix(0.92, 0.35, foam_mask);
	ALPHA = max(water.a, foam_mask * foam_color.a);
}
