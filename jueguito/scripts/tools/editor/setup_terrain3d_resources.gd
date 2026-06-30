@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const MATERIAL_PATH := "res://assets/environment/terrain/jueguito_terrain_material.tres"

const TEXTURES := [
	{
		"name": "00_TierraSeca",
		"albedo": "res://assets/environment/terrain/textures/ground/Ground103_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/ground/Ground103_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "01_Arena",
		"albedo": "res://assets/environment/terrain/textures/sand/Ground054_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/sand/Ground054_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "02_Pasto",
		"albedo": "res://assets/environment/terrain/textures/grass-2/Grass005_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/grass-2/Grass005_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "03_TierraHumeda",
		"albedo": "res://assets/environment/terrain/textures/grass/Grass001_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/grass/Grass001_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "04_Roca",
		"albedo": "res://assets/environment/terrain/textures/rock/Rock030_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/rock/Rock030_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "05_RocaSecundaria",
		"albedo": "res://assets/environment/terrain/textures/rock-2/Rock028_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/rock-2/Rock028_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "06_Nieve",
		"albedo": "res://assets/environment/terrain/textures/snow/Snow014_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/snow/Snow014_1K-JPG_NormalGL.jpg",
	},
	{
		"name": "07_Pantano",
		"albedo": "res://assets/environment/terrain/textures/swamp/Moss002_1K-JPG_Color.jpg",
		"normal": "res://assets/environment/terrain/textures/swamp/Moss002_1K-JPG_NormalGL.jpg",
	},
]


func _init() -> void:
	var assets := Terrain3DAssets.new()
	for index in range(TEXTURES.size()):
		var texture_data: Dictionary = TEXTURES[index]
		var texture := Terrain3DTextureAsset.new()
		texture.id = index
		texture.name = str(texture_data["name"])
		var albedo := load(str(texture_data["albedo"])) as Texture2D
		if albedo != null:
			texture.set_albedo_texture(albedo)
		var normal := load(str(texture_data["normal"])) as Texture2D
		if normal != null and texture.has_method("set_normal_texture"):
			texture.call("set_normal_texture", normal)
		assets.set_texture(index, texture)

	var material := Terrain3DMaterial.new()
	material.set("show_checkered", false)

	var assets_error := ResourceSaver.save(assets, ASSETS_PATH)
	var material_error := ResourceSaver.save(material, MATERIAL_PATH)
	if assets_error != OK:
		push_error("No pude guardar " + ASSETS_PATH + ": " + error_string(assets_error))
	if material_error != OK:
		push_error("No pude guardar " + MATERIAL_PATH + ": " + error_string(material_error))
	if assets_error == OK and material_error == OK:
		print("Terrain3D resources listos: ", ASSETS_PATH, " | ", MATERIAL_PATH)
	quit(0 if assets_error == OK and material_error == OK else 1)
