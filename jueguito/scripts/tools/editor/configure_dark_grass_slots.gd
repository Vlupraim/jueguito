@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const FLAT_NORMAL_PATH := "res://assets/environment/terrain/textures/stylized/terrain_slots/flat_normal_roughness.svg"
const REPLACEMENTS := [
	{
		"id": 6,
		"name": "06_PastoSombrio",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/06_pasto_sombrio.png",
	},
	{
		"id": 23,
		"name": "23_PastoRocasSombrio",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/23_pasto_rocas_sombrio.png",
	},
]


func _initialize() -> void:
	var assets := ResourceLoader.load(ASSETS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DAssets
	var normal := load(FLAT_NORMAL_PATH) as Texture2D
	if assets == null or normal == null:
		printerr("DARK_GRASS_SLOTS_ERROR no se pudieron cargar los recursos base")
		quit(2)
		return

	for data in REPLACEMENTS:
		var id := int(data.id)
		var texture := assets.get_texture(id) as Terrain3DTextureAsset
		if texture == null:
			texture = Terrain3DTextureAsset.new()
		texture.id = id
		texture.name = str(data.name)
		texture.set_albedo_texture(load(str(data.albedo)) as Texture2D)
		texture.set_normal_texture(normal)
		texture.albedo_color = Color.WHITE
		texture.normal_depth = 0.722
		texture.ao_strength = 0.813
		texture.roughness = 0.0
		texture.uv_scale = 0.684
		texture.detiling_rotation = 0.298
		texture.detiling_shift = 0.255
		assets.set_texture(id, texture)

	# Terrain3D usa una biblioteca compacta. Quitamos los antiguos slots 24 y 25.
	assets.texture_list.resize(24)
	var error := ResourceSaver.save(assets, ASSETS_PATH)
	if error != OK:
		printerr("DARK_GRASS_SLOTS_ERROR " + error_string(error))
		quit(1)
		return
	print("DARK_GRASS_SLOTS_OK textures=%d dark_ids=6,23" % assets.get_texture_count())
	quit(0)
