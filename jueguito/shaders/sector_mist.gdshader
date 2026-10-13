shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D mist_noise : repeat_enable, filter_linear;
uniform vec4 sector_rect = vec4(0.0, 0.0, 512.0, 512.0);
uniform vec3 mist_color : source_color = vec3(0.65, 0.73, 0.79);
uniform vec2 wind_velocity = vec2(0.25, 0.1);
uniform float border_width = 85.0;
uniform float density = 0.22;
uniform float height_begin = 42.0;
uniform float height_end = 110.0;
uniform int samples : hint_range(4, 16) = 8;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 world_at(vec2 uv, float depth, mat4 inverse_view, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 world = inverse_view * inverse_projection * vec4(ndc, 1.0);
	return world.xyz / world.w;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 origin = world_at(SCREEN_UV, 1.0, INV_VIEW_MATRIX, INV_PROJECTION_MATRIX);
	vec3 end = world_at(SCREEN_UV, max(depth, 0.00001), INV_VIEW_MATRIX, INV_PROJECTION_MATRIX);
	vec3 ray = end - origin;
	float distance_to_surface = min(length(ray), 750.0);
	vec3 direction = normalize(ray);
	float stride = distance_to_surface / float(samples);
	float optical_depth = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= samples) break;
		vec3 point = origin + direction * (float(i) + 0.5) * stride;
		vec2 flow = (point.xz - wind_velocity * TIME) * 0.007;
		float noise = texture(mist_noise, flow).r;
		float edge = min(min(point.x - sector_rect.x, sector_rect.z - point.x),
			min(point.z - sector_rect.y, sector_rect.w - point.z));
		float thickness = 1.0 - smoothstep(15.0, border_width, edge + (noise - 0.5) * 18.0);
		float altitude = 1.0 - smoothstep(height_begin, height_end, point.y + noise * 12.0);
		optical_depth += thickness * altitude * mix(0.75, 1.15, noise) * stride * density;
	}
	ALBEDO = mist_color;
	ALPHA = clamp(1.0 - exp(-optical_depth), 0.0, 1.0);
}
