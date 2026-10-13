shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 palette : source_color = vec3(0.95, 0.98, 0.9);

void fragment() {
	vec3 source = texture(albedo_texture, UV).rgb;
	// Lift the unusually dark source atlas without painting over its UV islands.
	ALBEDO = clamp(pow(source, vec3(0.78)) * palette, vec3(0.0), vec3(1.0));
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.12;
	BACKLIGHT = vec3(0.22, 0.28, 0.16);
}
