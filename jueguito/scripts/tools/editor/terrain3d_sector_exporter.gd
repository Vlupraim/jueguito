@tool
extends RefCounted

const SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const SECTOR_OVERRIDES_PATH := "res://data/terrain3d_sector_overrides.json"
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const MAP_IMAGE_SIZE := Vector2i(1672, 941)
const SECTOR_SIDE_METERS := 5000.0
const METERS_PER_PIXEL := 200.0
const SECTOR_PIXELS := 25
const EXPORT_RESOLUTION := 512  # multiplo de region_size (256) -> sector = 2x2 regiones limpias
const AUTO_BEACH_RADIUS_PIXELS := 4
const WATER_SHORE_RADIUS_PIXELS := 9
const UNKNOWN_SURFACE_SEARCH_RADIUS_PIXELS := 4
const SECTOR_EDGE_BLEND_RATIO := 0.10

const SURFACE_UNKNOWN := 0
const SURFACE_LAND := 1
const SURFACE_WATER := 2
const SURFACE_COAST := 3
const SURFACE_DEEP_WATER := 4

const TEXTURE_DRY_EARTH := 0
const TEXTURE_SAND := 1
const TEXTURE_GRASS := 2
const TEXTURE_HUMID_EARTH := 3
const TEXTURE_ROCK := 4
const TEXTURE_ARCANE := 5
const TEXTURE_SNOW := 6
const TEXTURE_SWAMP := 7

const ROCK_SLOPE_START_DEGREES := 28.0
const ROCK_SLOPE_FULL_DEGREES := 54.0
const MOUNTAIN_ROCK_SLOPE_START_DEGREES := 14.0
const MOUNTAIN_ROCK_SLOPE_FULL_DEGREES := 36.0
const MOUNTAIN_ROCK_HEIGHT_START_METERS := 24.0
const MOUNTAIN_ROCK_HEIGHT_FULL_METERS := 52.0
const MOUNTAIN_ROCK_HEIGHT_MAX_BLEND := 0.55
const SNOW_HEIGHT_START_METERS := 72.0
const SNOW_HEIGHT_FULL_METERS := 112.0

var sector_data: Dictionary = {}
var sector_overrides: Dictionary = {}
var sector_overrides_loaded := false
var surface_image: Image
var height_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var active_sector := Vector2i.ZERO
var active_surface_override_id := -1
var shore_influence_cache: Dictionary = {}


