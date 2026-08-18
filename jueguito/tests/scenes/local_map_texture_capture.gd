@tool
extends SceneTree

const BUILDER := preload("res://scripts/ui/local_map_texture_builder.gd")
const SURFACE_PATH := "res://data/terrain3d_exports/sector_27_30/surface_reference.png"
const HEIGHT_PATH := "res://data/terrain3d_exports/sector_27_30/height_preview.png"
const OUTPUT_PATH := "res://tests/output/local_map_texture_sector_27_30.png"


func _initialize() -> void:
	var surface := load(SURFACE_PATH) as Texture2D
	var height := load(HEIGHT_PATH) as Texture2D
	var result := BUILDER.build(surface, height) as ImageTexture
	if result == null:
		printerr("LOCAL_MAP_TEXTURE_CAPTURE_ERROR")
		quit(2)
		return
	var error := result.get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("LOCAL_MAP_TEXTURE_CAPTURE_OK " + OUTPUT_PATH if error == OK else "LOCAL_MAP_TEXTURE_CAPTURE_ERROR")
	quit(0 if error == OK else 3)
