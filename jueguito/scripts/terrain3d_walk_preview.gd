extends Node3D

# Preview caminable del terreno Terrain3D editado.
# Carga un sector guardado (res://data/terrain3d_edits/sector_X_Y) y deja
# caminar al personaje sobre la colision real para revisar texturas y forma.
# No es el juego final: es una herramienta de revision del art pass.

const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const TERRAIN_ASSETS := preload("res://assets/environment/terrain/jueguito_terrain_assets.tres")
const TERRAIN_MATERIAL := preload("res://assets/environment/terrain/jueguito_terrain_material.tres")

## Sector a previsualizar. Si no tiene ediciones guardadas, busca el primero que exista.
@export var sector := Vector2i(15, 6)
## Punto horizontal de respaldo si no se encuentra una region activa.
@export var spawn_xz := Vector2(512.0, 512.0)

var terrain: Terrain3D
var player: CharacterBody3D
var spawn_position := Vector3.ZERO


func _ready() -> void:
	_setup_environment()
	_setup_terrain()
	# Crear jugador y fijar la camara de Terrain3D ANTES de su primer frame de fisica,
	# asi no se queja de "active camera" ni detiene su proceso.
	_spawn_player()
	await get_tree().process_frame
	_place_player_on_ground()


func _process(_delta: float) -> void:
	# Red de seguridad: si la colision aun no estaba lista y el personaje cayo, lo reponemos.
	if player != null and player.global_position.y < -120.0:
		player.global_position = spawn_position
		player.velocity = Vector3.ZERO


func _setup_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var world_env := WorldEnvironment.new()
	world_env.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.45
	world_env.environment = env
	add_child(world_env)


func _setup_terrain() -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.assets = TERRAIN_ASSETS
	terrain.material = TERRAIN_MATERIAL
	add_child(terrain)

	var data_dir := _resolve_data_dir()
	if data_dir.is_empty():
		push_warning("Terrain3DWalkPreview: no encontre ningun sector editado en " + TERRAIN3D_EDIT_DIR + ". Carga y guarda un sector en el dock primero.")
		return
	terrain.data_directory = data_dir
	print("Terrain3DWalkPreview: cargado ", data_dir)


func _resolve_data_dir() -> String:
	var preferred := TERRAIN3D_EDIT_DIR + "/sector_%d_%d" % [sector.x, sector.y]
	if _dir_has_res(preferred):
		return preferred
	# Fallback: el primer sector con datos guardados.
	var root := DirAccess.open(ProjectSettings.globalize_path(TERRAIN3D_EDIT_DIR))
	if root == null:
		return ""
	root.list_dir_begin()
	var name := root.get_next()
	while name != "":
		if root.current_is_dir() and name.begins_with("sector_"):
			var candidate := TERRAIN3D_EDIT_DIR + "/" + name
			if _dir_has_res(candidate):
				root.list_dir_end()
				return candidate
		name = root.get_next()
	root.list_dir_end()
	return ""


func _dir_has_res(dir_path: String) -> bool:
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	if player.has_method("make_camera_current"):
		player.call("make_camera_current")
	# Terrain3D necesita saber que camara seguir para su clipmap/LOD.
	var cam := _player_camera()
	if cam != null and terrain != null and terrain.has_method("set_camera"):
		terrain.set_camera(cam)


func _place_player_on_ground() -> void:
	if player == null:
		return
	var ground_xz := _find_ground_xz()
	var ground_y := 5.0
	if terrain != null and terrain.data != null:
		var sampled := terrain.data.get_height(Vector3(ground_xz.x, 0.0, ground_xz.y))
		if not is_nan(sampled):
			ground_y = sampled + 3.0
	spawn_position = Vector3(ground_xz.x, ground_y, ground_xz.y)
	player.global_position = spawn_position
	if player.has_method("mark_safe_position"):
		player.call("mark_safe_position")
	print("Terrain3DWalkPreview: jugador en ", spawn_position.round())


# Busca el centro de la region activa con la tierra mas alta, para aparecer sobre
# terreno solido (no en el agua) y dentro del area cargada del sector.
func _find_ground_xz() -> Vector2:
	if terrain == null or terrain.data == null:
		return spawn_xz
	var region_size := 1024.0
	if "region_size" in terrain:
		region_size = float(terrain.region_size)
	var regions: Array = terrain.data.get_regions_active()
	var best_xz := spawn_xz
	var best_height := -INF
	for region in regions:
		var loc: Vector2i = region.location
		var center := Vector2((float(loc.x) + 0.5) * region_size, (float(loc.y) + 0.5) * region_size)
		var height := terrain.data.get_height(Vector3(center.x, 0.0, center.y))
		if not is_nan(height) and height > best_height:
			best_height = height
			best_xz = center
	return best_xz


func _player_camera() -> Camera3D:
	if player == null:
		return null
	var cameras := player.find_children("*", "Camera3D", true, false)
	if cameras.is_empty():
		return null
	return cameras[0]
