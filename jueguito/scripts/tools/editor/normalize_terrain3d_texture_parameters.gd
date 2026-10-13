@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"

# Base visual compartida para evitar saltos de relieve, brillo y escala al mezclar.
const NORMAL_DEPTH := 0.722
const AO_STRENGTH := 0.813
const ROUGHNESS := 0.0
const UV_SCALE := 0.684
const DETILING_ROTATION := 0.298
const DETILING_SHIFT := 0.255


func _initialize() -> void:
	var assets := ResourceLoader.load(ASSETS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DAssets
	if assets == null:
		printerr("TERRAIN_TEXTURE_NORMALIZE_ERROR no se pudo cargar " + ASSETS_PATH)
		quit(2)
		return

	var changed := 0
	for index in range(assets.get_texture_count()):
		var texture := assets.get_texture(index) as Terrain3DTextureAsset
		if texture == null:
			continue
		texture.normal_depth = NORMAL_DEPTH
		texture.ao_strength = AO_STRENGTH
		texture.roughness = ROUGHNESS
		texture.uv_scale = UV_SCALE
		texture.detiling_rotation = DETILING_ROTATION
		texture.detiling_shift = DETILING_SHIFT
		changed += 1

	var error := ResourceSaver.save(assets, ASSETS_PATH)
	if error != OK:
		printerr("TERRAIN_TEXTURE_NORMALIZE_ERROR " + error_string(error))
		quit(1)
		return
	print("TERRAIN_TEXTURE_NORMALIZE_OK textures=%d normal_depth=%.3f ao=%.3f roughness=%.3f uv=%.3f rotation=%.3f shift=%.3f" % [
		changed, NORMAL_DEPTH, AO_STRENGTH, ROUGHNESS, UV_SCALE, DETILING_ROTATION, DETILING_SHIFT,
	])
	quit(0)
