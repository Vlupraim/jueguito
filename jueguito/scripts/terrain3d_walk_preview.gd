extends Node3D

# Preview caminable del terreno Terrain3D editado.
# Carga un sector guardado (res://data/terrain3d_edits/sector_X_Y) y deja
# caminar al personaje sobre la colision real para revisar texturas y forma.
# No es el juego final: es una herramienta de revision del art pass.

const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TEMP_DATA_DIR := "user://walk_preview_temp"
const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const TERRAIN_ASSETS := preload("res://assets/environment/terrain/jueguito_terrain_assets.tres")
const TERRAIN_MATERIAL := preload("res://assets/environment/terrain/jueguito_terrain_material.tres")

# Minimapa (mismas referencias que el dock del plugin).
const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const SECTOR_PIXELS := 25.0
const MINIMAP_SIZE := Vector2(300.0, 169.0)
const MINIMAP_MARGIN := 12.0

## Sector a previsualizar. Si no tiene ediciones guardadas, busca el primero que exista.
@export var sector := Vector2i(15, 6)
## Punto horizontal de respaldo si no se encuentra una region activa.
@export var spawn_xz := Vector2(512.0, 512.0)

var terrain: Terrain3D
var player: CharacterBody3D
var spawn_position := Vector3.ZERO
var debug_label: Label
var saved_textures: Array = []  # respaldo de la lista de texturas para reconstruir el array

# Control de camara orbital para revisar el mundo.
var cam_pivot: Node3D
var cam_arm: SpringArm3D
var cam_yaw := 45.0
var cam_pitch := -45.0  # negativo = camara arriba mirando hacia abajo
var orbiting := false
const CAM_SENSITIVITY := 0.25

# Minimapa navegable.
var current_sector := Vector2i(-1, -1)
var available_sectors := {}  # "x,y" -> Vector2i
var minimap: Control
var minimap_texture: Texture2D
var progress_bar: ProgressBar
var sector_label: Label
var traveling := false


func _ready() -> void:
	_setup_environment()
	_setup_debug_hud()
	_scan_available_sectors()
	# Crear el jugador y activar su camara ANTES del terreno, para que Terrain3D
	# la encuentre en su primer frame y no detenga su procesamiento (quedaria invisible).
	_create_player()
	_setup_terrain()
	_setup_minimap()
	await get_tree().process_frame
	_place_player_on_ground()
	# Reasignar la camara ya en su posicion final, por si el clipmap no la seguia.
	var cam := _player_camera()
	if cam != null and terrain != null and terrain.has_method("set_camera"):
		terrain.set_camera(cam)
	var active_name := "NINGUNA"
	var active_cam := get_viewport().get_camera_3d()
	if active_cam != null:
		active_name = active_cam.name
	print("Terrain3DWalkPreview: camara activa = ", active_name)


func _process(_delta: float) -> void:
	# Red de seguridad: si la colision aun no estaba lista y el personaje cayo, lo reponemos.
	if player != null and player.global_position.y < -120.0:
		player.global_position = spawn_position
		player.velocity = Vector3.ZERO
	_update_debug_hud()


func _setup_debug_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugHUD"
	add_child(layer)
	debug_label = Label.new()
	debug_label.position = Vector2(12.0, 12.0)
	debug_label.add_theme_color_override("font_color", Color.BLACK)
	debug_label.add_theme_color_override("font_outline_color", Color.WHITE)
	debug_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(debug_label)


func _update_debug_hud() -> void:
	if debug_label == null:
		return
	var lines: Array[String] = []
	if player != null:
		lines.append("Jugador: " + str(player.global_position.round()))
		if terrain != null and terrain.data != null:
			var h := terrain.data.get_height(player.global_position)
			lines.append("Altura terreno aqui: " + ("%.1f" % h if not is_nan(h) else "NaN (fuera del terreno)"))
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		lines.append("Camara: " + str(cam.global_position.round()) + " | nombre: " + cam.name)
	else:
		lines.append("Camara: NINGUNA")
	debug_label.text = "\n".join(lines)


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
	# Capturar la lista de texturas ANTES de asignar: al asignar los assets a un
	# Terrain3D en runtime, la lista interna queda vacia y se ve el damero gris.
	saved_textures = TERRAIN_ASSETS.texture_list.duplicate()
	terrain.assets = TERRAIN_ASSETS
	terrain.material = TERRAIN_MATERIAL
	add_child(terrain)

	var cam := _player_camera()
	if cam != null and terrain.has_method("set_camera"):
		terrain.set_camera(cam)

	var initial := _resolve_initial_sector()
	if initial.x < 0:
		push_warning("Terrain3DWalkPreview: no encontre sectores en edits ni exports.")
		_rebuild_textures()
		return
	_load_sector_terrain(initial)
	current_sector = initial
	print("Terrain3DWalkPreview: cargado sector ", initial)


