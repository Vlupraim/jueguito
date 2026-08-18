@tool
extends SceneTree

const AUTO_PAINTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_auto_painter.gd")
const EDIT_DIR := "res://data/terrain3d_edits/sector_27_30"
const PREVIEW_PATH := "res://docs/design/concepts/tutorial/coast_art_paint_preview_v1.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var apply := OS.get_cmdline_user_args().has("--apply")
	var terrain := Terrain3D.new()
	root.add_child(terrain)
	terrain.data_directory = EDIT_DIR
	await process_frame
	var painter: RefCounted = AUTO_PAINTER_SCRIPT.new()
	var result: Dictionary = painter.call("process_terrain_data", terrain.data, {
		"apply": apply,
		"edge_radius": 5,
		"water_level": 2.0,
		"beach_height": 4.6,
		"cliff_slope": 27.0,
		"biome_id": 1,
		"surface_id": 3,
	})
	if not bool(result.get("ok", false)):
		printerr("COAST_ART_PAINT_ERROR " + str(result.get("message", "error desconocido")))
		quit(2)
		return
	var preview := result.get("preview") as Image
	if preview != null:
		preview.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
	if apply:
		terrain.data.save_directory(EDIT_DIR)
	var counts: PackedInt32Array = result.get("counts", PackedInt32Array())
	print("COAST_ART_PAINT_OK mode=%s biome=%s pixels=%d edge_radius=%d counts=%s preview=%s" % [
		"apply" if apply else "dry-run",
		str(result.get("biome_name", "Templado")),
		int(result.get("pixels", 0)),
		int(result.get("edge_radius", 0)),
		str(counts),
		PREVIEW_PATH,
	])
	quit(0)
