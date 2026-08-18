extends Control

# Superficie ilustrada del atlas. La geometria trapezoidal simula una carta
# observada desde el aire y el shader añade un relieve direccional muy contenido.

var atlas_texture: Texture2D
var flat_rect := Rect2()
var projected_quad := PackedVector2Array()
var relief_strength := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float relief_strength = 5.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * 2.0;
	float left_h = luminance(texture(TEXTURE, UV - vec2(pixel.x, 0.0)).rgb);
	float right_h = luminance(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).rgb);
	float up_h = luminance(texture(TEXTURE, UV - vec2(0.0, pixel.y)).rgb);
	float down_h = luminance(texture(TEXTURE, UV + vec2(0.0, pixel.y)).rgb);
	float relief = ((left_h - right_h) * 0.62 + (up_h - down_h) * 0.78) * relief_strength;
	relief = clamp(relief, -0.16, 0.18);
	float horizon = mix(0.84, 1.05, smoothstep(0.0, 0.92, UV.y));
	float vignette = 1.0 - smoothstep(0.52, 0.88, distance(UV, vec2(0.5))) * 0.20;
	vec3 color = base.rgb * (1.0 + relief) * horizon * vignette;
	COLOR = vec4(color, base.a) * COLOR;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("relief_strength", relief_strength)
	material = shader_material


func set_relief_strength(value: float) -> void:
	relief_strength = clampf(value, 0.0, 8.0)
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("relief_strength", relief_strength)


func set_view(texture: Texture2D, rect: Rect2) -> void:
	var changed := atlas_texture != texture or flat_rect != rect
	atlas_texture = texture
	flat_rect = rect
	projected_quad = _build_projected_quad(rect)
	if changed:
		queue_redraw()


func project_uv(uv: Vector2) -> Vector2:
	if projected_quad.size() != 4:
		return flat_rect.position + uv * flat_rect.size
	var top := projected_quad[0].lerp(projected_quad[1], uv.x)
	var bottom := projected_quad[3].lerp(projected_quad[2], uv.x)
	return top.lerp(bottom, uv.y)


func unproject_point(point: Vector2) -> Vector2:
	if projected_quad.size() != 4:
		return Vector2(-1.0, -1.0)
	var top_y := projected_quad[0].y
	var bottom_y := projected_quad[3].y
	var v := (point.y - top_y) / maxf(bottom_y - top_y, 0.001)
	if v < 0.0 or v > 1.0:
		return Vector2(-1.0, -1.0)
	var left_x := lerpf(projected_quad[0].x, projected_quad[3].x, v)
	var right_x := lerpf(projected_quad[1].x, projected_quad[2].x, v)
	var u := (point.x - left_x) / maxf(right_x - left_x, 0.001)
	if u < 0.0 or u > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(u, v)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("102d3a"), true)
	if atlas_texture == null or projected_quad.size() != 4:
		return
	var shadow := PackedVector2Array()
	for point in projected_quad:
		shadow.append(point + Vector2(0.0, 8.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.4))
	draw_polygon(
		projected_quad,
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0), Vector2.ONE, Vector2(0.0, 1.0)]),
		atlas_texture
	)


func _build_projected_quad(rect: Rect2) -> PackedVector2Array:
	var top_inset := rect.size.x * 0.065
	var top_y := rect.position.y + rect.size.y * 0.045
	var bottom_y := rect.end.y - rect.size.y * 0.025
	return PackedVector2Array([
		Vector2(rect.position.x + top_inset, top_y),
		Vector2(rect.end.x - top_inset, top_y),
		Vector2(rect.end.x, bottom_y),
		Vector2(rect.position.x, bottom_y),
	])
