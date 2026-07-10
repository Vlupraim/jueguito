@tool
extends SceneTree

const PLUGIN_SCRIPT_PATH := "res://addons/jueguito_terrain_tools/terrain_map_plugin.gd"
const DOCK_SCRIPT_PATH := "res://addons/jueguito_terrain_tools/terrain_map_dock.gd"


func _initialize() -> void:
	var failed := false
	if not _load_script(PLUGIN_SCRIPT_PATH):
		failed = true
	if not _load_script(DOCK_SCRIPT_PATH):
		failed = true

	if failed:
		printerr("Jueguito Terrain Tools validation failed.")
		quit(1)
		return

	print("Jueguito Terrain Tools validation OK.")
	quit(0)


func _load_script(path: String) -> bool:
	var resource := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is Script:
		return true
	printerr("Could not load script: " + path)
	return false