func export_sector(sector: Vector2i, use_biomes := true) -> Dictionary:
	active_sector = sector
	var load_error := _ensure_loaded()
	if not load_error.is_empty():
		return {"ok": false, "message": load_error}
	if not _sector_exists(sector):
		return {"ok": false, "message": "No existe data para el sector " + _sector_label(sector) + "."}

	_setup_noises(sector)
	shore_influence_cache.clear()
	var export_resource_dir := _terrain3d_export_resource_dir(sector)
	var export_absolute_dir := ProjectSettings.globalize_path(export_resource_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(export_absolute_dir)
	if dir_error != OK:
		return {"ok": false, "message": "No pude crear carpeta de export Terrain3D."}

	var sector_rect := _sector_pixel_rect(sector)
	var sector_dict := _get_sector_dict(sector)
	var override := _get_sector_override(sector)
	var source_biome_id := int(sector_dict.get("biome_id", 0))
	var override_biome_id := int(override.get("biome_id", -1))
	var source_surface_id := int(sector_dict.get("dominant_surface_id", SURFACE_UNKNOWN))
	var override_surface_id := int(override.get("surface_id", -1))
	var effective_source_biome_id := override_biome_id if override_biome_id >= 0 else source_biome_id
	var biome_id := _effective_biome_id(effective_source_biome_id, use_biomes)
	active_surface_override_id = override_surface_id
	var resolution := EXPORT_RESOLUTION
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	var surface_ids := PackedInt32Array()
	surface_ids.resize(resolution * resolution)
	var min_height := INF
	var max_height := -INF
	var surface_reference := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)

	for y_index in range(resolution):
		var z_ratio := float(y_index) / float(resolution - 1)
		for x_index in range(resolution):
			var x_ratio := float(x_index) / float(resolution - 1)
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			var height := _height_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)
			var index := y_index * resolution + x_index
			heights[index] = height
			surface_ids[index] = surface_id
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
			surface_reference.set_pixel(x_index, y_index, _editor_minimap_color(surface_id, biome_id))

	var control_result := _create_texture_control_maps(heights, surface_ids, resolution, biome_id)
	var control_image: Image = control_result.get("control", null)
	var control_preview: Image = control_result.get("preview", null)

	var height_image := Image.create(resolution, resolution, false, Image.FORMAT_RF)
	var height_preview := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var height_span := maxf(0.001, max_height - min_height)
	for y_index in range(resolution):
		for x_index in range(resolution):
			var index := y_index * resolution + x_index
			var height := heights[index]
			height_image.set_pixel(x_index, y_index, Color(height, 0.0, 0.0, 1.0))
			var preview_value := clampf((height - min_height) / height_span, 0.0, 1.0)
			height_preview.set_pixel(x_index, y_index, Color(preview_value, preview_value, preview_value, 1.0))

	var height_path := export_absolute_dir.path_join("height.exr")
	var preview_path := export_absolute_dir.path_join("height_preview.png")
	var surface_path := export_absolute_dir.path_join("surface_reference.png")
	var control_path := export_absolute_dir.path_join("control.exr")
	var control_preview_path := export_absolute_dir.path_join("control_preview.png")
	var metadata_path := export_absolute_dir.path_join("metadata.json")
	var height_error := height_image.save_exr(height_path, true)
	var preview_error := height_preview.save_png(preview_path)
	var surface_error := surface_reference.save_png(surface_path)
	var control_error := control_image.save_exr(control_path, false)
	var control_preview_error := control_preview.save_png(control_preview_path)
	if height_error != OK or preview_error != OK or surface_error != OK or control_error != OK or control_preview_error != OK:
		return {"ok": false, "message": "Export incompleto: revise permisos o soporte EXR."}

	var metadata := {
		"version": 1,
		"source": "terrain3d_sector_exporter",
		"sector": [sector.x, sector.y],
		"sector_side_meters": SECTOR_SIDE_METERS,
		"meters_per_source_pixel": METERS_PER_PIXEL,
		"export_resolution": resolution,
		"meters_per_export_pixel": SECTOR_SIDE_METERS / float(resolution - 1),
		"use_biomes": use_biomes,
		"source_biome_id": source_biome_id,
		"source_biome": str(sector_dict.get("biome", "Sin bioma")),
		"source_surface_id": source_surface_id,
		"source_surface": str(sector_dict.get("dominant_surface", "unknown")),
		"override_biome_id": override_biome_id,
		"override_surface_id": override_surface_id,
		"effective_source_biome_id": effective_source_biome_id,
		"effective_biome_id": biome_id,
		"height_min": min_height,
		"height_max": max_height,
		"height_units": "meters",
		"heightmap": "height.exr",
		"height_preview": "height_preview.png",
		"surface_reference": "surface_reference.png",
		"controlmap": "control.exr",
		"control_preview": "control_preview.png",
		"texture_convention": _texture_convention(),
		"terrain3d_note": "Importa height.exr como base de altura. Usa sector_side_meters como escala horizontal y esta metadata para recordar el rango vertical.",
	}
	var metadata_file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file == null:
		return {"ok": false, "message": "Export listo, pero no pude escribir metadata.json."}
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	return {
		"ok": true,
		"message": "Export listo: " + export_resource_dir,
		"resource_dir": export_resource_dir,
		"height_path": height_path,
		"control_path": control_path,
		"height_min": min_height,
		"height_max": max_height,
	}


