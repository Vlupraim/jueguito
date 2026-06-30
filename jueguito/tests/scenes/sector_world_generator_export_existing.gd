extends SceneTree

const EXPORT_ROOT := "res://data/terrain3d_exports"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/sector_world_generator.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)

	for index in range(8):
		await physics_frame

	var sectors := _existing_exported_sectors()
	if sectors.is_empty():
		print("No hay sectores Terrain3D exportados para regenerar.")
		quit(0)
		return

	var exported := 0
	for sector in sectors:
		if scene.call("_export_sector_for_terrain3d", sector, false):
			exported += 1
			print("REEXPORTED=", sector)
		else:
			push_error("No pude regenerar el sector " + str(sector))

	print("REEXPORTED_COUNT=", exported, "/", sectors.size())
	quit(0 if exported == sectors.size() else 1)


func _existing_exported_sectors() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	var absolute_root := ProjectSettings.globalize_path(EXPORT_ROOT)
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return sectors

	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if directory.current_is_dir() and entry.begins_with("sector_"):
			var parts := entry.trim_prefix("sector_").split("_")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				sectors.append(Vector2i(int(parts[0]), int(parts[1])))
		entry = directory.get_next()
	directory.list_dir_end()

	sectors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	return sectors
