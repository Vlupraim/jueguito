extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var exporter_script := load("res://scripts/tools/editor/terrain3d_sector_exporter.gd") as Script
	var exporter: RefCounted = exporter_script.new()
	var sectors := [
		Vector2i(42, 25),
		Vector2i(43, 24),
		Vector2i(44, 23),
		Vector2i(44, 25),
	]
	for sector in sectors:
		var result: Dictionary = await exporter.call("export_sector_async", sector, Callable())
		print("EXPORTER_SMOKE=", sector, result)
		if not bool(result.get("ok", false)):
			push_error("El exportador de sectores Terrain3D fallo en " + str(sector) + ".")
			quit(1)
			return
	quit(0)