func export_sector_async(sector: Vector2i, progress_callback: Callable = Callable(), use_biomes := true) -> Dictionary:
	active_sector = sector
	_notify_progress(progress_callback, 0.01, "Leyendo capas del mapa...")
	await _wait_frame()

	var load_error := _ensure_loaded()
	if not load_error.is_empty():
		return {"ok": false, "message": load_error}
	if not _sector_exists(sector):
		return {"ok": false, "message": "No existe data para el sector " + _sector_label(sector) + "."}

	_setup_noises(sector)
	shore_influence_cache.clear()
	var export_resource_dir := _terrain3d_export_resource_dir(sector)
	var export_absolute_dir := ProjectSettings.globalize_path(export_resource_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(export_absolute_dir)
	if dir_error != OK:
		return {"ok": false, "message": "No pude crear carpeta de export Terrain3D."}

	var sector_rect := _sector_pixel_rect(sector)
	var sector_dict := _get_sector_dict(sector)
	var override := _get_sector_override(sector)
	var source_biome_id := int(sector_dict.get("biome_id", 0))
	var override_biome_id := int(override.get("biome_id", -1))
	var source_surface_id := int(sector_dict.get("dominant_surface_id", SURFACE_UNKNOWN))
	var override_surface_id := int(override.get("surface_id", -1))
	var effective_source_biome_id := override_biome_id if override_biome_id >= 0 else source_biome_id
	var biome_id := _effective_biome_id(effective_source_biome_id, use_biomes)
	active_surface_override_id = override_surface_id
	var resolution := EXPORT_RESOLUTION
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	var surface_ids := PackedInt32Array()
	surface_ids.resize(resolution * resolution)
	var min_height := INF
	var max_height := -INF
	var surface_reference := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)

	for y_index in range(resolution):
		var z_ratio := float(y_index) / float(resolution - 1)
		for x_index in range(resolution):
			var x_ratio := float(x_index) / float(resolution - 1)
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			var height := _height_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)
			var index := y_index * resolution + x_index
			heights[index] = height
			surface_ids[index] = surface_id
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
			surface_reference.set_pixel(x_index, y_index, _editor_minimap_color(surface_id, biome_id))
		if y_index % 16 == 0:
			_notify_progress(progress_callback, 0.05 + 0.55 * float(y_index) / float(resolution - 1), "Calculando altura " + str(y_index + 1) + "/" + str(resolution))
			await _wait_frame()

	_notify_progress(progress_callback, 0.60, "Calculando textura base...")
	await _wait_frame()
	var control_result := _create_texture_control_maps(heights, surface_ids, resolution, biome_id)
	var control_image: Image = control_result.get("control", null)
	var control_preview: Image = control_result.get("preview", null)

	var height_image := Image.create(resolution, resolution, false, Image.FORMAT_RF)
	var height_preview := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var height_span := maxf(0.001, max_height - min_height)
	for y_index in range(resolution):
		for x_index in range(resolution):
			var index := y_index * resolution + x_index
			var height := heights[index]
			height_image.set_pixel(x_index, y_index, Color(height, 0.0, 0.0, 1.0))
			var preview_value := clampf((height - min_height) / height_span, 0.0, 1.0)
			height_preview.set_pixel(x_index, y_index, Color(preview_value, preview_value, preview_value, 1.0))
		if y_index % 24 == 0:
			_notify_progress(progress_callback, 0.62 + 0.25 * float(y_index) / float(resolution - 1), "Preparando heightmap " + str(y_index + 1) + "/" + str(resolution))
			await _wait_frame()

	_notify_progress(progress_callback, 0.90, "Guardando EXR y previews...")
	await _wait_frame()

	var height_path := export_absolute_dir.path_join("height.exr")
	var preview_path := export_absolute_dir.path_join("height_preview.png")
	var surface_path := export_absolute_dir.path_join("surface_reference.png")
	var control_path := export_absolute_dir.path_join("control.exr")
	var control_preview_path := export_absolute_dir.path_join("control_preview.png")
	var metadata_path := export_absolute_dir.path_join("metadata.json")
	var height_error := height_image.save_exr(height_path, true)
	var preview_error := height_preview.save_png(preview_path)
	var surface_error := surface_reference.save_png(surface_path)
	var control_error := control_image.save_exr(control_path, false)
	var control_preview_error := control_preview.save_png(control_preview_path)
	if height_error != OK or preview_error != OK or surface_error != OK or control_error != OK or control_preview_error != OK:
		return {"ok": false, "message": "Export incompleto: revise permisos o soporte EXR."}

	var metadata := {
		"version": 1,
		"source": "terrain3d_sector_exporter",
		"sector": [sector.x, sector.y],
		"sector_side_meters": SECTOR_SIDE_METERS,
		"meters_per_source_pixel": METERS_PER_PIXEL,
		"export_resolution": resolution,
		"meters_per_export_pixel": SECTOR_SIDE_METERS / float(resolution - 1),
		"use_biomes": use_biomes,
		"source_biome_id": source_biome_id,
		"source_biome": str(sector_dict.get("biome", "Sin bioma")),
		"source_surface_id": source_surface_id,
		"source_surface": str(sector_dict.get("dominant_surface", "unknown")),
		"override_biome_id": override_biome_id,
		"override_surface_id": override_surface_id,
		"effective_source_biome_id": effective_source_biome_id,
		"effective_biome_id": biome_id,
		"height_min": min_height,
		"height_max": max_height,
		"height_units": "meters",
		"heightmap": "height.exr",
		"height_preview": "height_preview.png",
		"surface_reference": "surface_reference.png",
		"controlmap": "control.exr",
		"control_preview": "control_preview.png",
		"texture_convention": _texture_convention(),
		"terrain3d_note": "Importa height.exr como base de altura. Usa sector_side_meters como escala horizontal y esta metadata para recordar el rango vertical.",
	}
	var metadata_file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file == null:
		return {"ok": false, "message": "Export listo, pero no pude escribir metadata.json."}
	metadata_file.store_string(JSON.stringify(metadata, "\t"))

	_notify_progress(progress_callback, 1.0, "Export listo.")
	return {
		"ok": true,
		"message": "Export listo: " + export_resource_dir,
		"resource_dir": export_resource_dir,
		"height_path": height_path,
		"control_path": control_path,
		"height_min": min_height,
		"height_max": max_height,
	}
