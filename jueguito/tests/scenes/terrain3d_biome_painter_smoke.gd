@tool
extends SceneTree

const AUTO_PAINTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_auto_painter.gd")
const EDIT_DIR := "res://data/terrain3d_edits/sector_27_30"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var painter: RefCounted = AUTO_PAINTER_SCRIPT.new()
	for biome_id in range(0, 8):
		var summary: Dictionary = painter.call("biome_profile_summary", biome_id)
		var texture_ids: PackedInt32Array = summary.get("texture_ids", PackedInt32Array())
		if texture_ids.is_empty() or texture_ids[0] < 0 or texture_ids[texture_ids.size() - 1] > 24:
			printerr("BIOME_PAINTER_PROFILE_ERROR biome=%d textures=%s" % [biome_id, str(texture_ids)])
			quit(2)
			return
		if biome_id == 4 and (not 24 in texture_ids or 15 in texture_ids):
			printerr("BIOME_PAINTER_PROFILE_ERROR polar debe usar nieve, no ceniza")
			quit(3)
			return

	var terrain := Terrain3D.new()
	terrain.assets = load("res://assets/environment/terrain/jueguito_terrain_assets.tres")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	root.add_child(terrain)
	terrain.set_camera(camera)
	terrain.data_directory = EDIT_DIR
	await process_frame
	# Ejercita perfiles representativos sin guardar ni modificar el terreno.
	for biome_id in [1, 2, 4, 6]:
		var result: Dictionary = painter.call("process_terrain_data", terrain.data, {
			"apply": false,
			"edge_radius": 5,
			"biome_id": biome_id,
			"surface_id": 3 if biome_id == 1 else 1,
		})
		if not bool(result.get("ok", false)):
			printerr("BIOME_PAINTER_DRY_RUN_ERROR biome=%d message=%s" % [biome_id, str(result.get("message", ""))])
			quit(4)
			return
		if int(result.get("pixels", 0)) != 512 * 512:
			printerr("BIOME_PAINTER_DRY_RUN_ERROR biome=%d pixel_count=%d" % [biome_id, int(result.get("pixels", 0))])
			quit(5)
			return

	print("BIOME_PAINTER_SMOKE_OK profiles=8 dry_runs=4 slots=0-24 polar=snow")
	quit(0)
