@tool
extends SceneTree

const ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const ASSETS_UID := "uid://culjong3w41jq"
const MATERIAL_PATH := "res://assets/environment/terrain/jueguito_terrain_material.tres"
const FLAT_NORMAL_PATH := "res://assets/environment/terrain/textures/stylized/terrain_slots/flat_normal_roughness.svg"
const QUATERNIUS_PATH := "res://assets/environment/vegetation/quaternius_stylized_nature/"
const TEXTURE_NORMAL_DEPTH := 0.722
const TEXTURE_AO_STRENGTH := 0.813
const TEXTURE_ROUGHNESS := 0.0
const TEXTURE_UV_SCALE := 0.684
const TEXTURE_DETILING_ROTATION := 0.298
const TEXTURE_DETILING_SHIFT := 0.255

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
		"name": "06_PastoSombrio",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/02_pasto.png",
		"albedo_color": Color("77856f"),
	},
	{
		"name": "07_Pantano",
		"albedo": "res://assets/environment/terrain/textures/stylized/terrain_slots/07_pantano.png",
	},
	{
		"name": "08_TierraGrisGravilla",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/tierra/tierra_gris_con_gravilla_001.png",
	},
	{
		"name": "09_ArenaRosaGravilla",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/arena_arcilla/arena_rosa_con_gravilla_fina_015.png",
	},
	{
		"name": "10_ArenaClaraPiedras",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/arena_arcilla/arena_clara_con_piedras_024.png",
	},
	{
		"name": "11_TierraOcrePiedras",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/tierra/tierra_ocre_con_piedras_031.png",
	},
	{
		"name": "12_TierraRojaFina",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/tierra/tierra_roja_con_gravilla_fina_033.png",
	},
	{
		"name": "13_TierraRojaGrava",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/tierra/tierra_roja_con_grava_036.png",
	},
	{
		"name": "14_RocaGrisLajas",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/roca_acantilado/roca_gris_de_lajas_grandes_040.png",
	},
	{
		"name": "15_CenizaGrisGravilla",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/tierra/ceniza_gris_con_gravilla_048.png",
	},
	{
		"name": "16_RocaMarronMusgo",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/vegetacion_humedad/roca_marron_con_musgo_064.png",
	},
	{
		"name": "17_PastoRocasDispersas",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/vegetacion_humedad/pasto_con_rocas_dispersas_070.png",
	},
	{
		"name": "18_MusgoRocasGrandes",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/vegetacion_humedad/musgo_con_rocas_grandes_071.png",
	},
	{
		"name": "19_RocaCalizaClara",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/roca_acantilado/roca_caliza_clara_077.png",
	},
	{
		"name": "20_RocaMarronLajas",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/roca_acantilado/roca_marron_en_lajas_079.png",
	},
	{
		"name": "21_CantosMarronesHumedos",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/grava_cantos/cantos_marrones_humedos_087.png",
	},
	{
		"name": "22_EmpedradoRojo",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/grava_cantos/empedrado_rojo_091.png",
	},
	{
		"name": "23_PastoRocasSombrio",
		"albedo": "res://assets/environment/terrain/textures/stylized/curated_ground/vegetacion_humedad/pasto_con_rocas_dispersas_070.png",
		"albedo_color": Color("7f8878"),
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
	# Reutilizar la biblioteca existente conserva ajustes hechos desde el asset dock
	# (UV, detiling, roughness, etc.) mientras normalizamos sus referencias de archivo.
	var assets := load(ASSETS_PATH) as Terrain3DAssets
	if assets == null:
		assets = Terrain3DAssets.new()
	var had_load_error := false
	for index in range(TEXTURES.size()):
		var texture_data: Dictionary = TEXTURES[index]
		var texture: Terrain3DTextureAsset = null
		if index < assets.get_texture_count():
			texture = assets.get_texture(index)
		if texture == null:
			texture = Terrain3DTextureAsset.new()
		texture.id = index
		texture.name = str(texture_data["name"])
		var albedo := load(str(texture_data["albedo"])) as Texture2D
		if albedo != null:
			texture.set_albedo_texture(albedo)
		else:
			had_load_error = true
			push_error("No pude cargar la textura albedo: " + str(texture_data["albedo"]))
		var normal := load(FLAT_NORMAL_PATH) as Texture2D
		if normal != null and texture.has_method("set_normal_texture"):
			texture.call("set_normal_texture", normal)
		else:
			had_load_error = true
			push_error("No pude cargar la textura normal compartida: " + FLAT_NORMAL_PATH)
		if texture_data.has("albedo_color"):
			texture.albedo_color = texture_data["albedo_color"]
		texture.normal_depth = TEXTURE_NORMAL_DEPTH
		texture.ao_strength = TEXTURE_AO_STRENGTH
		texture.roughness = TEXTURE_ROUGHNESS
		texture.uv_scale = TEXTURE_UV_SCALE
		texture.detiling_rotation = TEXTURE_DETILING_ROTATION
		texture.detiling_shift = TEXTURE_DETILING_SHIFT
		assets.set_texture(index, texture)
	assets.texture_list.resize(TEXTURES.size())

	for index in range(MESH_ASSETS.size()):
		var mesh_data: Dictionary = MESH_ASSETS[index]
		var mesh_asset: Terrain3DMeshAsset = null
		if index < assets.get_mesh_count():
			mesh_asset = assets.get_mesh_asset(index)
		if mesh_asset == null:
			mesh_asset = Terrain3DMeshAsset.new()
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
	var assets_uid_error := OK
	if assets_error == OK:
		assets_uid_error = ResourceSaver.set_uid(ASSETS_PATH, ResourceUID.text_to_id(ASSETS_UID))
	var material_error := OK
	if material_was_created:
		material_error = ResourceSaver.save(material, MATERIAL_PATH)
	if assets_error != OK:
		push_error("No pude guardar " + ASSETS_PATH + ": " + error_string(assets_error))
	if assets_uid_error != OK:
		push_error("No pude conservar el UID de " + ASSETS_PATH + ": " + error_string(assets_uid_error))
	if material_error != OK:
		push_error("No pude guardar " + MATERIAL_PATH + ": " + error_string(material_error))
	if assets_error == OK and assets_uid_error == OK and material_error == OK and not had_load_error:
		print("Terrain3D resources listos: ", ASSETS_PATH, " | ", MATERIAL_PATH)
	quit(0 if assets_error == OK and assets_uid_error == OK and material_error == OK and not had_load_error else 1)
