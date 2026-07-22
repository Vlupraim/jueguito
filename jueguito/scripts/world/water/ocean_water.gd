@tool
extends Node3D
class_name OceanWater

const EXPORT_DIR := "res://data/terrain3d_exports"
const SURFACE_WATER := 2
const SURFACE_DEEP_WATER := 4

@export var water_level := 2.0
@export_range(32, 192, 1) var mesh_resolution := 128
@export_range(16, 96, 1) var collision_resolution := 48
@export_range(2, 24, 1) var foam_search_pixels := 12
@export_range(4, 48, 1) var coast_overlap_pixels := 28
@export_range(0.25, 4.0, 0.05) var foam_depth_meters := 1.65
@export_range(0.0, 0.5, 0.01) var water_entry_depth := 0.08
@export_range(0.5, 3.0, 0.05) var swim_depth_threshold := 1.20
@export var fallback_sector_size := 512.0
@export var water_area_depth := 80.0

@onready var water_surface: MeshInstance3D = %WaterSurface
@onready var water_area: Area3D = %WaterArea
@onready var shore_loop: AudioStreamPlayer3D = %ShoreLoop
@onready var shore_lapping: AudioStreamPlayer3D = %ShoreLapping
@onready var wave_break: AudioStreamPlayer3D = %WaveBreak
@onready var wave_timer: Timer = %WaveTimer

var current_sector := Vector2i(-1, -1)
var sector_bounds := Rect2(Vector2.ZERO, Vector2(512.0, 512.0))
var surface_image: Image
var water_cell_count := 0
var shoreline_cell_count := 0
var water_collision_shape_count := 0
var _rng := RandomNumberGenerator.new()
var _terrain: Node
var _ocean_zone_mask := PackedByteArray()
var _shore_factor_mask := PackedFloat32Array()


func _ready() -> void:
	add_to_group("water_body")
	_rng.randomize()
	if not Engine.is_editor_hint():
		shore_loop.finished.connect(func(): _restart_loop(shore_loop))
		shore_lapping.finished.connect(func(): _restart_loop(shore_lapping))
		wave_timer.timeout.connect(_play_random_wave)


func configure_for_sector(next_sector: Vector2i, terrain: Node = null) -> bool:
	current_sector = next_sector
	_terrain = terrain
	sector_bounds = _fixed_sector_bounds(next_sector, terrain)
	var reference_path := "%s/sector_%d_%d/surface_reference.png" % [
		EXPORT_DIR,
		next_sector.x,
		next_sector.y,
	]
	if not FileAccess.file_exists(reference_path):
		_clear_water()
		return false

	surface_image = Image.load_from_file(ProjectSettings.globalize_path(reference_path))
	if surface_image == null or surface_image.is_empty():
		_clear_water()
		return false

	_rebuild_spatial_masks()
	_rebuild_surface()
	if Engine.is_editor_hint():
		_clear_water_area()
	else:
		_rebuild_water_area()
		_configure_audio()
	return water_cell_count > 0


func get_water_info(world_position: Vector3, terrain_height := INF) -> Dictionary:
	if surface_image == null or not sector_bounds.has_point(Vector2(world_position.x, world_position.z)):
		return {"in_water": false, "state": "dry"}
	var uv := Vector2(
		(world_position.x - sector_bounds.position.x) / sector_bounds.size.x,
		(world_position.z - sector_bounds.position.y) / sector_bounds.size.y
	)
	var surface_kind := _surface_kind_at_uv(uv)
	if not _is_ocean_zone_at_uv(uv):
		return {"in_water": false, "state": "dry"}

	var depth := water_level - terrain_height if terrain_height != INF else 0.0
	if terrain_height != INF and depth <= water_entry_depth:
		return {"in_water": false, "state": "dry"}
	var shore_factor := _terrain_shore_factor(depth) if terrain_height != INF else _mask_shore_factor_at_uv(uv)
	var mask_shore_factor := _mask_shore_factor_at_uv(uv)
	var state := "wading"
	if depth > swim_depth_threshold:
		state = "swimming" if mask_shore_factor > 0.08 else "open_water"
	return {
		"in_water": true,
		"state": state,
		"water_level": water_level,
		"depth": maxf(depth, 0.0),
		"shore_factor": shore_factor,
		"deep_water": surface_kind == SURFACE_DEEP_WATER,
	}


