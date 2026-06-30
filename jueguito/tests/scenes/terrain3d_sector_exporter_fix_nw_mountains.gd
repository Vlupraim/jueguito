extends SceneTree

const EXPORT_ROOT := "res://data/terrain3d_exports"
const MIN_X := 9
const MAX_X := 15
const MIN_Y := 10
const MAX_Y := 13
const HEIGHT_FIX_THRESHOLD := 100.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var exporter_script := load("res://scripts/tools/editor/terrain3d_sector_exporter.gd") as Script
	var exporter: RefCounted = exporter_script.new()
	var sectors := _sectors_to_fix()
	if sectors.is_empty():
		print("NW_MOUNTAIN_FIX= no hay sectores altos para reexportar.")
		quit(0)
		return

	var fixed_count := 0
	for sector in sectors:
		var result: Dictionary = await exporter.call("export_sector_async", sector, Callable())
		print("NW_MOUNTAIN_FIX=", sector, result)
		if not bool(result.get("ok", false)):
			push_error("No pude reexportar " + str(sector))
			quit(1)
			return
		fixed_count += 1

	print("NW_MOUNTAIN_FIX_COUNT=", fixed_count, "/", sectors.size())
	quit(0)


func _sectors_to_fix() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for y in range(MIN_Y, MAX_Y + 1):
		for x in range(MIN_X, MAX_X + 1):
			var sector := Vector2i(x, y)
			if _export_height_max(sector) > HEIGHT_FIX_THRESHOLD:
				sectors.append(sector)
	return sectors


func _export_height_max(sector: Vector2i) -> float:
	var metadata_path := ProjectSettings.globalize_path(EXPORT_ROOT + "/sector_" + str(sector.x) + "_" + str(sector.y) + "/metadata.json")
	if not FileAccess.file_exists(metadata_path):
		return HEIGHT_FIX_THRESHOLD + 1.0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not (parsed is Dictionary):
		return HEIGHT_FIX_THRESHOLD + 1.0
	var metadata := parsed as Dictionary
	return float(metadata.get("height_max", HEIGHT_FIX_THRESHOLD + 1.0))