# Reconstruye el array de texturas (en runtime no se reconstruye solo) y apaga el
# damero. Debe llamarse DESPUES de cargar/importar datos de terreno.
func _rebuild_textures() -> void:
	if terrain == null or terrain.assets == null:
		return
	for i in range(saved_textures.size()):
		terrain.assets.set_texture(i, saved_textures[i])
	if terrain.material != null:
		terrain.material.set("show_checkered", false)


# Carga un sector: si tiene edicion guardada usa data_directory; si no, importa
# el height.exr (+ control.exr si existe) del export. Reconstruye texturas al final.
func _load_sector_terrain(sec: Vector2i) -> bool:
	var edit_dir := _sector_edit_dir(sec)
	if _dir_has_res(edit_dir):
		terrain.data_directory = edit_dir
		_rebuild_textures()
		return true

	var export_base := ProjectSettings.globalize_path(TERRAIN3D_EXPORT_DIR + "/sector_%d_%d" % [sec.x, sec.y])
	var height_path := export_base + "/height.exr"
	if not FileAccess.file_exists(height_path):
		return false

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DATA_DIR))
	terrain.data_directory = TEMP_DATA_DIR
	_clear_regions()
	var images := [Terrain3DUtil.load_image(height_path, ResourceLoader.CACHE_MODE_IGNORE), null, null]
	var control_path := export_base + "/control.exr"
	if FileAccess.file_exists(control_path):
		images[1] = Terrain3DUtil.load_image(control_path, ResourceLoader.CACHE_MODE_IGNORE)
	terrain.data.import_images(images, Vector3.ZERO, 0.0, 1.0)
	_rebuild_textures()
	return true


func _clear_regions() -> void:
	if terrain != null and terrain.data != null:
		for region in terrain.data.get_regions_active().duplicate():
			terrain.data.remove_region(region, false)


# Sector inicial: el @export sector si esta disponible, si no el primero que haya.
func _resolve_initial_sector() -> Vector2i:
	if available_sectors.has(_sector_key(sector)):
		return sector
	for key in available_sectors:
		return available_sectors[key]
	return Vector2i(-1, -1)


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


func _create_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	if player.has_method("make_camera_current"):
		player.call("make_camera_current")
	# El brazo de camara (SpringArm3D) choca con la colision de Terrain3D y se
	# colapsa, dejando la camara pegada al suelo. Apagamos su colision en el preview.
	cam_pivot = player.get_node_or_null("CameraPivot")
	cam_arm = player.get_node_or_null("CameraPivot/SpringArm3D")
	if cam_arm != null:
		cam_arm.collision_mask = 0
	_apply_camera_angles()


func _apply_camera_angles() -> void:
	if cam_pivot != null:
		cam_pivot.rotation_degrees.y = cam_yaw
	if cam_arm != null:
		cam_arm.rotation_degrees.x = cam_pitch


func _unhandled_input(event: InputEvent) -> void:
	# Boton derecho mantenido + mover mouse = orbitar la camara.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		orbiting = event.pressed
	elif event is InputEventMouseMotion and orbiting:
		cam_yaw -= event.relative.x * CAM_SENSITIVITY
		cam_pitch = clampf(cam_pitch - event.relative.y * CAM_SENSITIVITY, -85.0, -5.0)
		_apply_camera_angles()


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


# --- Minimapa navegable -------------------------------------------------------

func _sector_key(s: Vector2i) -> String:
	return str(s.x) + "," + str(s.y)


func _sector_from_dir(dir_path: String) -> Vector2i:
	var parts := dir_path.get_file().split("_")  # sector_X_Y
	if parts.size() == 3:
		return Vector2i(int(parts[1]), int(parts[2]))
	return Vector2i(-1, -1)


func _sector_edit_dir(sec: Vector2i) -> String:
	return TERRAIN3D_EDIT_DIR + "/sector_%d_%d" % [sec.x, sec.y]


func _scan_available_sectors() -> void:
	available_sectors.clear()
	# Ediciones guardadas (con datos de region .res).
	_scan_sector_dir(TERRAIN3D_EDIT_DIR, true)
	# Exports (con height.exr): sectores generados aunque no se hayan editado.
	_scan_sector_dir(TERRAIN3D_EXPORT_DIR, false)