func _fixed_sector_bounds(sector: Vector2i, terrain: Node) -> Rect2:
	# El footprint pertenece al export original, no a las regiones activas. Un
	# pincel que cruza el borde puede crear regiones Terrain3D auxiliares; usarlas
	# para calcular estos limites estiraria y desplazaria la mascara del oceano.
	var export_resolution := fallback_sector_size
	var metadata_path := "%s/sector_%d_%d/metadata.json" % [EXPORT_DIR, sector.x, sector.y]
	if FileAccess.file_exists(metadata_path):
		var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
		if metadata_file != null:
			var parsed: Variant = JSON.parse_string(metadata_file.get_as_text())
			if parsed is Dictionary:
				export_resolution = float((parsed as Dictionary).get("export_resolution", fallback_sector_size))

	var import_scale := 1.0
	var import_origin := Vector2.ZERO
	if terrain != null:
		if "import_scale" in terrain:
			import_scale = maxf(float(terrain.get("import_scale")), 0.001)
		if "import_position" in terrain:
			var configured_position: Variant = terrain.get("import_position")
			if configured_position is Vector2i:
				import_origin = Vector2(configured_position)
	return Rect2(import_origin, Vector2.ONE * export_resolution * import_scale)


func _rebuild_surface() -> void:
	water_cell_count = 0
	shoreline_cell_count = 0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var shoreline_center := Vector2.ZERO
	var shoreline_weight := 0.0
	var resolution := maxi(mesh_resolution, 1)

	for z_index in range(resolution):
		var z0_ratio := float(z_index) / float(resolution)
		var z1_ratio := float(z_index + 1) / float(resolution)
		var z_mid := (z0_ratio + z1_ratio) * 0.5
		for x_index in range(resolution):
			var x0_ratio := float(x_index) / float(resolution)
			var x1_ratio := float(x_index + 1) / float(resolution)
			var x_mid := (x0_ratio + x1_ratio) * 0.5
			var uv_mid := Vector2(x_mid, z_mid)
			if not _is_ocean_zone_at_uv(uv_mid):
				continue

			var x0 := lerpf(sector_bounds.position.x, sector_bounds.end.x, x0_ratio)
			var x1 := lerpf(sector_bounds.position.x, sector_bounds.end.x, x1_ratio)
			var z0 := lerpf(sector_bounds.position.y, sector_bounds.end.y, z0_ratio)
			var z1 := lerpf(sector_bounds.position.y, sector_bounds.end.y, z1_ratio)
			var shore_factor := _visual_shore_factor(uv_mid, (x0 + x1) * 0.5, (z0 + z1) * 0.5)
			var base_index := vertices.size()
			vertices.append_array(PackedVector3Array([
				Vector3(x0, water_level, z0),
				Vector3(x1, water_level, z0),
				Vector3(x0, water_level, z1),
				Vector3(x1, water_level, z1),
			]))
			for _index in range(4):
				normals.append(Vector3.UP)
			colors.append(_vertex_color(Vector2(x0_ratio, z0_ratio), x0, z0))
			colors.append(_vertex_color(Vector2(x1_ratio, z0_ratio), x1, z0))
			colors.append(_vertex_color(Vector2(x0_ratio, z1_ratio), x0, z1))
			colors.append(_vertex_color(Vector2(x1_ratio, z1_ratio), x1, z1))
			uvs.append_array(PackedVector2Array([
				Vector2(x0_ratio, z0_ratio),
				Vector2(x1_ratio, z0_ratio),
				Vector2(x0_ratio, z1_ratio),
				Vector2(x1_ratio, z1_ratio),
			]))
			indices.append_array(PackedInt32Array([
				base_index,
				base_index + 2,
				base_index + 1,
				base_index + 1,
				base_index + 2,
				base_index + 3,
			]))
			water_cell_count += 1
			if shore_factor > 0.12:
				var weight := shore_factor * shore_factor
				shoreline_center += Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5) * weight
				shoreline_weight += weight
				shoreline_cell_count += 1

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	water_surface.mesh = mesh
	water_surface.visible = water_cell_count > 0
	water_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if shoreline_weight > 0.0:
		var center := shoreline_center / shoreline_weight
		_set_audio_position(Vector3(center.x, water_level + 0.4, center.y))
	else:
		var center := sector_bounds.get_center()
		_set_audio_position(Vector3(center.x, water_level + 0.4, center.y))


