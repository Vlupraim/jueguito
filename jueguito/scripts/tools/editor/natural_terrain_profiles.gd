@tool
extends RefCounted

const PROFILES_PATH := "res://data/materials/natural_terrain_v1.json"

static func apply(assets: Terrain3DAssets) -> bool:
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
	if not profiles is Array: return false
	for profile: Dictionary in profiles:
		var id := int(profile["id"])
		var texture: Terrain3DTextureAsset = assets.get_texture(id) if id < assets.get_texture_count() else null
		if texture == null: texture = Terrain3DTextureAsset.new()
		var albedo := load(str(profile["albedo"])) as Texture2D
		var normal := load(str(profile["normal"])) as Texture2D
		if albedo == null or normal == null: return false
		texture.id = id
		texture.name = str(profile["name"])
		texture.albedo_texture = albedo
		texture.normal_texture = normal
		var tint: Array = profile["tint"]
		texture.albedo_color = Color(tint[0], tint[1], tint[2], 1)
		for property in ["normal_depth", "ao_strength", "roughness", "uv_scale"]:
			texture.set(property, float(profile[property]))
		texture.detiling_rotation = 0.298
		texture.detiling_shift = 0.255
		assets.set_texture(id, texture)
	return true
