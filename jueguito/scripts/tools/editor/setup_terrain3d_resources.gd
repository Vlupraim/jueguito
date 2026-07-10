@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const MATERIAL_PATH := "res://assets/environment/terrain/jueguito_terrain_material.tres"
const QUATERNIUS_PATH := "res://assets/environment/vegetation/quaternius_stylized_nature/"

const TEXTURES := [
	{
		"name": "00_TierraSeca",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/00_tierra_seca.png",
	},
	{
		"name": "01_Arena",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/01_arena.png",
	},
	{
		"name": "02_Pasto",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/02_pasto.png",
	},
	{
		"name": "03_TierraHumeda",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/03_tierra_humeda.png",
	},
	{
		"name": "04_Roca",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/04_roca.png",
	},
	{
		"name": "05_Arcano",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/05_arcano.png",
	},
	{
		"name": "06_Nieve",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/06_nieve.png",
	},
	{
		"name": "07_Pantano",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/07_pantano.png",
	},
]

const MESH_ASSETS := [
	{
		"name": "00_PastoCorto",
		"scene": QUATERNIUS_PATH + "Grass_Common_Short.gltf",
		"density": 1.6,
		"height_offset": 0.0,
		"lod0_range": 40.0,
	},
	{
		"name": "01_PastoAlto",
		"scene": QUATERNIUS_PATH + "Grass_Wispy_Tall.gltf",
		"density": 0.9,
		"height_offset": 0.0,
		"lod0_range": 48.0,
	},
	{
		"name": "02_Arbusto",
		"scene": QUATERNIUS_PATH + "Bush_Common.gltf",
		"density": 0.25,
		"height_offset": 0.0,
		"lod0_range": 80.0,
	},
	{
		"name": "03_ArbolComun",
		"scene": QUATERNIUS_PATH + "CommonTree_1.gltf",
		"density": 0.035,
		"height_offset": 0.0,
		"lod0_range": 160.0,
	},
	{
		"name": "04_ArbolComunAlto",
		"scene": QUATERNIUS_PATH + "CommonTree_3.gltf",
		"density": 0.025,
		"height_offset": 0.0,
		"lod0_range": 180.0,
	},
	{
		"name": "05_Pino",
		"scene": QUATERNIUS_PATH + "Pine_1.gltf",
		"density": 0.03,
		"height_offset": 0.0,
		"lod0_range": 180.0,
	},
	{
		"name": "06_RocaMediana",
		"scene": QUATERNIUS_PATH + "Rock_Medium_1.gltf",
		"density": 0.08,
		"height_offset": 0.0,
		"lod0_range": 120.0,
	},
	{
		"name": "07_Hongo",
		"scene": QUATERNIUS_PATH + "Mushroom_Common.gltf",
		"density": 0.35,
		"height_offset": 0.0,
		"lod0_range": 48.0,
	},
]


func _init() -> void:
	var assets := Terrain3DAssets.new()
	var had_load_error := false
	for index in range(TEXTURES.size()):
		var texture_data: Dictionary = TEXTURES[index]
		var texture := Terrain3DTextureAsset.new()
		texture.id = index
		texture.name = str(texture_data["name"])
		var albedo := load(str(texture_data["albedo"])) as Texture2D
		if albedo != null:
			texture.set_albedo_texture(albedo)
		else:
			had_load_error = true
			push_error("No pude cargar la textura albedo: " + str(texture_data["albedo"]))
		if texture_data.has("normal") and not str(texture_data["normal"]).is_empty():
			var normal := load(str(texture_data["normal"])) as Texture2D
			if normal != null and texture.has_method("set_normal_texture"):
				texture.call("set_normal_texture", normal)
		assets.set_texture(index, texture)

	for index in range(MESH_ASSETS.size()):
		var mesh_data: Dictionary = MESH_ASSETS[index]
		var mesh_asset := Terrain3DMeshAsset.new()
		mesh_asset.id = index
		mesh_asset.name = str(mesh_data["name"])
		var scene := load(str(mesh_data["scene"])) as PackedScene
		if scene != null:
			mesh_asset.set_scene_file(scene)
		else:
			had_load_error = true
			push_error("No pude cargar el mesh asset: " + str(mesh_data["scene"]))
		mesh_asset.density = float(mesh_data["density"])
		mesh_asset.height_offset = float(mesh_data["height_offset"])
		mesh_asset.lod0_range = float(mesh_data["lod0_range"])
		assets.set_mesh_asset(index, mesh_asset)

	var material_was_created := false
	var material := load(MATERIAL_PATH) as Terrain3DMaterial
	if material == null:
		material = Terrain3DMaterial.new()
		material_was_created = true
	material.set("show_checkered", false)

	var assets_error := ResourceSaver.save(assets, ASSETS_PATH)
	var material_error := OK
	if material_was_created:
		material_error = ResourceSaver.save(material, MATERIAL_PATH)
	if assets_error != OK:
		push_error("No pude guardar " + ASSETS_PATH + ": " + error_string(assets_error))
	if material_error != OK:
		push_error("No pude guardar " + MATERIAL_PATH + ": " + error_string(material_error))
	if assets_error == OK and material_error == OK and not had_load_error:
		print("Terrain3D resources listos: ", ASSETS_PATH, " | ", MATERIAL_PATH)
	quit(0 if assets_error == OK and material_error == OK and not had_load_error else 1)
