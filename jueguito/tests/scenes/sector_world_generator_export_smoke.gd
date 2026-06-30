extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/sector_world_generator.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)

	for index in range(8):
		await physics_frame

	scene.call("_export_current_sector_for_terrain3d")
	for index in range(900):
		await process_frame
		if not bool(scene.get("terrain3d_export_in_progress")):
			break
	print("EXPORT_STATUS=", scene.get("editor_status_text"))

	if not str(scene.get("editor_status_text")).contains("Export Terrain3D listo"):
		push_error("La exportacion Terrain3D no termino correctamente.")
		quit(1)
		return

	quit(0)