func _ensure_loaded() -> String:
	if sector_data.is_empty():
		var data_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SECTOR_DATA_PATH))
		if data_text.is_empty():
			return "No pude leer " + SECTOR_DATA_PATH + "."
		var parsed: Variant = JSON.parse_string(data_text)
		if not (parsed is Dictionary):
			return "El archivo de sectores no es JSON valido."
		sector_data = parsed as Dictionary

	if not sector_overrides_loaded:
		sector_overrides_loaded = true
		var overrides_path := ProjectSettings.globalize_path(SECTOR_OVERRIDES_PATH)
		if FileAccess.file_exists(overrides_path):
			var overrides_text := FileAccess.get_file_as_string(overrides_path)
			var parsed_overrides: Variant = JSON.parse_string(overrides_text)
			if parsed_overrides is Dictionary:
				sector_overrides = parsed_overrides as Dictionary

	if surface_image == null:
		surface_image = Image.new()
		var error := surface_image.load(ProjectSettings.globalize_path(SURFACE_MASK_PATH))
		if error != OK:
			return "No pude cargar " + SURFACE_MASK_PATH + "."
		surface_image.convert(Image.FORMAT_RGBA8)
	return ""


func _setup_noises(sector: Vector2i) -> void:
	var seed_base := sector.x * 73856093 + sector.y * 19349663 + 311
	height_noise = FastNoiseLite.new()
	height_noise.seed = seed_base
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency = 0.00058

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = seed_base + 913
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.0032


func _effective_biome_id(source_biome_id: int, use_biomes: bool) -> int:
	if use_biomes:
		return source_biome_id
	return 1


func _height_at_ratio(x_ratio: float, z_ratio: float, sector_rect: Rect2i, biome_id: int) -> float:
	var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
	var shore_influence := _shore_influence(x_ratio, z_ratio, sector_rect, surface_id)
	var edge_falloff := _sector_edge_falloff(x_ratio, z_ratio)
	return _height_for(x_ratio, z_ratio, surface_id, biome_id, shore_influence, edge_falloff)


