extends SubViewportContainer

# Proxy cartografico 3D. Reconstruye una maqueta ligera desde los exports del
# sector; no instancia Terrain3D ni la vegetacion jugable.

const GRID_RESOLUTION := 96
const MAP_EXTENT := 112.0
const CAMERA_SIZE := 86.0
const CAMERA_POSITION := Vector3(0.0, 74.0, 64.0)
const CAMERA_TARGET := Vector3(0.0, 2.5, 0.0)

const REFERENCE_WATER := Color8(31, 91, 160)
const REFERENCE_SAND := Color8(212, 187, 122)
const REFERENCE_LAND := Color8(70, 134, 63)
const SURFACE_SMOOTHING_KERNEL := [
	Vector3(0.0, 0.0, 0.28),
	Vector3(0.018, 0.0, 0.12),
	Vector3(-0.018, 0.0, 0.12),
	Vector3(0.0, 0.018, 0.12),
	Vector3(0.0, -0.018, 0.12),
	Vector3(0.0127, 0.0127, 0.06),
	Vector3(-0.0127, 0.0127, 0.06),
	Vector3(0.0127, -0.0127, 0.06),
	Vector3(-0.0127, -0.0127, 0.06),
]

var map_viewport: SubViewport
var map_root: Node3D
var map_camera: Camera3D
var base_camera_transform := Transform3D.IDENTITY
var height_image: Image
var surface_image: Image
var configured_sector := Vector2i(-1, -1)
var view_zoom := 1.0
var view_pan := Vector2.ZERO
var terrain_ready := false


func _ready() -> void:
	_ensure_viewport()
	resized.connect(_sync_viewport_size)
	call_deferred("_sync_viewport_size")


func configure_sector(sector: Vector2i, export_root: String) -> bool:
	_ensure_viewport()
	var sector_dir := "%s/sector_%d_%d" % [export_root, sector.x, sector.y]
	var height_path := sector_dir + "/height_preview.png"
	var surface_path := sector_dir + "/surface_reference.png"
	if not ResourceLoader.exists(height_path) or not ResourceLoader.exists(surface_path):
		terrain_ready = false
		visible = false
		return false

	var height_texture := load(height_path) as Texture2D
	var surface_texture := load(surface_path) as Texture2D
	if height_texture == null or surface_texture == null:
		terrain_ready = false
		visible = false
		return false
	height_image = height_texture.get_image()
	surface_image = surface_texture.get_image()
	if height_image == null or surface_image == null:
		terrain_ready = false
		visible = false
		return false
	_prepare_image(height_image)
	_prepare_image(surface_image)
	_clear_map_root()
	_build_ocean_plane()
	_build_terrain()
	_build_cartographic_vegetation()
	configured_sector = sector
	terrain_ready = true
	visible = true
	set_view_transform(view_zoom, view_pan)
	return true


func is_configured() -> bool:
	return terrain_ready


func set_view_transform(zoom: float, pan_pixels: Vector2) -> void:
	view_zoom = clampf(zoom, 1.0, 2.5)
	view_pan = pan_pixels
	if map_camera == null:
		return
	map_camera.size = CAMERA_SIZE / view_zoom
	map_camera.transform = base_camera_transform
	var viewport_height := maxf(float(map_viewport.size.y), 1.0)
	var world_per_pixel := map_camera.size / viewport_height
	var right := base_camera_transform.basis.x.normalized()
	var screen_up := base_camera_transform.basis.y.normalized()
	var camera_shift := -right * view_pan.x * world_per_pixel
	camera_shift += screen_up * view_pan.y * world_per_pixel
	map_camera.position = CAMERA_POSITION + camera_shift
	map_camera.look_at(CAMERA_TARGET + camera_shift, Vector3.UP)


func project_uv(uv: Vector2) -> Vector2:
	if not terrain_ready or map_camera == null:
		return uv * size
	var clamped_uv := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	var world_position := _uv_to_world(clamped_uv, true)
	return map_camera.unproject_position(world_position)


func unproject_screen_to_uv(screen_position: Vector2) -> Vector2:
	if not terrain_ready or map_camera == null:
		return Vector2(
			clampf(screen_position.x / maxf(size.x, 1.0), 0.0, 1.0),
			clampf(screen_position.y / maxf(size.y, 1.0), 0.0, 1.0)
		)
	var ray_origin := map_camera.project_ray_origin(screen_position)
	var ray_direction := map_camera.project_ray_normal(screen_position)
	var map_plane := Plane(Vector3.UP, 1.0)
	var hit: Variant = map_plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return Vector2(-1.0, -1.0)
	var point := hit as Vector3
	return Vector2(
		clampf(point.x / MAP_EXTENT + 0.5, 0.0, 1.0),
		clampf(point.z / MAP_EXTENT + 0.5, 0.0, 1.0)
	)


