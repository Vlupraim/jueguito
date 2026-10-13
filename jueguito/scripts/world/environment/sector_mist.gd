extends MeshInstance3D

const MATERIAL := preload("res://resources/environment/sector_mist_material.tres")

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	material_override = MATERIAL.duplicate() as ShaderMaterial
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true
	position.z = -0.1

func configure(bounds: Rect2, wind: Vector3, quality: int) -> void:
	var material := material_override as ShaderMaterial
	material.set_shader_parameter("sector_rect", Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	material.set_shader_parameter("wind_velocity", Vector2(wind.x,wind.z)*0.12)
	material.set_shader_parameter("samples", [6,10,16][clampi(quality,0,2)])