func _height_for(
	x_ratio: float,
	z_ratio: float,
	surface_id: int,
	biome_id: int,
	shore_influence: float,
	edge_falloff: float
) -> float:
	var noise_x := float(active_sector.x) * SECTOR_SIDE_METERS + x_ratio * SECTOR_SIDE_METERS
	var noise_z := float(active_sector.y) * SECTOR_SIDE_METERS + z_ratio * SECTOR_SIDE_METERS
	var broad := height_noise.get_noise_2d(noise_x, noise_z)
	var detail := detail_noise.get_noise_2d(noise_x, noise_z)
	var base_height := 6.5
	var biome_height := 16.0
	var detail_height := 1.3
	match biome_id:
		2:
			base_height = 4.5
			biome_height = 9.0
			detail_height = 0.9
		3:
			base_height = 7.5
			biome_height = 22.0
			detail_height = 1.6
		4:
			base_height = 10.0
			biome_height = 30.0
			detail_height = 1.8
		5:
			base_height = 16.0
			biome_height = 36.0
			detail_height = 1.8
		6:
			base_height = 3.5
			biome_height = 6.0
			detail_height = 0.8
		7:
			base_height = 11.0
			biome_height = 38.0
			detail_height = 2.0

	if surface_id == SURFACE_DEEP_WATER:
		var deep_floor := -10.0 + detail * 1.0
		var shallow_floor := 0.8 + broad * 1.2 + detail * 0.6
		return lerpf(deep_floor, shallow_floor, shore_influence)
	if surface_id == SURFACE_WATER:
		var open_water_floor := -4.0 + detail * 0.7
		var near_shore_floor := 1.4 + broad * 1.0 + detail * 0.5
		return lerpf(open_water_floor, near_shore_floor, shore_influence)
	if surface_id == SURFACE_COAST:
		return 5.0 + broad * 3.5 + detail * 1.1
	if surface_id == SURFACE_LAND:
		var broad_lift := maxf(0.0, broad + 0.12)
		if biome_id == 5:
			broad_lift = _smooth01(clampf((broad + 0.24) * 0.55, 0.0, 1.0))
		var land_height := base_height + broad_lift * biome_height + detail * detail_height
		var beach_strength := _beach_strength(surface_id, shore_influence)
		if beach_strength > 0.0:
			var beach_height := 6.0 + broad * 3.0 + detail * 1.0
			land_height = lerpf(land_height, beach_height, beach_strength)

		if edge_falloff < 1.0:
			var edge_cap := 34.0 + maxf(0.0, broad + 0.2) * 30.0 + detail * 2.0
			if land_height > edge_cap:
				land_height = lerpf(edge_cap, land_height, edge_falloff)
		return land_height
	if surface_id == SURFACE_UNKNOWN:
		return 3.0 + broad * 2.0 + detail
	return 0.0


func _editor_minimap_color(surface_id: int, biome_id: int) -> Color:
	match surface_id:
		SURFACE_DEEP_WATER:
			return Color(0.03, 0.10, 0.30, 1.0)
		SURFACE_WATER:
			return Color(0.08, 0.32, 0.62, 1.0)
		SURFACE_COAST:
			return Color(0.83, 0.72, 0.46, 1.0)
		SURFACE_LAND:
			match biome_id:
				2:
					return Color(0.69, 0.56, 0.30, 1.0)
				3:
					return Color(0.09, 0.37, 0.20, 1.0)
				4:
					return Color(0.76, 0.86, 0.88, 1.0)
				5:
					return Color(0.41, 0.39, 0.34, 1.0)
				6:
					return Color(0.22, 0.32, 0.20, 1.0)
				7:
					return Color(0.42, 0.25, 0.48, 1.0)
				_:
					return Color(0.28, 0.52, 0.25, 1.0)
		_:
			return Color(0.42, 0.42, 0.39, 1.0)


