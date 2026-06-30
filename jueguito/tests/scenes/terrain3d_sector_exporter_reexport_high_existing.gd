extends SceneTree

const EXPORT_ROOT := "res://data/terrain3d_exports"
const SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const MOUNTAIN_BIOME_ID := 5
const OLD_MOUNTAIN_THRESHOLD := 130.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var exporter_script := load("res://scripts/tools/editor/terrain3d_sector_exporter.gd") as Script
	var exporter: RefCounted = exporter_script.new()
	var sectors := _mountain_or_high_exported_sectors()
	if sectors.is_empty():
		print("MOUNTAIN_EXPORT_REEXPORT= no hay sectores de montaña exportados.")
		quit(0)
		return

	var fixed_count := 0
	for sector in sectors:
		var old_max := _export_height_max(sector)
		var result: Dictionary = await exporter.call("export_sector_async", sector, Callable())
		print("MOUNTAIN_EXPORT_REEXPORT=", sector, " old_max=", old_max, " result=", result)
		if not bool(result.get("ok", false)):
			push_error("No pude reexportar " + str(sector))
			quit(1)
			return
		fixed_count += 1

	print("MOUNTAIN_EXPORT_REEXPORT_COUNT=", fixed_count, "/", sectors.size())
	quit(0)


func _mountain_or_high_exported_sectors() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	var sector_data := _load_sector_data()
	var root_path := ProjectSettings.globalize_path(EXPORT_ROOT)
	var directory := DirAccess.open(root_path)
	if directory == null:
		return sectors

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir() and entry.begins_with("sector_"):
			var sector := _sector_from_dir_name(entry)
			if sector != Vector2i(-1, -1) and (_is_mountain_sector(sector, sector_data) or _export_height_max(sector) > OLD_MOUNTAIN_THRESHOLD):
				sectors.append(sector)
		entry = directory.get_next()
	directory.list_dir_end()
	sectors.sort_custom(_sort_sectors)
	return sectors


func _load_sector_data() -> Dictionary:
	var path := ProjectSettings.globalize_path(SECTOR_DATA_PATH)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary


func _is_mountain_sector(sector: Vector2i, sector_data: Dictionary) -> bool:
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		return false
	var sectors := sectors_value as Dictionary
	var sector_value: Variant = sectors.get(str(sector.x) + "," + str(sector.y), {})
	if not (sector_value is Dictionary):
		return false
	return int((sector_value as Dictionary).get("biome_id", 0)) == MOUNTAIN_BIOME_ID


func _sort_sectors(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x


func _sector_from_dir_name(dir_name: String) -> Vector2i:
	var parts := dir_name.trim_prefix("sector_").split("_")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _export_height_max(sector: Vector2i) -> float:
	var metadata_path := ProjectSettings.globalize_path(
		EXPORT_ROOT + "/sector_" + str(sector.x) + "_" + str(sector.y) + "/metadata.json"
	)
	if not FileAccess.file_exists(metadata_path):
		return -INF
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not (parsed is Dictionary):
		return -INF
	var metadata := parsed as Dictionary
	return float(metadata.get("height_max", -INF))
