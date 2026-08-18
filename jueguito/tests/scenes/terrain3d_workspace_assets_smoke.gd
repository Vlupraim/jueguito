@tool
extends SceneTree

const WORKSPACE_PATH := "res://scenes/tools/editor/terrain3d_sector_workspace.tscn"
const EXPECTED_ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"


func _initialize() -> void:
	var scene := load(WORKSPACE_PATH) as PackedScene
	if scene == null:
		printerr("TERRAIN_WORKSPACE_ASSETS_ERROR no se pudo cargar el workspace")
		quit(2)
		return
	var workspace := scene.instantiate()
	root.add_child(workspace)
	var importer := workspace.find_child("Importer", true, false)
	var assets := importer.get("assets") as Resource if importer != null else null
	var actual_path := assets.resource_path if assets != null else ""
	if actual_path != EXPECTED_ASSETS_PATH:
		printerr("TERRAIN_WORKSPACE_ASSETS_ERROR actual=%s expected=%s" % [actual_path, EXPECTED_ASSETS_PATH])
		quit(3)
		return
	var texture_assets := assets as Terrain3DAssets
	if texture_assets.get_texture_count() != 24:
		printerr("TERRAIN_WORKSPACE_ASSETS_ERROR texture_count=%d" % texture_assets.get_texture_count())
		quit(4)
		return
	for texture_id in [6, 23]:
		var texture := texture_assets.get_texture(texture_id) as Terrain3DTextureAsset
		if texture == null or texture.get_albedo_texture() == null:
			printerr("TERRAIN_WORKSPACE_ASSETS_ERROR slot=%d vacio" % texture_id)
			quit(5)
			return
	print("TERRAIN_WORKSPACE_ASSETS_OK path=%s slots=24 dark_grass=6,23" % actual_path)
	quit(0)