func _create_texture_control_maps(heights: PackedFloat32Array, surface_ids: PackedInt32Array, resolution: int, biome_id: int) -> Dictionary:
	var control_bytes := PackedByteArray()
	control_bytes.resize(resolution * resolution * 4)
	var preview := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	for y_index in range(resolution):
		for x_index in range(resolution):
			var index := y_index * resolution + x_index
			var height := heights[index]
			var surface_id := surface_ids[index]
			var base_id := _base_texture_id(surface_id, biome_id)
			var overlay_id := base_id
			var blend := 0
			var navigation := surface_id == SURFACE_LAND or surface_id == SURFACE_COAST

			if surface_id == SURFACE_LAND:
				var slope_degrees := _slope_degrees_at(heights, resolution, x_index, y_index)
				var rock_start := ROCK_SLOPE_START_DEGREES
				var rock_full := ROCK_SLOPE_FULL_DEGREES
				if biome_id == 5:
					rock_start = MOUNTAIN_ROCK_SLOPE_START_DEGREES
					rock_full = MOUNTAIN_ROCK_SLOPE_FULL_DEGREES
				var rock_blend_value := _smooth_range(slope_degrees, rock_start, rock_full)
				if biome_id == 5:
					var height_rock := _smooth_range(height, MOUNTAIN_ROCK_HEIGHT_START_METERS, MOUNTAIN_ROCK_HEIGHT_FULL_METERS)
					rock_blend_value = maxf(rock_blend_value, height_rock * MOUNTAIN_ROCK_HEIGHT_MAX_BLEND)
				var rock_blend := int(round(rock_blend_value * 255.0))
				var snow_blend := 0
				if biome_id == 4:
					snow_blend = int(round(_smooth_range(height, SNOW_HEIGHT_START_METERS, SNOW_HEIGHT_FULL_METERS) * 255.0))
				if snow_blend > 0 and slope_degrees < rock_full:
					overlay_id = TEXTURE_SNOW
					blend = snow_blend
				if rock_blend > blend:
					overlay_id = TEXTURE_ROCK
					blend = rock_blend

			var packed_control := _pack_control_pixel(base_id, overlay_id, blend, 0, 0, false, navigation, false)
			control_bytes.encode_u32(index * 4, packed_control)
			preview.set_pixel(x_index, y_index, _control_preview_color(base_id, overlay_id, blend))
	var control := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, control_bytes)
	return {"control": control, "preview": preview}


func _base_texture_id(surface_id: int, biome_id: int) -> int:
	if surface_id == SURFACE_COAST or surface_id == SURFACE_WATER or surface_id == SURFACE_DEEP_WATER:
		return TEXTURE_SAND
	match biome_id:
		2:
			return TEXTURE_DRY_EARTH
		3:
			return TEXTURE_HUMID_EARTH
		4:
			return TEXTURE_SNOW
		5:
			return TEXTURE_GRASS
		6:
			return TEXTURE_SWAMP
		7:
			return TEXTURE_ARCANE
		_:
			return TEXTURE_GRASS


func _slope_degrees_at(heights: PackedFloat32Array, resolution: int, x_index: int, y_index: int) -> float:
	var left := heights[y_index * resolution + maxi(0, x_index - 1)]
	var right := heights[y_index * resolution + mini(resolution - 1, x_index + 1)]
	var down := heights[maxi(0, y_index - 1) * resolution + x_index]
	var up := heights[mini(resolution - 1, y_index + 1) * resolution + x_index]
	var meters_per_pixel := SECTOR_SIDE_METERS / float(resolution - 1)
	var dx := (right - left) / maxf(0.001, meters_per_pixel * 2.0)
	var dz := (up - down) / maxf(0.001, meters_per_pixel * 2.0)
	var slope := sqrt(dx * dx + dz * dz)
	return rad_to_deg(atan(slope))


func _smooth_range(value: float, start: float, end: float) -> float:
	if is_equal_approx(start, end):
		return 1.0 if value >= end else 0.0
	return _smooth01(clampf((value - start) / (end - start), 0.0, 1.0))


func _pack_control_pixel(
	base_id: int,
	overlay_id: int,
	blend: int,
	angle: int,
	scale: int,
	hole: bool,
	navigation: bool,
	autoshader: bool
) -> int:
	var packed := 0
	packed |= (base_id & 0x1F) << 27
	packed |= (overlay_id & 0x1F) << 22
	packed |= (blend & 0xFF) << 14
	packed |= (angle & 0xF) << 10
	packed |= (scale & 0x7) << 7
	packed |= (1 if hole else 0) << 2
	packed |= (1 if navigation else 0) << 1
	packed |= 1 if autoshader else 0
	return packed


func _control_preview_color(base_id: int, overlay_id: int, blend: int) -> Color:
	var base_color := _texture_preview_color(base_id)
	if blend <= 0:
		return base_color
	return base_color.lerp(_texture_preview_color(overlay_id), clampf(float(blend) / 255.0, 0.0, 1.0))