func _scan_sector_dir(root_dir: String, require_res: bool) -> void:
	var root := DirAccess.open(ProjectSettings.globalize_path(root_dir))
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if root.current_is_dir() and entry.begins_with("sector_"):
			var sec := _sector_from_dir(entry)
			if sec.x >= 0:
				var ok := false
				if require_res:
					ok = _dir_has_res(root_dir + "/" + entry)
				else:
					ok = FileAccess.file_exists(ProjectSettings.globalize_path(root_dir + "/" + entry + "/height.exr"))
				if ok:
					available_sectors[_sector_key(sec)] = sec
		entry = root.get_next()
	root.list_dir_end()


func _setup_minimap() -> void:
	minimap_texture = load(MAP_TEXTURE_PATH) as Texture2D
	var layer := CanvasLayer.new()
	layer.name = "MinimapaUI"
	add_child(layer)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -MINIMAP_SIZE.x - MINIMAP_MARGIN
	box.offset_right = -MINIMAP_MARGIN
	box.offset_top = MINIMAP_MARGIN
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)

	sector_label = Label.new()
	sector_label.add_theme_color_override("font_color", Color.WHITE)
	sector_label.add_theme_color_override("font_outline_color", Color.BLACK)
	sector_label.add_theme_constant_override("outline_size", 4)
	sector_label.text = _sector_caption(current_sector)
	box.add_child(sector_label)

	minimap = Control.new()
	minimap.custom_minimum_size = MINIMAP_SIZE
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.tooltip_text = "Clic en un sector verde para viajar ahi."
	minimap.draw.connect(_on_minimap_draw)
	minimap.gui_input.connect(_on_minimap_gui_input)
	box.add_child(minimap)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(MINIMAP_SIZE.x, 16.0)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	box.add_child(progress_bar)

	minimap.queue_redraw()


func _sector_caption(sec: Vector2i) -> String:
	if sec.x < 0:
		return "Sin sector cargado"
	return "Sector [%d, %d]" % [sec.x, sec.y]


func _on_minimap_draw() -> void:
	if minimap == null:
		return
	var rect := Rect2(Vector2.ZERO, MINIMAP_SIZE)
	if minimap_texture != null:
		minimap.draw_texture_rect(minimap_texture, rect, false)
	else:
		minimap.draw_rect(rect, Color(0.18, 0.22, 0.28), true)

	var scale := MINIMAP_SIZE / MAP_IMAGE_SIZE
	var cell := Vector2(SECTOR_PIXELS, SECTOR_PIXELS) * scale
	for key in available_sectors:
		var s: Vector2i = available_sectors[key]
		var top_left := Vector2(s.x * SECTOR_PIXELS, s.y * SECTOR_PIXELS) * scale
		minimap.draw_rect(Rect2(top_left, cell), Color(0.2, 0.8, 0.35, 0.45), true)

	if current_sector.x >= 0:
		var cur := Vector2(current_sector.x * SECTOR_PIXELS, current_sector.y * SECTOR_PIXELS) * scale
		minimap.draw_rect(Rect2(cur, cell), Color(1.0, 0.85, 0.1, 1.0), false, 2.0)

	minimap.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.85), false, 2.0)


func _on_minimap_gui_input(event: InputEvent) -> void:
	if traveling:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var scale := MINIMAP_SIZE / MAP_IMAGE_SIZE
		var px: Vector2 = event.position / scale
		var sec := Vector2i(int(px.x / SECTOR_PIXELS), int(px.y / SECTOR_PIXELS))
		if available_sectors.has(_sector_key(sec)):
			_travel_to_sector(sec)
		elif sector_label != null:
			sector_label.text = "Sector [%d, %d] sin datos" % [sec.x, sec.y]


func _travel_to_sector(sec: Vector2i) -> void:
	if traveling or terrain == null:
		return
	traveling = true
	_set_progress(10.0, "Cargando [%d, %d]..." % [sec.x, sec.y])
	await get_tree().process_frame

	var ok := _load_sector_terrain(sec)
	current_sector = sec
	_set_progress(60.0)
	await get_tree().process_frame
	await get_tree().process_frame

	if not ok:
		_set_progress(100.0, "Sector [%d, %d] sin datos" % [sec.x, sec.y])
		await get_tree().create_timer(0.4).timeout
		if progress_bar != null:
			progress_bar.visible = false
		traveling = false
		return

	_place_player_on_ground()
	_set_progress(100.0)
	await get_tree().create_timer(0.25).timeout

	if progress_bar != null:
		progress_bar.visible = false
	if sector_label != null:
		sector_label.text = _sector_caption(sec)
	if minimap != null:
		minimap.queue_redraw()
	traveling = false


func _set_progress(value: float, caption := "") -> void:
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.value = value
	if not caption.is_empty() and sector_label != null:
		sector_label.text = caption
