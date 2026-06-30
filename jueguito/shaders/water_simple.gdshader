// Agua de prototipo: simple, translucida y barata.
// El color no es fijo: el generador pasa shallow_color/deep_color segun la
// latitud del sector (indigo cerca de los polos, azul mar en el centro).
// La malla de agua marca agua profunda en COLOR.r (0 = normal, 1 = profunda).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.45, 0.66, 0.60);
uniform vec4 deep_color : source_color = vec4(0.03, 0.20, 0.42, 0.78);
// Ondas muy suaves para que el agua no se vea muerta. Pon 0.0 para plano total.
uniform float wave_strength = 0.18;
uniform float wave_speed = 0.6;
uniform float wave_scale = 0.012;
uniform float water_roughness = 0.12;

void vertex() {
	float wave = sin((VERTEX.x * wave_scale) + TIME * wave_speed)
		+ cos((VERTEX.z * wave_scale) + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_strength;
}

void fragment() {
	float depth_factor = clamp(COLOR.r, 0.0, 1.0);
	vec4 water = mix(shallow_color, deep_color, depth_factor);
	ALBEDO = water.rgb;
	ALPHA = water.a;
	ROUGHNESS = water_roughness;
	METALLIC = 0.0;
}