func _texture_preview_color(texture_id: int) -> Color:
	match texture_id:
		TEXTURE_ROCK:
			return Color(0.34, 0.34, 0.32, 1.0)
		TEXTURE_GRASS:
			return Color(0.30, 0.58, 0.25, 1.0)
		TEXTURE_SAND:
			return Color(0.82, 0.72, 0.45, 1.0)
		TEXTURE_SNOW:
			return Color(0.86, 0.91, 0.92, 1.0)
		TEXTURE_SWAMP:
			return Color(0.22, 0.31, 0.20, 1.0)
		TEXTURE_DRY_EARTH:
			return Color(0.58, 0.43, 0.25, 1.0)
		TEXTURE_HUMID_EARTH:
			return Color(0.18, 0.42, 0.26, 1.0)
		TEXTURE_ARCANE:
			return Color(0.42, 0.24, 0.50, 1.0)
		_:
			return Color(0.45, 0.45, 0.42, 1.0)


func _texture_convention() -> Dictionary:
	return {
		"0": "tierra seca / desierto",
		"1": "arena / costa / fondo bajo",
		"2": "pasto / pradera",
		"3": "tierra humeda / selva",
		"4": "roca / acantilado",
		"5": "roca secundaria / arcano provisional",
		"6": "nieve",
		"7": "barro / pantano",
	}


