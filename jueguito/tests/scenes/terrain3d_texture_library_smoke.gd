@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"


func _initialize() -> void:
	var assets := ResourceLoader.load(ASSETS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DAssets
	if assets == null:
		printerr("TERRAIN_TEXTURE_LIBRARY_ERROR no se pudo cargar la biblioteca")
		quit(2)
		return
	print("TERRAIN_TEXTURE_LIBRARY count=%d" % assets.get_texture_count())
	for texture_id in range(assets.get_texture_count()):
		var texture := assets.get_texture(texture_id) as Terrain3DTextureAsset
		var albedo := texture.get_albedo_texture() if texture != null else null
		var image := albedo.get_image() if albedo != null else null
		var valid := image != null and not image.is_empty()
		var has_mipmaps := image.has_mipmaps() if valid else false
		print("slot=%02d name=%s albedo=%s size=%s format=%s mipmaps=%s tint=%s valid=%s" % [
			texture_id,
			texture.name if texture != null else "<null>",
			albedo.resource_path if albedo != null else "<null>",
			str(image.get_size()) if valid else "<none>",
			str(image.get_format()) if valid else "<none>",
			str(has_mipmaps),
			str(texture.albedo_color) if texture != null else "<none>",
			str(valid),
		])
		if not valid:
			printerr("TERRAIN_TEXTURE_LIBRARY_ERROR slot invalido %d" % texture_id)
			quit(3)
			return
		if texture_id in [6, 23] and not has_mipmaps:
			printerr("TERRAIN_TEXTURE_LIBRARY_ERROR slot %d sin mipmaps" % texture_id)
			quit(4)
			return
		if texture_id in [6, 23] and image.get_format() != Image.FORMAT_RGB8:
			printerr("TERRAIN_TEXTURE_LIBRARY_ERROR slot %d tiene formato %s; se requiere RGB8" % [texture_id, str(image.get_format())])
			quit(5)
			return
	print("TERRAIN_TEXTURE_LIBRARY_OK")
	quit(0)