func _ensure_viewport() -> void:
	if map_viewport != null:
		return
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_viewport = SubViewport.new()
	map_viewport.name = "ViewportCartografico3D"
	map_viewport.own_world_3d = true
	map_viewport.transparent_bg = false
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(map_viewport)

	map_root = Node3D.new()
	map_root.name = "MaquetaSector"
	map_viewport.add_child(map_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("315f6b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a8bab3")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	map_viewport.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "LuzCartografica"
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_color = Color("ffe3b0")
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	map_viewport.add_child(sun)

	map_camera = Camera3D.new()
	map_camera.name = "CamaraCartografica"
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = CAMERA_SIZE
	map_camera.position = CAMERA_POSITION
	map_viewport.add_child(map_camera)
	map_camera.look_at(CAMERA_TARGET, Vector3.UP)
	map_camera.current = true
	base_camera_transform = map_camera.transform
	_sync_viewport_size()


func _sync_viewport_size() -> void:
	if map_viewport == null:
		return
	# Con `stretch` activo el contenedor mantiene automaticamente el viewport
	# sincronizado con su rectangulo. Aqui solo recalculamos la camara.
	set_view_transform(view_zoom, view_pan)


func _clear_map_root() -> void:
	for child in map_root.get_children():
		child.free()


func _build_ocean_plane() -> void:
	# El proxy debe sentirse como una costa continua, no como una baldosa 3D.
	# Este plano cubre el fondo del viewport y oculta los cantos de la maqueta.
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(MAP_EXTENT * 5.0, MAP_EXTENT * 5.0)
	var ocean_material := StandardMaterial3D.new()
	ocean_material.albedo_color = Color("315f6b")
	ocean_material.roughness = 0.9
	ocean_material.metallic_specular = 0.08
	ocean_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ocean_mesh.material = ocean_material
	var ocean_instance := MeshInstance3D.new()
	ocean_instance.name = "OceanoCartografico"
	ocean_instance.mesh = ocean_mesh
	ocean_instance.position.y = -0.36
	map_root.add_child(ocean_instance)


func _build_terrain() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(GRID_RESOLUTION - 1):
		for x_index in range(GRID_RESOLUTION - 1):
			var uv00 := Vector2(
				float(x_index) / float(GRID_RESOLUTION - 1),
				float(z_index) / float(GRID_RESOLUTION - 1)
			)
			var uv10 := Vector2(
				float(x_index + 1) / float(GRID_RESOLUTION - 1),
				uv00.y
			)
			var uv01 := Vector2(
				uv00.x,
				float(z_index + 1) / float(GRID_RESOLUTION - 1)
			)
			var uv11 := Vector2(uv10.x, uv01.y)
			_emit_triangle(surface_tool, uv00, uv01, uv10)
			_emit_triangle(surface_tool, uv10, uv01, uv11)
	surface_tool.generate_normals()
	var terrain_mesh := surface_tool.commit()
	var material := ShaderMaterial.new()
	var terrain_shader := Shader.new()
	terrain_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

void fragment() {
	float water = step(COLOR.r + 0.035, COLOR.b);
	ALBEDO = COLOR.rgb * (1.0 - water);
	EMISSION = COLOR.rgb * water * 0.36;
	ROUGHNESS = 0.9;
	SPECULAR = 0.16;
}
"""
	material.shader = terrain_shader
	terrain_mesh.surface_set_material(0, material)
	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "RelieveSector"
	terrain_instance.mesh = terrain_mesh
	map_root.add_child(terrain_instance)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(MAP_EXTENT, 2.5, MAP_EXTENT)
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color("243138")
	base_material.roughness = 1.0
	base_mesh.material = base_material
	var base_instance := MeshInstance3D.new()
	base_instance.name = "BaseMaqueta"
	base_instance.mesh = base_mesh
	base_instance.position.y = -2.3
	map_root.add_child(base_instance)


func _emit_triangle(surface_tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	for uv in [a, b, c]:
		surface_tool.set_uv(uv)
		surface_tool.set_color(_map_color(uv))
		surface_tool.add_vertex(_uv_to_world(uv, false))


func _uv_to_world(uv: Vector2, marker_offset: bool) -> Vector3:
	var weights := _surface_weights(uv)
	var height_value := _sample_height(uv)
	var water_height := -0.35
	var sand_height := 0.1 + height_value * 2.2
	var land_height := 0.7 + pow(height_value, 1.18) * 18.0
	var map_height := water_height * weights.x
	map_height += sand_height * weights.y
	map_height += land_height * weights.z
	if marker_offset:
		map_height += 1.25
	return Vector3(
		(uv.x - 0.5) * MAP_EXTENT,
		map_height,
		(uv.y - 0.5) * MAP_EXTENT
	)


func _map_color(uv: Vector2) -> Color:
	var height_value := _sample_height(uv)
	var weights := _surface_weights(uv)
	var water_color := Color("1f6078").lerp(Color("376f82"), height_value * 0.18)
	var sand_color := Color("ae9563").lerp(Color("c9b27b"), height_value * 0.3)
	var land_color := Color("50643b").lerp(Color("788d54"), height_value * 0.38)
	if height_value > 0.68:
		land_color = land_color.lerp(Color("7a796c"), (height_value - 0.68) / 0.32)
	return water_color * weights.x + sand_color * weights.y + land_color * weights.z


func _build_cartographic_vegetation() -> void:
	var placements: Array[Transform3D] = []
	for z_index in range(7, GRID_RESOLUTION - 7, 6):
		for x_index in range(7, GRID_RESOLUTION - 7, 6):
			var uv := Vector2(
				float(x_index) / float(GRID_RESOLUTION - 1),
				float(z_index) / float(GRID_RESOLUTION - 1)
			)
			if _surface_kind(uv) != 2:
				continue
			var seed_value := fposmod(
				sin(float(x_index) * 12.9898 + float(z_index) * 78.233) * 43758.5453,
				1.0
			)
			if seed_value < 0.42:
				continue
			var position := _uv_to_world(uv, true)
			var scale_value := 0.75 + seed_value * 0.65
			placements.append(Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * scale_value),
				position
			))
	_build_tree_layer(placements, false)
	_build_tree_layer(placements, true)


func _build_tree_layer(placements: Array[Transform3D], crown: bool) -> void:
	if placements.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = placements.size()
	var mesh: PrimitiveMesh
	if crown:
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = 1.45
		crown_mesh.height = 4.2
		crown_mesh.radial_segments = 5
		mesh = crown_mesh
	else:
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.22
		trunk_mesh.bottom_radius = 0.32
		trunk_mesh.height = 2.0
		trunk_mesh.radial_segments = 5
		mesh = trunk_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("435536") if crown else Color("59442f")
	material.roughness = 1.0
	mesh.material = material
	multimesh.mesh = mesh
	for index in range(placements.size()):
		var transform := placements[index]
		transform.origin.y += 2.7 if crown else 0.8
		multimesh.set_instance_transform(index, transform)
	var instance := MultiMeshInstance3D.new()
	instance.name = "CopasCartograficas" if crown else "TroncosCartograficos"
	instance.multimesh = multimesh
	map_root.add_child(instance)


func _surface_kind(uv: Vector2) -> int:
	var weights := _surface_weights(uv)
	if weights.x >= weights.y and weights.x >= weights.z:
		return 0
	if weights.y >= weights.z:
		return 1
	return 2


func _surface_weights(uv: Vector2) -> Vector3:
	var weights := Vector3.ZERO
	for kernel_sample in SURFACE_SMOOTHING_KERNEL:
		var sample_uv := Vector2(
			clampf(uv.x + kernel_sample.x, 0.0, 1.0),
			clampf(uv.y + kernel_sample.y, 0.0, 1.0)
		)
		match _surface_kind_raw(sample_uv):
			0:
				weights.x += kernel_sample.z
			1:
				weights.y += kernel_sample.z
			_:
				weights.z += kernel_sample.z
	return weights


func _surface_kind_raw(uv: Vector2) -> int:
	var color := _sample_image(surface_image, uv)
	var water_distance := _color_distance_squared(color, REFERENCE_WATER)
	var sand_distance := _color_distance_squared(color, REFERENCE_SAND)
	var land_distance := _color_distance_squared(color, REFERENCE_LAND)
	if water_distance <= sand_distance and water_distance <= land_distance:
		return 0
	if sand_distance <= land_distance:
		return 1
	return 2


func _sample_height(uv: Vector2) -> float:
	return clampf(_sample_image(height_image, uv).r, 0.0, 1.0)


func _sample_image(image: Image, uv: Vector2) -> Color:
	if image == null or image.is_empty():
		return Color.BLACK
	var pixel := Vector2i(
		clampi(int(round(uv.x * float(image.get_width() - 1))), 0, image.get_width() - 1),
		clampi(int(round(uv.y * float(image.get_height() - 1))), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel)


func _prepare_image(image: Image) -> void:
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)


func _color_distance_squared(a: Color, b: Color) -> float:
	var delta := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return delta.length_squared()