func _sample_surface_id(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> int:
	if active_surface_override_id >= SURFACE_LAND and active_surface_override_id <= SURFACE_DEEP_WATER:
		return active_surface_override_id
	var pixel := _surface_pixel_from_ratio(x_ratio, z_ratio, sector_rect)
	var surface_id := _surface_id_at_pixel(pixel.x, pixel.y)
	if surface_id != SURFACE_UNKNOWN:
		return surface_id
	return _nearest_defined_surface_id(pixel, UNKNOWN_SURFACE_SEARCH_RADIUS_PIXELS)


func _surface_pixel_from_ratio(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> Vector2i:
	var clamped_x := clampf(x_ratio, 0.0, 0.9999)
	var clamped_z := clampf(z_ratio, 0.0, 0.9999)
	var pixel_x := sector_rect.position.x + int(clamped_x * float(maxi(1, sector_rect.size.x)))
	var pixel_y := sector_rect.position.y + int(clamped_z * float(maxi(1, sector_rect.size.y)))
	pixel_x = clampi(pixel_x, 0, surface_image.get_width() - 1)
	pixel_y = clampi(pixel_y, 0, surface_image.get_height() - 1)
	return Vector2i(pixel_x, pixel_y)


func _shore_influence(x_ratio: float, z_ratio: float, sector_rect: Rect2i, surface_id: int) -> float:
	if surface_id == SURFACE_COAST:
		return 1.0

	var pixel := _surface_pixel_from_ratio(x_ratio, z_ratio, sector_rect)
	var cache_key := surface_id * surface_image.get_width() * surface_image.get_height() + pixel.y * surface_image.get_width() + pixel.x
	if shore_influence_cache.has(cache_key):
		return float(shore_influence_cache[cache_key])

	var search_radius := WATER_SHORE_RADIUS_PIXELS if surface_id == SURFACE_WATER or surface_id == SURFACE_DEEP_WATER else AUTO_BEACH_RADIUS_PIXELS
	var nearest := search_radius + 1
	for y_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			var distance := maxi(absi(x_offset), absi(y_offset))
			if distance <= 0 or distance >= nearest:
				continue
			var sample_x := clampi(pixel.x + x_offset, 0, surface_image.get_width() - 1)
			var sample_y := clampi(pixel.y + y_offset, 0, surface_image.get_height() - 1)
			var sample_id := _surface_id_at_pixel(sample_x, sample_y)
			if _is_shore_target(surface_id, sample_id):
				nearest = distance

	if nearest > search_radius:
		shore_influence_cache[cache_key] = 0.0
		return 0.0
	var raw := 1.0 - float(nearest - 1) / float(search_radius)
	var influence := _smooth01(raw)
	shore_influence_cache[cache_key] = influence
	return influence


func _is_shore_target(origin_surface_id: int, sample_surface_id: int) -> bool:
	if origin_surface_id == SURFACE_WATER or origin_surface_id == SURFACE_DEEP_WATER:
		return sample_surface_id == SURFACE_LAND or sample_surface_id == SURFACE_COAST
	return sample_surface_id == SURFACE_WATER or sample_surface_id == SURFACE_DEEP_WATER or sample_surface_id == SURFACE_COAST


func _nearest_defined_surface_id(pixel: Vector2i, search_radius: int) -> int:
	var best_surface := SURFACE_UNKNOWN
	var best_distance := INF
	for y_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			var sample_x := clampi(pixel.x + x_offset, 0, surface_image.get_width() - 1)
			var sample_y := clampi(pixel.y + y_offset, 0, surface_image.get_height() - 1)
			var surface_id := _surface_id_at_pixel(sample_x, sample_y)
			if surface_id == SURFACE_UNKNOWN:
				continue
			var distance := Vector2(float(x_offset), float(y_offset)).length_squared()
			if distance < best_distance:
				best_distance = distance
				best_surface = surface_id
	return best_surface


func _beach_strength(surface_id: int, shore_influence: float) -> float:
	if surface_id == SURFACE_COAST:
		return 1.0
	if surface_id == SURFACE_LAND:
		return clampf(shore_influence, 0.0, 1.0)
	return 0.0


func _sector_edge_falloff(x_ratio: float, z_ratio: float) -> float:
	var edge_distance := minf(minf(x_ratio, 1.0 - x_ratio), minf(z_ratio, 1.0 - z_ratio))
	return _smooth01(edge_distance / SECTOR_EDGE_BLEND_RATIO)


func _smooth01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _surface_id_at_pixel(pixel_x: int, pixel_y: int) -> int:
	return _surface_id_from_color(surface_image.get_pixel(pixel_x, pixel_y))


func _surface_id_from_color(color: Color) -> int:
	if color.a <= 0.05:
		return SURFACE_UNKNOWN
	if color.r > 0.70 and color.g > 0.50 and color.b < 0.50:
		return SURFACE_COAST
	if color.g > color.r * 1.7 and color.g > color.b * 0.70 and color.r < 0.40:
		return SURFACE_LAND
	if color.b > 0.35 and color.r < 0.08 and color.g < 0.20:
		return SURFACE_DEEP_WATER
	if color.b > 0.35 and color.r < 0.28 and color.g > 0.15:
		return SURFACE_WATER
	return SURFACE_UNKNOWN


func _sector_pixel_rect(sector: Vector2i) -> Rect2i:
	var x_start := sector.x * SECTOR_PIXELS
	var y_start := sector.y * SECTOR_PIXELS
	var x_end := mini(x_start + SECTOR_PIXELS, MAP_IMAGE_SIZE.x)
	var y_end := mini(y_start + SECTOR_PIXELS, MAP_IMAGE_SIZE.y)
	return Rect2i(Vector2i(x_start, y_start), Vector2i(maxi(1, x_end - x_start), maxi(1, y_end - y_start)))


func _get_sector_dict(sector: Vector2i) -> Dictionary:
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		return {}
	var sectors: Dictionary = sectors_value as Dictionary
	var value: Variant = sectors.get(_sector_key(sector), {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_sector_override(sector: Vector2i) -> Dictionary:
	var sectors_value: Variant = sector_overrides.get("sectors", {})
	if not (sectors_value is Dictionary):
		return {}
	var sectors: Dictionary = sectors_value as Dictionary
	var value: Variant = sectors.get(_sector_key(sector), {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _sector_exists(sector: Vector2i) -> bool:
	return not _get_sector_dict(sector).is_empty()


func _terrain3d_export_resource_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EXPORT_DIR + "/sector_" + str(sector.x) + "_" + str(sector.y)


func _sector_key(sector: Vector2i) -> String:
	return str(sector.x) + "," + str(sector.y)


func _sector_label(sector: Vector2i) -> String:
	return "[" + str(sector.x) + ", " + str(sector.y) + "]"


func _notify_progress(progress_callback: Callable, progress: float, message: String) -> void:
	if progress_callback.is_valid():
		progress_callback.call(clampf(progress, 0.0, 1.0), message)


func _wait_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
