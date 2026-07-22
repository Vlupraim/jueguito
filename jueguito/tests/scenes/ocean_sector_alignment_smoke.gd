extends Node3D

const OCEAN_SCENE := preload("res://scenes/world/water/ocean_water.tscn")
const EXPORT_ROOT := "res://data/terrain3d_exports"
const SAMPLE_GRID := 18


func _ready() -> void:
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	call_deferred("_run")


func _run() -> void:
	for sector in [Vector2i(10, 6), Vector2i(15, 7)]:
		var result := await _check_sector(sector)
		if not bool(result.get("ok", false)):
			_fail(String(result.get("message", "Alineacion de oceano invalida")))
			return
		print(
			"OCEAN_SECTOR_ALIGNMENT sector=", sector,
			" agreement=", snappedf(float(result.get("agreement", 0.0)), 0.001),
			" water_samples=", int(result.get("water_samples", 0)),
			" land_samples=", int(result.get("land_samples", 0))
		)
	print("OCEAN_SECTOR_ALIGNMENT_SMOKE_OK west_and_east_coasts=true")
	get_tree().quit(0)


func _check_sector(sector: Vector2i) -> Dictionary:
	var export_dir := "%s/sector_%d_%d" % [EXPORT_ROOT, sector.x, sector.y]
	var height_path := ProjectSettings.globalize_path(export_dir + "/height.exr")
	var surface_path := ProjectSettings.globalize_path(export_dir + "/surface_reference.png")
	if not FileAccess.file_exists(height_path) or not FileAccess.file_exists(surface_path):
		return {"ok": false, "message": "Faltan exports para " + str(sector)}

	var terrain := Terrain3D.new()
	terrain.name = "AlignmentTerrain_%d_%d" % [sector.x, sector.y]
	add_child(terrain)
	var temp_data_dir := "res://.godot/ocean_alignment/%d_%d" % [sector.x, sector.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_data_dir))
	terrain.data_directory = temp_data_dir
	var images := [Terrain3DUtil.load_image(height_path, ResourceLoader.CACHE_MODE_IGNORE), null, null]
	terrain.data.import_images(images, Vector3.ZERO, 0.0, 1.0)
	await get_tree().process_frame

	var ocean := OCEAN_SCENE.instantiate() as OceanWater
	add_child(ocean)
	await get_tree().process_frame
	if not ocean.configure_for_sector(sector, terrain):
		return {"ok": false, "message": "El sector costero no genero agua: " + str(sector)}
	var expected_size := Vector2.ONE * 512.0
	if not ocean.sector_bounds.position.is_equal_approx(Vector2.ZERO) or not ocean.sector_bounds.size.is_equal_approx(expected_size):
		return {
			"ok": false,
			"message": "El footprint del oceano cambio con las regiones Terrain3D en " + str(sector),
		}

	var surface := Image.load_from_file(surface_path)
	var matching := 0
	var compared := 0
	var water_samples := 0
	var land_samples := 0
	for sample_z in range(SAMPLE_GRID):
		for sample_x in range(SAMPLE_GRID):
			var uv := Vector2(
				(float(sample_x) + 0.5) / float(SAMPLE_GRID),
				(float(sample_z) + 0.5) / float(SAMPLE_GRID)
			)
			var pixel := Vector2i(
				clampi(int(uv.x * surface.get_width()), 0, surface.get_width() - 1),
				clampi(int(uv.y * surface.get_height()), 0, surface.get_height() - 1)
			)
			var color := surface.get_pixelv(pixel)
			var expected_water := color.b > 0.45 and color.b > color.r * 2.0
			var world := Vector3(
				lerpf(ocean.sector_bounds.position.x, ocean.sector_bounds.end.x, uv.x),
				0.0,
				lerpf(ocean.sector_bounds.position.y, ocean.sector_bounds.end.y, uv.y)
			)
			var terrain_height := terrain.data.get_height(world)
			if is_nan(terrain_height):
				continue
			var observed_water_height := terrain_height < ocean.water_level
			compared += 1
			water_samples += 1 if expected_water else 0
			land_samples += 0 if expected_water else 1
			if expected_water == observed_water_height:
				matching += 1

	var agreement := float(matching) / float(maxi(compared, 1))
	terrain.queue_free()
	ocean.queue_free()
	if water_samples == 0 or land_samples == 0:
		return {"ok": false, "message": "El sector no contiene ambas superficies: " + str(sector)}
	if agreement < 0.78:
		return {
			"ok": false,
			"message": "Mascara MMO y Terrain3D desalineados en %s (%.1f%%)" % [sector, agreement * 100.0],
		}
	return {
		"ok": true,
		"agreement": agreement,
		"water_samples": water_samples,
		"land_samples": land_samples,
	}


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