func _rebuild_water_area() -> void:
	for child in water_area.get_children():
		child.queue_free()
	water_collision_shape_count = 0
	if water_cell_count == 0:
		return

	var resolution := maxi(collision_resolution, 1)
	var cell_width := sector_bounds.size.x / float(resolution)
	var cell_depth := sector_bounds.size.y / float(resolution)
	for z_index in range(resolution):
		var run_start := -1
		for x_index in range(resolution + 1):
			var is_water_cell := false
			if x_index < resolution:
				is_water_cell = _is_ocean_zone_at_uv(Vector2(
					(float(x_index) + 0.5) / float(resolution),
					(float(z_index) + 0.5) / float(resolution)
				))
			if is_water_cell and run_start < 0:
				run_start = x_index
			elif not is_water_cell and run_start >= 0:
				_add_water_collision_run(run_start, x_index - 1, z_index, cell_width, cell_depth)
				run_start = -1


func _add_water_collision_run(run_start: int, run_end: int, z_index: int, cell_width: float, cell_depth: float) -> void:
	var run_width := run_end - run_start + 1
	if run_width <= 0:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(run_width) * cell_width, water_area_depth + 2.0, cell_depth)
	var collider := CollisionShape3D.new()
	collider.name = "WaterRun_%d_%d_%d" % [z_index, run_start, run_end]
	collider.shape = shape
	collider.position = Vector3(
		sector_bounds.position.x + (float(run_start) + float(run_width) * 0.5) * cell_width,
		water_level - water_area_depth * 0.5 + 1.0,
		sector_bounds.position.y + (float(z_index) + 0.5) * cell_depth
	)
	water_area.add_child(collider)
	water_collision_shape_count += 1


func _surface_kind_at_uv(uv: Vector2) -> int:
	if surface_image == null or surface_image.is_empty():
		return 0
	return _surface_kind_at_pixel(_pixel_at_uv(uv))


func _mask_shore_factor_at_uv(uv: Vector2) -> float:
	if surface_image == null or surface_image.is_empty():
		return 0.0
	var index := _pixel_index(_pixel_at_uv(uv))
	if index < 0 or index >= _shore_factor_mask.size():
		return 0.0
	return _shore_factor_mask[index]


func _is_ocean_zone_at_uv(uv: Vector2) -> bool:
	if surface_image == null or surface_image.is_empty():
		return false
	var index := _pixel_index(_pixel_at_uv(uv))
	return index >= 0 and index < _ocean_zone_mask.size() and _ocean_zone_mask[index] != 0


func _pixel_at_uv(uv: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(uv.x * float(surface_image.get_width())), 0, surface_image.get_width() - 1),
		clampi(int(uv.y * float(surface_image.get_height())), 0, surface_image.get_height() - 1)
	)


func _surface_kind_at_pixel(pixel: Vector2i) -> int:
	var color := surface_image.get_pixelv(pixel)
	if color.b > 0.45 and color.b > color.r * 2.0:
		return SURFACE_DEEP_WATER if color.g < 0.20 else SURFACE_WATER
	return 0


func _pixel_index(pixel: Vector2i) -> int:
	if surface_image == null or surface_image.is_empty():
		return -1
	return pixel.y * surface_image.get_width() + pixel.x


func _rebuild_spatial_masks() -> void:
	var width := surface_image.get_width()
	var height := surface_image.get_height()
	var total := width * height
	_ocean_zone_mask.resize(total)
	_shore_factor_mask.resize(total)
	var distance_to_water := _build_distance_field(true)
	var distance_to_land := _build_distance_field(false)
	var overlap_limit := maxi(coast_overlap_pixels, 1) * 10
	var foam_limit := maxi(foam_search_pixels, 1) * 10
	for index in range(total):
		_ocean_zone_mask[index] = 1 if distance_to_water[index] <= overlap_limit else 0
		_shore_factor_mask[index] = clampf(
			1.0 - float(distance_to_land[index]) / float(foam_limit),
			0.0,
			1.0
		)


