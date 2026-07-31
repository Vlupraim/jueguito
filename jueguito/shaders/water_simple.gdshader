// Agua de prototipo: simple, translucida y barata.
// El color no es fijo: el generador pasa shallow_color/deep_color segun la
// latitud del sector (indigo cerca de los polos, azul mar en el centro).
// La malla de agua marca agua profunda en COLOR.r (0 = normal, 1 = profunda).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.14, 0.58, 0.82, 0.55);
uniform vec4 deep_color : source_color = vec4(0.03, 0.22, 0.54, 0.82);
// Ondas muy suaves para que el agua no se vea muerta. Pon 0.0 para plano total.
uniform float wave_strength = 0.18;
uniform float wave_speed = 0.6;
uniform float wave_scale = 0.012;
uniform float water_roughness = 0.10;

void vertex() {
	float wave = sin((VERTEX.x * wave_scale) + TIME * wave_speed)
		+ cos((VERTEX.z * wave_scale) + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_strength;
}

void fragment() {
	float depth_factor = clamp(COLOR.r, 0.0, 1.0);
	vec4 water = mix(shallow_color, deep_color, depth_factor);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(water.rgb, water.rgb * 1.15 + vec3(0.02, 0.05, 0.08), fresnel * 0.35);
	ALPHA = clamp(water.a + fresnel * 0.28, 0.0, 0.95);
	ROUGHNESS = mix(water_roughness, 0.22, fresnel * 0.5);
	SPECULAR = mix(0.9, 1.0, fresnel);
	METALLIC = 0.0;
}