func _build_distance_field(target_is_water: bool) -> PackedInt32Array:
	var width := surface_image.get_width()
	var height := surface_image.get_height()
	var distance := PackedInt32Array()
	distance.resize(width * height)
	distance.fill(1_000_000)
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			var is_water_pixel := _is_water(_surface_kind_at_pixel(Vector2i(x, y)))
			if is_water_pixel == target_is_water:
				distance[index] = 0
				continue
			if x > 0:
				distance[index] = mini(distance[index], distance[index - 1] + 10)
			if y > 0:
				distance[index] = mini(distance[index], distance[index - width] + 10)
				if x > 0:
					distance[index] = mini(distance[index], distance[index - width - 1] + 14)
				if x + 1 < width:
					distance[index] = mini(distance[index], distance[index - width + 1] + 14)
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var index := y * width + x
			if x + 1 < width:
				distance[index] = mini(distance[index], distance[index + 1] + 10)
			if y + 1 < height:
				distance[index] = mini(distance[index], distance[index + width] + 10)
				if x > 0:
					distance[index] = mini(distance[index], distance[index + width - 1] + 14)
				if x + 1 < width:
					distance[index] = mini(distance[index], distance[index + width + 1] + 14)
	return distance


func _terrain_height_at(x: float, z: float) -> float:
	if _terrain == null or not ("data" in _terrain) or _terrain.data == null:
		return NAN
	return float(_terrain.data.get_height(Vector3(x, 0.0, z)))


func _terrain_shore_factor(depth: float) -> float:
	return clampf(1.0 - maxf(depth, 0.0) / maxf(foam_depth_meters, 0.01), 0.0, 1.0)


func _visual_shore_factor(uv: Vector2, x: float, z: float) -> float:
	var terrain_height := _terrain_height_at(x, z)
	if not is_nan(terrain_height):
		return _terrain_shore_factor(water_level - terrain_height)
	return _mask_shore_factor_at_uv(uv)


func _vertex_color(uv: Vector2, x: float, z: float) -> Color:
	var surface_kind := _surface_kind_at_uv(uv)
	var terrain_height := _terrain_height_at(x, z)
	var shore_factor := 0.0
	var depth_factor := 1.0 if surface_kind == SURFACE_DEEP_WATER else 0.0
	if not is_nan(terrain_height):
		var depth := water_level - terrain_height
		shore_factor = _terrain_shore_factor(depth)
		depth_factor = maxf(depth_factor, clampf((depth - 0.65) / 4.0, 0.0, 1.0))
	else:
		shore_factor = _mask_shore_factor_at_uv(uv)
	return Color(depth_factor, shore_factor, 0.0, 1.0)


func _is_water(surface_kind: int) -> bool:
	return surface_kind == SURFACE_WATER or surface_kind == SURFACE_DEEP_WATER


func _set_audio_position(next_position: Vector3) -> void:
	shore_loop.position = next_position
	shore_lapping.position = next_position
	wave_break.position = next_position
	var audible_distance := maxf(sector_bounds.size.x, sector_bounds.size.y) * 0.9
	shore_loop.max_distance = audible_distance
	shore_lapping.max_distance = audible_distance * 0.7
	wave_break.max_distance = audible_distance * 0.55


func _configure_audio() -> void:
	if Engine.is_editor_hint():
		return
	var has_water := water_cell_count > 0
	if not has_water:
		_stop_audio()
		return
	if not shore_loop.playing:
		shore_loop.play()
	if not shore_lapping.playing:
		shore_lapping.play(_rng.randf_range(0.0, 12.0))
	wave_timer.start(_rng.randf_range(7.0, 15.0))


func _restart_loop(player: AudioStreamPlayer3D) -> void:
	if water_cell_count > 0 and is_inside_tree():
		player.play()


func _play_random_wave() -> void:
	if water_cell_count <= 0:
		return
	wave_break.pitch_scale = _rng.randf_range(0.92, 1.08)
	wave_break.play()
	wave_timer.start(_rng.randf_range(8.0, 18.0))


func _stop_audio() -> void:
	shore_loop.stop()
	shore_lapping.stop()
	wave_break.stop()
	wave_timer.stop()


func _clear_water() -> void:
	water_cell_count = 0
	shoreline_cell_count = 0
	_ocean_zone_mask.clear()
	_shore_factor_mask.clear()
	water_surface.mesh = null
	water_surface.hide()
	_clear_water_area()
	_stop_audio()


func _clear_water_area() -> void:
	for child in water_area.get_children():
		child.queue_free()
	water_collision_shape_count = 0
