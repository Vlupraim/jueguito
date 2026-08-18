extends Node3D

# Preview caminable del terreno Terrain3D editado.
# Carga un sector guardado (res://data/terrain3d_edits/sector_X_Y) y deja
# caminar al personaje sobre la colision real para revisar texturas y forma.
# No es el juego final: es una herramienta de revision del art pass.

const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TEMP_DATA_DIR := "user://walk_preview_temp"
const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const GAMEPLAY_HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")
const OCEAN_WATER_SCENE := preload("res://scenes/world/water/ocean_water.tscn")
const TERRAIN_ASSETS := preload("res://assets/environment/terrain/jueguito_terrain_assets.tres")
const TERRAIN_MATERIAL := preload("res://assets/environment/terrain/jueguito_terrain_material.tres")
const LOCAL_MAP_TEXTURE_BUILDER := preload("res://scripts/ui/local_map_texture_builder.gd")
const WORLD_ATLAS_SURFACE := preload("res://scripts/ui/world_atlas_surface.gd")
const EDITABLE_HUD_MODULE_SCRIPT := preload("res://scripts/ui/editable_hud_module.gd")
const MINIMAP_FRAME_TEXTURE := preload("res://assets/ui/hud/runtime/minimap_frame_parchment.png")
const MAP_MENU_SHELL_TEXTURE := preload("res://assets/ui/hud/runtime/map_menu_shell.png")
const WORLD_ATLAS_SHELL_TEXTURE := preload("res://assets/ui/hud/runtime/world_atlas_shell.png")
const HUD_CLOSE_ICON := preload("res://assets/ui/icons/close.svg")
const HUD_ZOOM_IN_ICON := preload("res://assets/ui/icons/zoom_in.svg")
const HUD_ZOOM_OUT_ICON := preload("res://assets/ui/icons/zoom_out.svg")
const HUD_EXPAND_ICON := preload("res://assets/ui/icons/expand.svg")
const HUD_CENTER_ICON := preload("res://assets/ui/icons/center.svg")
const HUD_WORLD_ICON := preload("res://assets/ui/icons/world.svg")
const TUTORIAL_SECTOR := Vector2i(27, 30)
# La ilustracion maestra del atlas ubica estas dos celdas costeras al reves
# respecto de la grilla de datos. El intercambio conserva intactos tanto el
# arte como las coordenadas logicas usadas por terreno, guardado y portales.
const WORLD_MAP_ART_SECTOR_SWAPS := {
	Vector2i(27, 30): Vector2i(26, 30),
	Vector2i(26, 30): Vector2i(27, 30),
}
const TUTORIAL_SHIP_POSITION := Vector3(283.47443, 2.5446196, 181.37114)
const TUTORIAL_SPAWN_XZ := Vector2(283.47443, 210.57114)
const TUTORIAL_STAND_UP_ACTION := &"stand_up1"
const TUTORIAL_BLACK_SCREEN_SECONDS := 1.5
const TUTORIAL_FADE_IN_SECONDS := 4.0
const SECTOR_CONTENT_DIR := "res://scenes/world/sectors/handmade"

# Cada sector usa su propia referencia 2D. El atlas mundial queda reservado
# para una futura pantalla de viaje y nunca se muestra con Tab.
const LOCAL_MINIMAP_SIZE := Vector2(250.0, 190.0)
const LOCAL_MINIMAP_DIAMOND_HALF_SIZE := Vector2(112.0, 88.0)
const EXPANDED_LOCAL_MAP_SIZE := Vector2(760.0, 430.0)
const WORLD_MAP_TEXTURE_PATH := "res://assets/ui/maps/world_atlas_cartographic.png"
const WORLD_MAP_SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const WORLD_MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const WORLD_MAP_VIEW_SIZE := Vector2(720.0, 390.0)
const WORLD_MAP_REGION_VISIBLE_COLUMNS := 11.0
const MINIMAP_MARGIN := 12.0
const CAMERA_QUADRANT_YAWS := [45.0, 135.0, 225.0, 315.0]
## Franja de terreno que sigue renderizandose alrededor del area jugable para
## que la camara nunca revele el final real del sector. No precarga vecinos.
const SECTOR_VISUAL_BORDER := 48.0
const PORTAL_ENTRY_OVERLAP := 1.25
const PORTAL_BOUNDARY_DEPTH := 3.0
const MINIMAP_ZOOM_MIN := 1.0
const MINIMAP_ZOOM_MAX := 1.6
const CAMERA_PAN_MAX_DISTANCE := 30.0
const CAMERA_PAN_PIXELS_TO_WORLD := 0.006
const CAMERA_PAN_MIN_SCALE := 0.04
const CAMERA_PAN_MAX_SCALE := 0.4
const CAMERA_RECENTER_SPEED := 7.0

## Sector a previsualizar. Si no tiene ediciones guardadas, busca el primero que exista.
@export var sector := TUTORIAL_SECTOR
## Punto horizontal de respaldo si no se encuentra una region activa.
@export var spawn_xz := Vector2(512.0, 512.0)
## El texto tecnico puede reactivarse desde el Inspector cuando sea necesario.
@export var show_debug_hud := false

var terrain: Terrain3D
var player: CharacterBody3D
var ocean_water: OceanWater
var sector_content: Node3D
var spawn_position := Vector3.ZERO
var debug_label: Label
var saved_textures: Array = []  # respaldo de la lista de texturas para reconstruir el array

# Camara tactica hibrida: sigue al personaje, permite orbita libre y un
# desplazamiento temporal limitado para inspeccionar el entorno cercano.
var cam_pivot: Node3D
var cam_arm: SpringArm3D
var cam_yaw := 45.0
var cam_pitch := -55.0  # negativo = camara arriba mirando hacia abajo

# Mapa local del chunk actual.
var current_sector := Vector2i(-1, -1)
var available_sectors := {}  # "x,y" -> Vector2i
var local_minimap: Control
var expanded_local_minimap: Control
var regional_map_surface: Control
var expanded_map_backdrop: ColorRect
var local_minimap_texture: Texture2D
var expanded_map_texture: Texture2D
var local_map_texture_cache := {}
var expanded_map_zoom := 1.0
var expanded_map_pan := Vector2.ZERO
var expanded_map_dragging := false
var expanded_map_last_mouse := Vector2.ZERO
var map_legend_visible := false
var _last_minimap_player_xz := Vector2(INF, INF)
var local_minimap_tilt := 0.9
var local_minimap_zoom := 1.0
var map_marker_color := Color("f3cf55")
var map_customization_panel: Control
var minimap_ping_button: Button
var map_ping_mode := 0
var map_ping_uv := Vector2(-1.0, -1.0)
var progress_bar: ProgressBar
var sector_label: Label
var expanded_map_title_label: Label
var expanded_sector_label: Label
var expanded_map_status_label: Label
var expanded_region_info_label: Label
var traveling := false
var local_map_expanded := false
var inventory_is_visible := false
var camera_quadrant_index := 0
var camera_rotation_tween: Tween
var is_middle_mouse_dragging := false
var middle_mouse_is_panning := false
var camera_recenter_requested := false
var sector_portal_openings: Array[Dictionary] = []

# El mapa mundial es una vista separada del mapa local de Tab.
var world_map_backdrop: ColorRect
var world_map_canvas: Control
var world_map_surface: Control
var world_map_texture: Texture2D
var world_map_zoom := 1.0
var world_map_pan := Vector2.ZERO
var world_map_dragging := false
var world_map_last_mouse := Vector2.ZERO
var world_map_columns := 67
var world_map_rows := 38
var world_map_sector_pixels := 25.0
var world_map_hovered_sector := Vector2i(-1, -1)
var world_map_selected_sector := Vector2i(-1, -1)
var world_map_hover_label: Label
var world_map_info_label: Label
var world_map_info_card: PanelContainer
var world_map_drag_distance := 0.0
var gameplay_hud: CanvasLayer
var minimap_hud_module: Control
var tutorial_intro_active := false
var tutorial_intro_overlay: ColorRect


func _ready() -> void:
	CursorManager.set_cursor_mode(CursorManager.POINTING_HAND)
	cam_pitch = float(SettingsManager.get_setting("controls", "camera_pitch", -45.0))
	if not SettingsManager.setting_changed.is_connected(_on_setting_changed):
		SettingsManager.setting_changed.connect(_on_setting_changed)
	_apply_character_sector()
	tutorial_intro_active = (
		current_sector == TUTORIAL_SECTOR
		or sector == TUTORIAL_SECTOR
	) and GameManager.should_play_tutorial_intro
	if tutorial_intro_active:
		_setup_tutorial_intro_overlay()
	_setup_environment()
	if show_debug_hud:
		_setup_debug_hud()
	_setup_gameplay_hud()
	_scan_available_sectors()
	# Crear el jugador y activar su camara ANTES del terreno, para que Terrain3D
	# la encuentre en su primer frame y no detenga su procesamiento (quedaria invisible).
	_create_player()
	_setup_terrain()
	_setup_ocean()
	_setup_sector_content()
	_setup_minimap()
	await get_tree().process_frame
	_place_player_on_ground()
	if tutorial_intro_active:
		await _play_tutorial_intro()
	# Reasignar la camara ya en su posicion final, por si el clipmap no la seguia.
	var cam := _player_camera()
	if cam != null and terrain != null and terrain.has_method("set_camera"):
		terrain.set_camera(cam)
	var active_name := "NINGUNA"
	var active_cam := get_viewport().get_camera_3d()
	if active_cam != null:
		active_name = active_cam.name
	print("Terrain3DWalkPreview: camara activa = ", active_name)


func _exit_tree() -> void:
	CursorManager.reset_cursor()


func _apply_character_sector() -> void:
	if GameManager == null or GameManager.current_character.is_empty():
		return
	var requested_sector: Variant = GameManager.current_character.get("current_sector")
	if requested_sector is Vector2i:
		sector = requested_sector


func _process(delta: float) -> void:
	# Red de seguridad: si la colision aun no estaba lista y el personaje cayo, lo reponemos.
	if player != null and player.global_position.y < -120.0:
		player.global_position = spawn_position
		player.velocity = Vector3.ZERO
	_update_camera_recenter(delta)
	_update_debug_hud()
	_queue_local_minimap_redraw_if_needed()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if tutorial_intro_active:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				if mouse_event.double_click:
					is_middle_mouse_dragging = false
					middle_mouse_is_panning = false
					_request_camera_recenter()
					get_viewport().set_input_as_handled()
					return
				if camera_rotation_tween != null and camera_rotation_tween.is_valid():
					camera_rotation_tween.kill()
				is_middle_mouse_dragging = true
				middle_mouse_is_panning = Input.is_key_pressed(KEY_SHIFT)
				get_viewport().set_input_as_handled()
			else:
				if is_middle_mouse_dragging:
					is_middle_mouse_dragging = false
					if not middle_mouse_is_panning:
						SettingsManager.set_setting("controls", "camera_pitch", cam_pitch)
					middle_mouse_is_panning = false
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_middle_mouse_dragging:
		var motion := event as InputEventMouseMotion
		if middle_mouse_is_panning:
			_pan_camera(motion.relative)
		else:
			var sensitivity := 0.25 * float(SettingsManager.get_setting("controls", "camera_sensitivity", 1.0))
			cam_yaw = wrapf(cam_yaw + motion.relative.x * sensitivity, 0.0, 360.0)
			cam_pitch = clampf(cam_pitch + motion.relative.y * sensitivity, -60.0, -30.0)
			_apply_camera_angles()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_TAB:
			if world_map_backdrop != null and world_map_backdrop.visible:
				world_map_backdrop.visible = false
				local_map_expanded = true
				expanded_map_backdrop.visible = true
				_refresh_player_input_enabled()
			else:
				_toggle_local_map()
			get_viewport().set_input_as_handled()
		KEY_N:
			_open_regional_map()
			get_viewport().set_input_as_handled()
		KEY_M:
			_toggle_world_map()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if world_map_backdrop != null and world_map_backdrop.visible:
				_toggle_world_map()
				get_viewport().set_input_as_handled()
			elif local_map_expanded:
				_toggle_local_map()
				get_viewport().set_input_as_handled()
		KEY_C:
			_cycle_camera_quadrant()
			get_viewport().set_input_as_handled()
		KEY_F:
			_request_camera_recenter()
			get_viewport().set_input_as_handled()
		KEY_F4:
			toggle_fog()
			get_viewport().set_input_as_handled()


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
	if cam_arm != null:
		var zoom_label := "Dist"
		var zoom_value := cam_arm.spring_length
		var zoom_min := float(player.get("min_camera_distance")) if player != null else 0.0
		var zoom_max := float(player.get("max_camera_distance")) if player != null else 0.0
		if player != null and player.has_method("get_camera_zoom_value"):
			zoom_label = str(player.call("get_camera_zoom_label"))
			zoom_value = float(player.call("get_camera_zoom_value"))
			zoom_min = float(player.call("get_camera_zoom_min"))
			zoom_max = float(player.call("get_camera_zoom_max"))
		var camera_mode_label := "desconocida"
		if player != null and player.has_method("get_camera_mode_label"):
			camera_mode_label = str(player.call("get_camera_mode_label"))
		lines.append("%s zoom: %.1f / %.1f-%.1f | dist %.1f | yaw %.1f | pitch %.1f" % [
			zoom_label,
			zoom_value,
			zoom_min,
			zoom_max,
			cam_arm.spring_length,
			cam_yaw,
			cam_pitch,
		])
		var camera_offset := Vector2.ZERO
		if cam_pivot != null:
			camera_offset = Vector2(cam_pivot.position.x, cam_pivot.position.z)
		lines.append(
			"Modo camara: %s | yaw %.1f | offset %.1f m" % [
				camera_mode_label,
				cam_yaw,
				camera_offset.length(),
			]
		)
	if player != null:
		lines.append("Velocidad: %.1f caminar | %.1f correr | snap suelo Terrain3D" % [
			float(player.get("walk_speed")),
			float(player.get("sprint_speed")),
		])
		if ocean_water != null and terrain != null and terrain.data != null:
			var terrain_height := terrain.data.get_height(player.global_position)
			var water_info := ocean_water.get_water_info(player.global_position, terrain_height)
			lines.append("Agua: %s | profundidad %.2f m | nivel %.2f | celdas %d | espuma %d" % [
				String(water_info.get("state", "dry")),
				float(water_info.get("depth", 0.0)),
				float(water_info.get("water_level", ocean_water.water_level)),
				ocean_water.water_cell_count,
				ocean_water.shoreline_cell_count,
			])
	debug_label.text = "\n".join(lines)


var fog_enabled := true


func set_fog_enabled(enabled: bool) -> void:
	fog_enabled = enabled
	var world_env := get_node_or_null("Ambiente") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		world_env.environment.fog_enabled = enabled


func toggle_fog() -> void:
	set_fog_enabled(not fog_enabled)


func _setup_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

	var world_env := WorldEnvironment.new()
	world_env.name = "Ambiente"
	var env := Environment.new()

	# Cielo procedural cinemático equilibrado
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.48, 0.64)
	sky_material.sky_horizon_color = Color(0.64, 0.70, 0.78)
	sky_material.ground_bottom_color = Color(0.24, 0.26, 0.28)
	sky_material.ground_horizon_color = Color(0.55, 0.60, 0.66)
	sky_material.sun_angle_max = 30.0

	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Tonemapping ACES cinemático (suave)
	env.tonemap_mode = 3 # ToneMapper.TONEMAP_ACES
	env.tonemap_exposure = 0.98

	# Graduación de color equilibrada (50% menos sombría)
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.96
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.90

	# Niebla atmosférica sutil
	env.fog_enabled = fog_enabled
	env.fog_light_color = Color(0.58, 0.64, 0.72)
	env.fog_density = 0.0003
	env.fog_sky_affect = 0.3

	# Luz ambiental para rellenar sombras oscuras
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.78

	world_env.environment = env
	add_child(world_env)


func _setup_gameplay_hud() -> void:
	gameplay_hud = GAMEPLAY_HUD_SCENE.instantiate()
	gameplay_hud.name = "GameplayHUD"
	add_child(gameplay_hud)
	gameplay_hud.visible = not tutorial_intro_active
	gameplay_hud.inventory_visibility_changed.connect(_on_inventory_visibility_changed)
	gameplay_hud.hud_edit_mode_changed.connect(_on_hud_edit_mode_changed)
	var reset_button := gameplay_hud.find_child("Reset", true, false) as Button
	if reset_button != null:
		reset_button.pressed.connect(_reset_minimap_hud_layout)


func _on_hud_edit_mode_changed(enabled: bool) -> void:
	if minimap_hud_module != null:
		minimap_hud_module.call("set_edit_mode", enabled)


func _reset_minimap_hud_layout() -> void:
	if minimap_hud_module != null:
		minimap_hud_module.call("reset_layout")


func _on_inventory_visibility_changed(is_visible: bool) -> void:
	inventory_is_visible = is_visible
	_refresh_player_input_enabled()


func _refresh_player_input_enabled() -> void:
	if player != null and player.has_method("set_gameplay_input_enabled"):
		player.call(
			"set_gameplay_input_enabled",
			not inventory_is_visible and not local_map_expanded and not tutorial_intro_active
		)


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


func _setup_ocean() -> void:
	ocean_water = OCEAN_WATER_SCENE.instantiate() as OceanWater
	ocean_water.name = "OceanWater"
	add_child(ocean_water)
	var has_water := ocean_water.configure_for_sector(current_sector, terrain)
	print(
		"Terrain3DWalkPreview: oceano sector ",
		current_sector,
		" | agua=", has_water,
		" | celdas=", ocean_water.water_cell_count,
		" | colliders=", ocean_water.water_collision_shape_count
	)


func _setup_sector_content() -> void:
	if sector_content != null:
		remove_child(sector_content)
		sector_content.queue_free()
		sector_content = null
	var content_path := SECTOR_CONTENT_DIR + "/sector_%d_%d.tscn" % [current_sector.x, current_sector.y]
	if not ResourceLoader.exists(content_path):
		return
	var content_scene := load(content_path) as PackedScene
	if content_scene == null:
		push_warning("Terrain3DWalkPreview: contenido invalido para sector " + str(current_sector))
		return
	sector_content = content_scene.instantiate() as Node3D
	sector_content.name = "SectorContent"
	add_child(sector_content)
	print("Terrain3DWalkPreview: contenido artesanal sector ", current_sector)


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
	if tutorial_intro_active and player.has_method("set_gameplay_input_enabled"):
		player.call("set_gameplay_input_enabled", false)
	if gameplay_hud != null and gameplay_hud.has_method("bind_player"):
		gameplay_hud.call("bind_player", player)
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


func _pan_camera(mouse_delta: Vector2) -> void:
	if cam_pivot == null:
		return
	var active_camera := _player_camera()
	if active_camera == null:
		return
	var right := active_camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -active_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var zoom_value := 18.0
	if player != null and player.has_method("get_camera_zoom_value"):
		zoom_value = float(player.call("get_camera_zoom_value"))
	var pan_scale := clampf(
		zoom_value * CAMERA_PAN_PIXELS_TO_WORLD,
		CAMERA_PAN_MIN_SCALE,
		CAMERA_PAN_MAX_SCALE
	)
	var pan_delta := (-right * mouse_delta.x + forward * mouse_delta.y) * pan_scale
	var next_offset := Vector2(cam_pivot.position.x + pan_delta.x, cam_pivot.position.z + pan_delta.z)
	next_offset = next_offset.limit_length(CAMERA_PAN_MAX_DISTANCE)
	cam_pivot.position.x = next_offset.x
	cam_pivot.position.z = next_offset.y
	camera_recenter_requested = false


func _request_camera_recenter() -> void:
	camera_recenter_requested = true


func _update_camera_recenter(delta: float) -> void:
	if cam_pivot == null or is_middle_mouse_dragging:
		return
	var player_is_moving := player != null and Vector2(player.velocity.x, player.velocity.z).length_squared() > 0.01
	if player_is_moving:
		camera_recenter_requested = true
	if not camera_recenter_requested:
		return
	var weight := 1.0 - exp(-CAMERA_RECENTER_SPEED * delta)
	cam_pivot.position.x = lerpf(cam_pivot.position.x, 0.0, weight)
	cam_pivot.position.z = lerpf(cam_pivot.position.z, 0.0, weight)
	if Vector2(cam_pivot.position.x, cam_pivot.position.z).length_squared() < 0.0001:
		cam_pivot.position.x = 0.0
		cam_pivot.position.z = 0.0
		camera_recenter_requested = false


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "controls" and key == "camera_pitch":
		cam_pitch = clampf(float(value), -60.0, -30.0)
		_apply_camera_angles()


func _cycle_camera_quadrant() -> void:
	cam_pitch = float(SettingsManager.get_setting("controls", "camera_pitch", -45.0))
	_apply_camera_angles()
	camera_quadrant_index = wrapi(camera_quadrant_index + 1, 0, CAMERA_QUADRANT_YAWS.size())
	var target_yaw := float(CAMERA_QUADRANT_YAWS[camera_quadrant_index])
	var current_yaw := cam_yaw
	while target_yaw <= current_yaw:
		target_yaw += 360.0
	if camera_rotation_tween != null and camera_rotation_tween.is_valid():
		camera_rotation_tween.kill()
	camera_rotation_tween = create_tween()
	camera_rotation_tween.set_trans(Tween.TRANS_SINE)
	camera_rotation_tween.set_ease(Tween.EASE_IN_OUT)
	camera_rotation_tween.tween_method(Callable(self, "_set_camera_yaw"), current_yaw, target_yaw, 0.22)
	camera_rotation_tween.tween_callback(Callable(self, "_finish_camera_quadrant").bind(target_yaw))
	if local_minimap != null:
		local_minimap.queue_redraw()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func _set_camera_yaw(next_yaw: float) -> void:
	cam_yaw = next_yaw
	if cam_pivot != null:
		cam_pivot.rotation_degrees.y = cam_yaw


func _finish_camera_quadrant(target_yaw: float) -> void:
	_set_camera_yaw(target_yaw)
	if local_minimap != null:
		local_minimap.queue_redraw()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func get_player_ground_info(requested_position: Vector3) -> Dictionary:
	if terrain == null or terrain.data == null:
		return {"walkable": false}
	if not _is_position_inside_sector_or_portal(Vector2(requested_position.x, requested_position.z)):
		return {"walkable": false, "reason": "limite_sector"}
	var platform_info := _walkable_ship_surface_info(requested_position)
	if not platform_info.is_empty():
		return platform_info
	var terrain_height := terrain.data.get_height(Vector3(requested_position.x, 0.0, requested_position.z))
	if is_nan(terrain_height):
		return {"walkable": false}
	var water_info := {"in_water": false, "state": "dry"}
	if ocean_water != null:
		water_info = ocean_water.get_water_info(requested_position, terrain_height)
	return {
		"walkable": true,
		"position": Vector3(requested_position.x, terrain_height, requested_position.z),
		"water": water_info,
	}


func _sector_walkable_bounds() -> Rect2:
	return _sector_visual_bounds().grow(-SECTOR_VISUAL_BORDER)


func _sector_visual_bounds() -> Rect2:
	if ocean_water != null:
		return ocean_water.sector_bounds
	return Rect2(Vector2.ZERO, Vector2(512.0, 512.0))


func _is_position_inside_sector_or_portal(world_xz: Vector2) -> bool:
	var bounds := _sector_walkable_bounds()
	if bounds.has_point(world_xz):
		return true
	for opening in sector_portal_openings:
		if _portal_opening_contains(opening, world_xz, bounds):
			return true
	return false


func _portal_opening_contains(opening: Dictionary, world_xz: Vector2, bounds: Rect2) -> bool:
	var side := String(opening.get("side", "")).to_upper()
	var center := float(opening.get("center", 0.0))
	var half_width := maxf(float(opening.get("width", 0.0)) * 0.5, 0.0)
	match side:
		"N":
			return absf(world_xz.x - center) <= half_width \
				and world_xz.y >= bounds.position.y - PORTAL_BOUNDARY_DEPTH \
				and world_xz.y <= bounds.position.y + PORTAL_ENTRY_OVERLAP
		"E":
			return absf(world_xz.y - center) <= half_width \
				and world_xz.x >= bounds.end.x - PORTAL_ENTRY_OVERLAP \
				and world_xz.x <= bounds.end.x + PORTAL_BOUNDARY_DEPTH
		"S":
			return absf(world_xz.x - center) <= half_width \
				and world_xz.y >= bounds.end.y - PORTAL_ENTRY_OVERLAP \
				and world_xz.y <= bounds.end.y + PORTAL_BOUNDARY_DEPTH
		"O", "W":
			return absf(world_xz.y - center) <= half_width \
				and world_xz.x >= bounds.position.x - PORTAL_BOUNDARY_DEPTH \
				and world_xz.x <= bounds.position.x + PORTAL_ENTRY_OVERLAP
	return false


func register_sector_portal_opening(
	side: String,
	center: float,
	width: float,
	target_sector := Vector2i(-1, -1),
	portal_id := ""
) -> void:
	var normalized_side := side.to_upper()
	if normalized_side == "W":
		normalized_side = "O"
	if not normalized_side in ["N", "E", "S", "O"] or width <= 0.0:
		push_warning("Portal de sector ignorado: lado o ancho invalido.")
		return
	sector_portal_openings.append({
		"side": normalized_side,
		"center": center,
		"width": width,
		"target_sector": target_sector,
		"portal_id": portal_id,
	})
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func clear_sector_portal_openings() -> void:
	sector_portal_openings.clear()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func _walkable_ship_surface_info(requested_position: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return {}
	var ray_start := Vector3(requested_position.x, 80.0, requested_position.z)
	var ray_end := Vector3(requested_position.x, -80.0, requested_position.z)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 8)
	if player != null:
		query.exclude = [player.get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Object = result.get("collider")
	if not (collider is Node) or not (collider as Node).is_in_group("walkable_ship_surface"):
		return {}
	var surface_node := collider as Node
	var hit_position: Vector3 = result.get("position", requested_position)
	return {
		"walkable": true,
		"position": Vector3(requested_position.x, hit_position.y, requested_position.z),
		"water": {"in_water": false, "state": "dry"},
		"platform_id": String(surface_node.get_meta("platform_id", "")),
		"surface_role": String(surface_node.get_meta("surface_role", "deck")),
	}


func _place_player_on_ground() -> void:
	if player == null:
		return
	var ground_xz := _find_ground_xz()
	var ground_y := 5.0
	if terrain != null and terrain.data != null:
		var sampled := terrain.data.get_height(Vector3(ground_xz.x, 0.0, ground_xz.y))
		if not is_nan(sampled):
			var clearance := float(player.get("ground_clearance")) if current_sector == TUTORIAL_SECTOR else 3.0
			ground_y = sampled + clearance
	spawn_position = Vector3(ground_xz.x, ground_y, ground_xz.y)
	player.global_position = spawn_position
	if player.has_method("mark_safe_position"):
		player.call("mark_safe_position")
	if current_sector == TUTORIAL_SECTOR and player.has_method("face_world_position"):
		player.call("face_world_position", _tutorial_ship_world_position())
	print("Terrain3DWalkPreview: jugador en ", spawn_position.round())


# Busca el centro de la region activa con la tierra mas alta, para aparecer sobre
# terreno solido (no en el agua) y dentro del area cargada del sector.
func _find_ground_xz() -> Vector2:
	if terrain == null or terrain.data == null:
		return spawn_xz
	if current_sector == TUTORIAL_SECTOR:
		return _find_tutorial_spawn_xz()
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


func _find_tutorial_spawn_xz() -> Vector2:
	# Busca arena seca alrededor del punto elegido, por si una escultura posterior
	# de Terrain3D mueve ligeramente la orilla.
	var offsets := [
		Vector2.ZERO,
		Vector2(0.0, 4.0),
		Vector2(-4.0, 4.0),
		Vector2(4.0, 4.0),
		Vector2(0.0, 8.0),
		Vector2(-8.0, 8.0),
		Vector2(8.0, 8.0),
		Vector2(0.0, 14.0),
	]
	var authored_spawn := _tutorial_spawn_xz()
	for offset: Vector2 in offsets:
		var candidate := authored_spawn + offset
		var height := terrain.data.get_height(Vector3(candidate.x, 0.0, candidate.y))
		if is_nan(height):
			continue
		if ocean_water == null:
			return candidate
		var water_info := ocean_water.get_water_info(Vector3(candidate.x, height, candidate.y), height)
		if String(water_info.get("state", "dry")) == "dry":
			return candidate
	return authored_spawn


func _tutorial_spawn_xz() -> Vector2:
	if sector_content != null:
		var marker := sector_content.find_child("TutorialSpawn", true, false) as Node3D
		if marker != null:
			return Vector2(marker.global_position.x, marker.global_position.z)
	return TUTORIAL_SPAWN_XZ


func _tutorial_ship_world_position() -> Vector3:
	if sector_content != null:
		var ship := sector_content.find_child("destroyed_ship", true, false) as Node3D
		if ship != null:
			return ship.global_position
	return TUTORIAL_SHIP_POSITION


func _setup_tutorial_intro_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TutorialIntroLayer"
	layer.layer = 100
	add_child(layer)
	tutorial_intro_overlay = ColorRect.new()
	tutorial_intro_overlay.name = "BlackFade"
	tutorial_intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_intro_overlay.color = Color.BLACK
	tutorial_intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(tutorial_intro_overlay)


func _play_tutorial_intro() -> void:
	if player == null or tutorial_intro_overlay == null:
		tutorial_intro_active = false
		return
	player.call("hold_character_action_pose", TUTORIAL_STAND_UP_ACTION, 0.0)
	await get_tree().create_timer(TUTORIAL_BLACK_SCREEN_SECONDS).timeout
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(
		tutorial_intro_overlay,
		"color:a",
		0.0,
		TUTORIAL_FADE_IN_SECONDS
	)
	await fade.finished
	tutorial_intro_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stand_duration := float(player.call(
		"get_character_action_duration",
		TUTORIAL_STAND_UP_ACTION
	))
	if bool(player.call("play_character_action", TUTORIAL_STAND_UP_ACTION, 0.08)):
		await get_tree().create_timer(maxf(stand_duration, 0.1)).timeout
	tutorial_intro_active = false
	if gameplay_hud != null:
		gameplay_hud.visible = true
	if minimap_hud_module != null:
		minimap_hud_module.visible = true
	_refresh_player_input_enabled()
	GameManager.complete_tutorial_intro()
	var intro_layer := tutorial_intro_overlay.get_parent()
	intro_layer.queue_free()
	tutorial_intro_overlay = null


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
	_load_map_preferences()
	_load_local_minimap_texture()
	var layer := CanvasLayer.new()
	layer.name = "MinimapaUI"
	add_child(layer)

	minimap_hud_module = HBoxContainer.new()
	minimap_hud_module.name = "MinimapModule"
	minimap_hud_module.set_script(EDITABLE_HUD_MODULE_SCRIPT)
	minimap_hud_module.set("layout_key", "minimap")
	minimap_hud_module.set("default_normalized_position", Vector2(1.0, 0.0))
	minimap_hud_module.set("default_position_offset", Vector2(-12.0, 12.0))
	minimap_hud_module.custom_minimum_size = Vector2(292.0, 224.0)
	minimap_hud_module.add_theme_constant_override("separation", 6)
	minimap_hud_module.visible = not tutorial_intro_active
	layer.add_child(minimap_hud_module)

	var box := VBoxContainer.new()
	box.name = "CartografiaLocal"
	box.add_theme_constant_override("separation", 2)
	minimap_hud_module.add_child(box)

	var minimap_panel := PanelContainer.new()
	minimap_panel.name = "MarcoMapaLocal"
	minimap_panel.add_theme_stylebox_override(
		"panel",
		_make_map_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	)
	box.add_child(minimap_panel)
	var minimap_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		minimap_margin.add_theme_constant_override(side, 6)
	minimap_panel.add_child(minimap_margin)

	local_minimap = Control.new()
	local_minimap.name = "MapaLocal"
	local_minimap.custom_minimum_size = LOCAL_MINIMAP_SIZE
	local_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	local_minimap.clip_contents = true
	local_minimap.tooltip_text = "Mapa local del sector actual"
	local_minimap.draw.connect(_on_local_minimap_draw)
	minimap_margin.add_child(local_minimap)

	# Controles compactos al borde del minimapa, como una herramienta del HUD.
	# El zoom minimo es la vista completa: nunca deja alejarse mas que el encuadre base.
	var minimap_controls := VBoxContainer.new()
	minimap_controls.name = "ControlesMapaLocal"
	minimap_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	minimap_controls.add_theme_constant_override("separation", 4)
	minimap_hud_module.add_child(minimap_controls)
	var minimap_zoom_in := Button.new()
	minimap_zoom_in.name = "AcercarMapaLocal"
	minimap_zoom_in.icon = HUD_ZOOM_IN_ICON
	minimap_zoom_in.expand_icon = true
	minimap_zoom_in.add_theme_constant_override("icon_max_width", 18)
	minimap_zoom_in.tooltip_text = "Acercar el minimapa"
	minimap_zoom_in.custom_minimum_size = Vector2(34.0, 32.0)
	_style_minimap_edge_button(minimap_zoom_in)
	minimap_zoom_in.pressed.connect(_change_local_minimap_zoom.bind(0.15))
	minimap_controls.add_child(minimap_zoom_in)
	var minimap_zoom_out := Button.new()
	minimap_zoom_out.name = "AlejarMapaLocal"
	minimap_zoom_out.icon = HUD_ZOOM_OUT_ICON
	minimap_zoom_out.expand_icon = true
	minimap_zoom_out.add_theme_constant_override("icon_max_width", 18)
	minimap_zoom_out.tooltip_text = "Alejar hasta mostrar el chunk completo"
	minimap_zoom_out.custom_minimum_size = Vector2(34.0, 32.0)
	_style_minimap_edge_button(minimap_zoom_out)
	minimap_zoom_out.pressed.connect(_change_local_minimap_zoom.bind(-0.15))
	minimap_controls.add_child(minimap_zoom_out)
	var minimap_expand := Button.new()
	minimap_expand.name = "ExpandirMapaLocal"
	minimap_expand.icon = HUD_EXPAND_ICON
	minimap_expand.expand_icon = true
	minimap_expand.add_theme_constant_override("icon_max_width", 18)
	minimap_expand.tooltip_text = "Expandir el mapa"
	minimap_expand.custom_minimum_size = Vector2(34.0, 32.0)
	_style_minimap_edge_button(minimap_expand)
	minimap_expand.pressed.connect(_open_regional_map)
	minimap_controls.add_child(minimap_expand)

	var name_plate := PanelContainer.new()
	name_plate.name = "NombreAreaLocal"
	name_plate.add_theme_stylebox_override(
		"panel",
		_make_map_style(Color("ded2b9f2"), Color("75654ae6"), 4, 5)
	)
	box.add_child(name_plate)
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 12)
	name_margin.add_theme_constant_override("margin_right", 12)
	name_margin.add_theme_constant_override("margin_top", 3)
	name_margin.add_theme_constant_override("margin_bottom", 3)
	name_plate.add_child(name_margin)
	sector_label = Label.new()
	sector_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sector_label.add_theme_color_override("font_color", Color("302b24"))
	sector_label.add_theme_font_size_override("font_size", 13)
	sector_label.text = _location_caption(current_sector)
	name_margin.add_child(sector_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(LOCAL_MINIMAP_SIZE.x, 16.0)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	box.add_child(progress_bar)

	expanded_map_backdrop = ColorRect.new()
	expanded_map_backdrop.name = "MapaLocalAmpliado"
	expanded_map_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expanded_map_backdrop.color = Color(0.015, 0.022, 0.03, 0.88)
	expanded_map_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	expanded_map_backdrop.visible = false
	layer.add_child(expanded_map_backdrop)
	_add_map_menu_shell(expanded_map_backdrop, MAP_MENU_SHELL_TEXTURE, "CarcasaMapaRegional")

	var center := MarginContainer.new()
	center.name = "MargenPantallaMapaRegional"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 20)
	center.add_theme_constant_override("margin_top", 14)
	center.add_theme_constant_override("margin_right", 20)
	center.add_theme_constant_override("margin_bottom", 14)
	expanded_map_backdrop.add_child(center)
	var expanded_panel := PanelContainer.new()
	expanded_panel.name = "PanelMapaLocal"
	expanded_panel.add_theme_stylebox_override(
		"panel", _make_map_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	)
	center.add_child(expanded_panel)
	expanded_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expanded_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var expanded_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		expanded_margin.add_theme_constant_override(side, 0)
	expanded_panel.add_child(expanded_margin)
	var expanded_box := VBoxContainer.new()
	expanded_box.name = "ContenidoMapaLocal"
	expanded_box.add_theme_constant_override("separation", 8)
	expanded_margin.add_child(expanded_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 76.0
	header.add_theme_constant_override("separation", 12)
	expanded_box.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)
	expanded_map_title_label = Label.new()
	expanded_map_title_label.text = _location_caption(current_sector).to_upper()
	expanded_map_title_label.add_theme_font_size_override("font_size", 22)
	expanded_map_title_label.add_theme_color_override("font_color", Color("eee3c5"))
	title_box.add_child(expanded_map_title_label)
	expanded_sector_label = Label.new()
	expanded_sector_label.add_theme_font_size_override("font_size", 12)
	expanded_sector_label.add_theme_color_override("font_color", Color("aaa38f"))
	expanded_sector_label.text = "%s - %s" % [_location_caption(current_sector), _sector_caption(current_sector)]
	title_box.add_child(expanded_sector_label)
	_add_map_navigation_tabs(header, false)
	var close_button := Button.new()
	close_button.icon = HUD_CLOSE_ICON
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width", 27)
	close_button.tooltip_text = "Cerrar mapa (Tab)"
	close_button.custom_minimum_size = Vector2(40.0, 36.0)
	_style_map_button(close_button)
	close_button.pressed.connect(_toggle_local_map)
	header.add_child(close_button)

	var regional_body := HBoxContainer.new()
	regional_body.name = "CuerpoMapaRegional"
	regional_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	regional_body.add_theme_constant_override("separation", 12)
	expanded_box.add_child(regional_body)

	var regional_map_margin := MarginContainer.new()
	regional_map_margin.name = "HuecoMapaRegional"
	regional_map_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regional_map_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	regional_map_margin.add_theme_constant_override("margin_left", 26)
	regional_map_margin.add_theme_constant_override("margin_top", 10)
	regional_map_margin.add_theme_constant_override("margin_right", 24)
	regional_map_margin.add_theme_constant_override("margin_bottom", 22)
	regional_body.add_child(regional_map_margin)
	expanded_local_minimap = Control.new()
	expanded_local_minimap.name = "MapaDelChunk"
	expanded_local_minimap.custom_minimum_size = Vector2(640.0, 360.0)
	expanded_local_minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expanded_local_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expanded_local_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	expanded_local_minimap.mouse_default_cursor_shape = Control.CURSOR_DRAG
	expanded_local_minimap.clip_contents = true
	expanded_local_minimap.draw.connect(_on_expanded_local_minimap_draw)
	expanded_local_minimap.gui_input.connect(_on_expanded_map_gui_input)
	regional_map_margin.add_child(expanded_local_minimap)
	regional_map_surface = WORLD_ATLAS_SURFACE.new() as Control
	regional_map_surface.name = "SuperficieCartaRegional"
	regional_map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	regional_map_surface.show_behind_parent = true
	regional_map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expanded_local_minimap.add_child(regional_map_surface)
	regional_map_surface.call("set_relief_strength", 3.25)
	_configure_regional_map_surface()
	var regional_info_panel := PanelContainer.new()
	regional_info_panel.name = "InformacionMapaRegional"
	regional_info_panel.custom_minimum_size = Vector2(240.0, 0.0)
	regional_info_panel.add_theme_stylebox_override(
		"panel", _make_map_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	)
	regional_body.add_child(regional_info_panel)
	var regional_info_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		regional_info_margin.add_theme_constant_override(side, 14)
	regional_info_panel.add_child(regional_info_margin)
	var regional_info_box := VBoxContainer.new()
	regional_info_box.add_theme_constant_override("separation", 10)
	regional_info_margin.add_child(regional_info_box)
	var regional_info_title := Label.new()
	regional_info_title.text = "REGION ACTUAL"
	regional_info_title.add_theme_font_size_override("font_size", 11)
	regional_info_title.add_theme_color_override("font_color", Color("c5b27e"))
	regional_info_box.add_child(regional_info_title)
	expanded_region_info_label = Label.new()
	expanded_region_info_label.text = "%s\n%s\n\nCarta cargada desde el terreno real del sector." % [
		_location_caption(current_sector), _sector_caption(current_sector)
	]
	expanded_region_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expanded_region_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expanded_region_info_label.add_theme_color_override("font_color", Color("ded5bf"))
	regional_info_box.add_child(expanded_region_info_label)
	var regional_shortcuts := Label.new()
	regional_shortcuts.text = "TAB  Cerrar\nM  Atlas mundial\nDoble clic  Ping\nRueda  Zoom"
	regional_shortcuts.add_theme_font_size_override("font_size", 11)
	regional_shortcuts.add_theme_color_override("font_color", Color("918b7b"))
	regional_info_box.add_child(regional_shortcuts)

	var tools_row := HBoxContainer.new()
	tools_row.name = "HerramientasMapaRegional"
	tools_row.custom_minimum_size.y = 54.0
	tools_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_row.add_theme_constant_override("separation", 5)
	expanded_box.add_child(tools_row)
	var center_button := _add_map_tool_button(
		tools_row, "Centrar", "Volver al encuadre inicial", _center_expanded_map
	)
	center_button.icon = HUD_CENTER_ICON
	center_button.expand_icon = true
	center_button.add_theme_constant_override("icon_max_width", 18)
	_add_map_tool_button(tools_row, "Ping", "Marcar una posicion para el grupo", _set_map_ping_mode.bind(0))
	_add_map_tool_button(tools_row, "Ataque", "Ping tactico de ataque", _set_map_ping_mode.bind(1))
	_add_map_tool_button(tools_row, "Defensa", "Ping tactico de defensa", _set_map_ping_mode.bind(2))

	var interaction_hint := Label.new()
	interaction_hint.text = "Arrastrar · rueda para zoom"
	interaction_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_hint.add_theme_font_size_override("font_size", 11)
	interaction_hint.add_theme_color_override("font_color", Color("918b7b"))
	tools_row.add_child(interaction_hint)
	expanded_map_status_label = Label.new()
	expanded_map_status_label.text = "Carta ilustrada"
	expanded_map_status_label.add_theme_font_size_override("font_size", 11)
	expanded_map_status_label.add_theme_color_override("font_color", Color("c5b27e"))
	tools_row.add_child(expanded_map_status_label)
	var zoom_out := Button.new()
	zoom_out.icon = HUD_ZOOM_OUT_ICON
	zoom_out.expand_icon = true
	zoom_out.add_theme_constant_override("icon_max_width", 19)
	zoom_out.custom_minimum_size = Vector2(40.0, 38.0)
	zoom_out.tooltip_text = "Alejar"
	_style_map_button(zoom_out)
	zoom_out.pressed.connect(_change_expanded_map_zoom.bind(-0.15))
	tools_row.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.icon = HUD_ZOOM_IN_ICON
	zoom_in.expand_icon = true
	zoom_in.add_theme_constant_override("icon_max_width", 19)
	zoom_in.custom_minimum_size = Vector2(40.0, 38.0)
	zoom_in.tooltip_text = "Acercar"
	_style_map_button(zoom_in)
	zoom_in.pressed.connect(_change_expanded_map_zoom.bind(0.15))
	tools_row.add_child(zoom_in)
	var legend_button := Button.new()
	legend_button.text = "Leyenda"
	legend_button.tooltip_text = "Mostrar u ocultar leyenda"
	_style_map_button(legend_button)
	legend_button.pressed.connect(_toggle_map_legend)
	tools_row.add_child(legend_button)
	var world_button := Button.new()
	world_button.text = "Mundo"
	world_button.icon = HUD_WORLD_ICON
	world_button.expand_icon = true
	world_button.add_theme_constant_override("icon_max_width", 18)
	world_button.tooltip_text = "Abrir el mapa general"
	_style_map_button(world_button)
	world_button.pressed.connect(_toggle_world_map)
	tools_row.add_child(world_button)

	_setup_map_customization(layer)
	_setup_world_map_overlay(layer)
	_update_regional_map_info(current_sector)
	if _regional_map_surface_active():
		_set_map_status("Carta regional ilustrada")

	local_minimap.queue_redraw()
	expanded_local_minimap.queue_redraw()


func _make_map_style(background: Color, border: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = shadow_size
	return style


func _add_map_menu_shell(backdrop: Control, texture: Texture2D, shell_name: String) -> void:
	var shell := TextureRect.new()
	shell.name = shell_name
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.texture = texture
	shell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shell.stretch_mode = TextureRect.STRETCH_SCALE
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(shell)


func _style_map_button(button: Button) -> void:
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("ddd2b5"))
	button.add_theme_color_override("font_hover_color", Color("fff1c9"))
	var normal := _make_map_style(Color("11130fe6"), Color("5f5035d9"), 5, 0)
	var hover := _make_map_style(Color("29251bed"), Color("b99b59f2"), 5, 0)
	var pressed := _make_map_style(Color("0c0e0ce8"), Color("d8bd72f2"), 5, 0)
	for style in [normal, hover, pressed]:
		style.content_margin_left = 12.0
		style.content_margin_top = 7.0
		style.content_margin_right = 12.0
		style.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)


func _style_minimap_edge_button(button: Button) -> void:
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("d8c891"))
	button.add_theme_color_override("font_hover_color", Color("fff0b5"))
	button.add_theme_stylebox_override(
		"normal", _make_map_style(Color("171914d9"), Color("746444b8"), 5, 0)
	)
	button.add_theme_stylebox_override(
		"hover", _make_map_style(Color("2b291feb"), Color("c3a45edb"), 5, 0)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_map_style(Color("0f100de8"), Color("e0c475eb"), 5, 0)
	)


func _style_map_tab_button(button: Button, active: bool) -> void:
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f1dfad") if active else Color("b8b3a4"))
	button.add_theme_color_override("font_hover_color", Color("fff1c9"))
	button.add_theme_stylebox_override(
		"normal",
		_make_map_style(
			Color("443a29ed") if active else Color("202428e6"),
			Color("c4a55ee6") if active else Color("625b4cb3"),
			5,
			0
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_map_style(Color("514631f5"), Color("d4b86fe6"), 5, 0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_map_style(Color("332d24f5"), Color("ead08ee6"), 5, 0)
	)


func _add_map_navigation_tabs(parent: Control, world_active: bool, compact := false) -> void:
	var sector_tab := Button.new()
	sector_tab.name = "PestanaSector"
	sector_tab.text = "SECTOR"
	sector_tab.tooltip_text = "Abrir la carta regional (Tab)"
	sector_tab.custom_minimum_size = Vector2(122.0 if compact else 116.0, 30.0 if compact else 34.0)
	sector_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	_style_map_tab_button(sector_tab, not world_active)
	sector_tab.pressed.connect(_open_regional_map)
	parent.add_child(sector_tab)

	var world_tab := Button.new()
	world_tab.name = "PestanaMundo"
	world_tab.text = "MUNDO"
	world_tab.tooltip_text = "Abrir el atlas territorial (M)"
	world_tab.custom_minimum_size = Vector2(122.0 if compact else 116.0, 30.0 if compact else 34.0)
	world_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	_style_map_tab_button(world_tab, world_active)
	if not world_active:
		world_tab.pressed.connect(_toggle_world_map)
	parent.add_child(world_tab)


func _add_map_tool_button(
	parent: Control,
	caption: String,
	tooltip: String,
	callback: Callable,
	disabled := false
) -> Button:
	var button := Button.new()
	button.name = caption.replace(" ", "")
	button.text = caption
	button.tooltip_text = tooltip
	button.disabled = disabled
	_style_map_button(button)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _load_map_preferences() -> void:
	var saved_color: Variant = SettingsManager.get_setting("map", "marker_color", Color("f3cf55"))
	map_marker_color = saved_color if saved_color is Color else Color(String(saved_color))
	local_minimap_tilt = clampf(float(SettingsManager.get_setting("map", "tilt", 0.9)), 0.72, 1.0)
	local_minimap_zoom = clampf(
		float(SettingsManager.get_setting("map", "minimap_zoom", MINIMAP_ZOOM_MIN)),
		MINIMAP_ZOOM_MIN,
		MINIMAP_ZOOM_MAX
	)


func _setup_map_customization(parent: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.name = "PersonalizacionMapa"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = MINIMAP_MARGIN + LOCAL_MINIMAP_SIZE.x + 58.0
	panel.offset_top = MINIMAP_MARGIN + 24.0
	panel.add_theme_stylebox_override(
		"panel",
		_make_map_style(Color("202326f0"), Color("76684cb3"), 7, 0)
	)
	parent.add_child(panel)
	map_customization_panel = panel

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	panel.add_child(margin)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var tilt_label := Label.new()
	tilt_label.text = "Inclinacion"
	tilt_label.add_theme_color_override("font_color", Color("cfc5aa"))
	row.add_child(tilt_label)
	var tilt_slider := HSlider.new()
	tilt_slider.name = "Inclinacion"
	tilt_slider.custom_minimum_size = Vector2(140.0, 28.0)
	tilt_slider.min_value = 0.72
	tilt_slider.max_value = 1.0
	tilt_slider.step = 0.02
	tilt_slider.value = local_minimap_tilt
	tilt_slider.tooltip_text = "Aplana o abre solo el minimapa del HUD"
	tilt_slider.value_changed.connect(_set_map_tilt)
	row.add_child(tilt_slider)

	var color_picker := ColorPickerButton.new()
	color_picker.name = "ColorPuntero"
	color_picker.text = "Color"
	color_picker.color = map_marker_color
	color_picker.edit_alpha = false
	color_picker.tooltip_text = "Cambiar el color del puntero"
	_style_map_button(color_picker)
	color_picker.color_changed.connect(_set_map_marker_color)
	row.add_child(color_picker)

	var reset_button := Button.new()
	reset_button.text = "Restablecer"
	reset_button.tooltip_text = "Volver a la presentacion recomendada"
	_style_map_button(reset_button)
	reset_button.pressed.connect(_reset_map_customization.bind(tilt_slider, color_picker))
	row.add_child(reset_button)


func _setup_world_map_overlay(layer: CanvasLayer) -> void:
	_load_world_map_grid_config()
	world_map_texture = load(WORLD_MAP_TEXTURE_PATH) as Texture2D
	world_map_backdrop = ColorRect.new()
	world_map_backdrop.name = "MapaMundial"
	world_map_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_map_backdrop.color = Color(0.01, 0.015, 0.022, 0.94)
	world_map_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map_backdrop.visible = false
	layer.add_child(world_map_backdrop)
	_add_map_menu_shell(world_map_backdrop, WORLD_ATLAS_SHELL_TEXTURE, "CarcasaAtlasMundial")

	var center := MarginContainer.new()
	center.name = "MargenPantallaAtlas"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 20)
	center.add_theme_constant_override("margin_top", 14)
	center.add_theme_constant_override("margin_right", 20)
	center.add_theme_constant_override("margin_bottom", 14)
	world_map_backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "PanelAtlasMundial"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", _make_map_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 0)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 76.0
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	var title := Label.new()
	title.text = "ATLAS DEL MUNDO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("eee3c5"))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Atlas territorial - %d x %d sectores de 5 km" % [world_map_columns, world_map_rows]
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("aaa38f"))
	title_box.add_child(subtitle)
	_add_map_navigation_tabs(header, true)
	var close_button := Button.new()
	close_button.icon = HUD_CLOSE_ICON
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width", 27)
	close_button.tooltip_text = "Volver al mapa local"
	_style_map_button(close_button)
	close_button.pressed.connect(_toggle_world_map)
	header.add_child(close_button)

	var world_body := HBoxContainer.new()
	world_body.name = "CuerpoAtlasMundial"
	world_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_body.add_theme_constant_override("separation", 12)
	content.add_child(world_body)

	var world_map_margin := MarginContainer.new()
	world_map_margin.name = "HuecoMapaMundial"
	world_map_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_margin.add_theme_constant_override("margin_left", 26)
	world_map_margin.add_theme_constant_override("margin_top", 10)
	world_map_margin.add_theme_constant_override("margin_right", 32)
	world_map_margin.add_theme_constant_override("margin_bottom", 22)
	world_body.add_child(world_map_margin)
	world_map_canvas = Control.new()
	world_map_canvas.name = "LienzoMapaMundial"
	world_map_canvas.custom_minimum_size = Vector2(640.0, 360.0)
	world_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_canvas.clip_contents = true
	world_map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	world_map_canvas.draw.connect(_on_world_map_draw)
	world_map_canvas.gui_input.connect(_on_world_map_gui_input)
	world_map_margin.add_child(world_map_canvas)
	world_map_surface = WORLD_ATLAS_SURFACE.new() as Control
	world_map_surface.name = "SuperficieAtlasIlustrado"
	world_map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map_surface.show_behind_parent = true
	world_map_canvas.add_child(world_map_surface)
	world_map_info_card = PanelContainer.new()
	world_map_info_card.name = "FichaTerritorioAtlas"
	world_map_info_card.visible = false
	world_map_info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map_info_card.anchor_left = 1.0
	world_map_info_card.anchor_right = 1.0
	world_map_info_card.offset_left = -286.0
	world_map_info_card.offset_top = 16.0
	world_map_info_card.offset_right = -16.0
	world_map_info_card.offset_bottom = 206.0
	world_map_info_card.add_theme_stylebox_override(
		"panel", _make_map_style(Color("171514eb"), Color("a68b5be6"), 8, 8)
	)
	world_map_canvas.add_child(world_map_info_card)
	var world_info_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		world_info_margin.add_theme_constant_override(side, 14)
	world_map_info_card.add_child(world_info_margin)
	var world_info_box := VBoxContainer.new()
	world_info_box.add_theme_constant_override("separation", 10)
	world_info_margin.add_child(world_info_box)
	var world_info_title := Label.new()
	world_info_title.text = "TERRITORIO SELECCIONADO"
	world_info_title.add_theme_font_size_override("font_size", 11)
	world_info_title.add_theme_color_override("font_color", Color("c5b27e"))
	world_info_box.add_child(world_info_title)
	world_map_info_label = Label.new()
	world_map_info_label.text = ""
	world_map_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_map_info_label.add_theme_color_override("font_color", Color("ded5bf"))
	world_info_box.add_child(world_map_info_label)

	var footer := HBoxContainer.new()
	footer.name = "HerramientasMapaMundial"
	footer.custom_minimum_size.y = 54.0
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(footer)
	var hint := Label.new()
	hint.text = "Desplaza el puntero para consultar cada territorio"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("918b7b"))
	footer.add_child(hint)
	world_map_hover_label = hint
	var current_region_button := _add_map_tool_button(
		footer, "Region actual", "Centrar el atlas en el jugador", _center_world_map_on_current_sector
	)
	current_region_button.icon = HUD_CENTER_ICON
	current_region_button.expand_icon = true
	current_region_button.add_theme_constant_override("icon_max_width", 18)
	_add_map_tool_button(footer, "Completo", "Mostrar el mundo entero", _reset_world_map_view)
	var zoom_out := Button.new()
	zoom_out.icon = HUD_ZOOM_OUT_ICON
	zoom_out.expand_icon = true
	zoom_out.add_theme_constant_override("icon_max_width", 19)
	zoom_out.custom_minimum_size = Vector2(40.0, 38.0)
	zoom_out.tooltip_text = "Alejar hasta ver el mundo completo"
	_style_map_button(zoom_out)
	zoom_out.pressed.connect(_change_world_map_zoom.bind(-0.2))
	footer.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.icon = HUD_ZOOM_IN_ICON
	zoom_in.expand_icon = true
	zoom_in.add_theme_constant_override("icon_max_width", 19)
	zoom_in.custom_minimum_size = Vector2(40.0, 38.0)
	zoom_in.tooltip_text = "Acercar"
	_style_map_button(zoom_in)
	zoom_in.pressed.connect(_change_world_map_zoom.bind(0.2))
	footer.add_child(zoom_in)


func _load_world_map_grid_config() -> void:
	if not FileAccess.file_exists(WORLD_MAP_SECTOR_DATA_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_MAP_SECTOR_DATA_PATH))
	if not (parsed is Dictionary):
		return
	var scale_value: Variant = (parsed as Dictionary).get("scale", {})
	if not (scale_value is Dictionary):
		return
	var scale := scale_value as Dictionary
	world_map_columns = maxi(int(scale.get("columns", world_map_columns)), 1)
	world_map_rows = maxi(int(scale.get("rows", world_map_rows)), 1)
	var meters_per_pixel := maxf(float(scale.get("meters_per_pixel", 200.0)), 0.001)
	var sector_side_meters := maxf(float(scale.get("sector_side_km", 5.0)) * 1000.0, 1.0)
	world_map_sector_pixels = sector_side_meters / meters_per_pixel


func _toggle_map_customization() -> void:
	if map_customization_panel != null:
		map_customization_panel.visible = not map_customization_panel.visible


func _center_expanded_map() -> void:
	expanded_map_zoom = 1.0
	expanded_map_pan = Vector2.ZERO
	_sync_regional_map_view()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func _cycle_map_ping_mode() -> void:
	_set_map_ping_mode((map_ping_mode + 1) % 3)


func _set_map_ping_mode(mode: int) -> void:
	map_ping_mode = clampi(mode, 0, 2)
	if expanded_local_minimap != null:
		expanded_local_minimap.mouse_default_cursor_shape = (
			Control.CURSOR_CROSS if map_ping_mode == 1 else Control.CURSOR_DRAG
		)
	if minimap_ping_button != null:
		minimap_ping_button.text = ["P", "A", "D"][map_ping_mode]
		minimap_ping_button.tooltip_text = [
			"Ping normal; pulsa para alternar ataque y defensa",
			"Ping de ataque activo",
			"Ping de defensa activo",
		][map_ping_mode]
	_set_map_status(["Ping normal", "Ping de ataque", "Ping de defensa"][map_ping_mode])


func _set_map_tilt(value: float) -> void:
	local_minimap_tilt = clampf(value, 0.72, 1.0)
	SettingsManager.set_setting("map", "tilt", local_minimap_tilt, false)
	_queue_all_map_redraws()


func _change_local_minimap_zoom(delta: float) -> void:
	local_minimap_zoom = clampf(
		local_minimap_zoom + delta,
		MINIMAP_ZOOM_MIN,
		MINIMAP_ZOOM_MAX
	)
	SettingsManager.set_setting("map", "minimap_zoom", local_minimap_zoom, false)
	if local_minimap != null:
		local_minimap.queue_redraw()


func _set_map_marker_color(color: Color) -> void:
	map_marker_color = color
	SettingsManager.set_setting("map", "marker_color", map_marker_color, false)
	_queue_all_map_redraws()


func _reset_map_customization(tilt_slider: HSlider, color_picker: ColorPickerButton) -> void:
	local_minimap_tilt = 0.9
	map_marker_color = Color("f3cf55")
	tilt_slider.value = local_minimap_tilt
	color_picker.color = map_marker_color
	SettingsManager.set_setting("map", "tilt", local_minimap_tilt, false)
	SettingsManager.set_setting("map", "marker_color", map_marker_color, false)
	_queue_all_map_redraws()


func _queue_all_map_redraws() -> void:
	if local_minimap != null:
		local_minimap.queue_redraw()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()
	if world_map_canvas != null:
		world_map_canvas.queue_redraw()


func _load_local_minimap_texture() -> void:
	local_minimap_texture = null
	expanded_map_texture = null
	if current_sector.x < 0:
		return
	var cache_key := _sector_key(current_sector)
	if local_map_texture_cache.has(cache_key):
		local_minimap_texture = local_map_texture_cache[cache_key]
		expanded_map_texture = local_minimap_texture
		return
	var surface_path := "%s/sector_%d_%d/surface_reference.png" % [
		TERRAIN3D_EXPORT_DIR,
		current_sector.x,
		current_sector.y,
	]
	var height_path := "%s/sector_%d_%d/height_preview.png" % [
		TERRAIN3D_EXPORT_DIR,
		current_sector.x,
		current_sector.y,
	]
	if not ResourceLoader.exists(surface_path):
		return
	var surface_texture := load(surface_path) as Texture2D
	var height_texture := load(height_path) as Texture2D if ResourceLoader.exists(height_path) else null
	local_minimap_texture = LOCAL_MAP_TEXTURE_BUILDER.build(surface_texture, height_texture)
	if local_minimap_texture == null:
		local_minimap_texture = surface_texture
	local_map_texture_cache[cache_key] = local_minimap_texture
	expanded_map_texture = local_minimap_texture


func _configure_regional_map_surface() -> void:
	if regional_map_surface == null:
		return
	var configured := expanded_map_texture != null
	regional_map_surface.visible = configured
	_sync_regional_map_view()
	if configured:
		_set_map_status("Carta regional ilustrada")


func _regional_map_surface_active() -> bool:
	return regional_map_surface != null \
		and regional_map_surface.visible \
		and expanded_map_texture != null


func _sync_regional_map_view() -> void:
	if regional_map_surface == null:
		return
	var map_size := _expanded_map_view_size()
	var scaled_size := map_size * expanded_map_zoom
	var rect := Rect2((map_size - scaled_size) * 0.5 + expanded_map_pan, scaled_size)
	regional_map_surface.call("set_view", expanded_map_texture, rect)


func _project_sector_map_uv(uv: Vector2, fallback_size: Vector2) -> Vector2:
	if _regional_map_surface_active():
		return regional_map_surface.call("project_uv", uv) as Vector2
	return uv * fallback_size


func _unproject_sector_map_position(position: Vector2, fallback_size: Vector2) -> Vector2:
	if _regional_map_surface_active():
		return regional_map_surface.call("unproject_point", position) as Vector2
	var untransformed := (
		(position - fallback_size * 0.5 - expanded_map_pan)
		/ expanded_map_zoom
		+ fallback_size * 0.5
	)
	return Vector2(
		clampf(untransformed.x / maxf(fallback_size.x, 1.0), 0.0, 1.0),
		clampf(untransformed.y / maxf(fallback_size.y, 1.0), 0.0, 1.0)
	)


func _update_regional_map_info(sec: Vector2i) -> void:
	if expanded_region_info_label == null:
		return
	var info: Dictionary = MapDataManager.get_sector_info(sec)
	var resources_text := PackedStringArray()
	var resources: Array = info.get("resources", []) as Array
	for index in range(mini(resources.size(), 3)):
		var resource: Dictionary = resources[index] as Dictionary
		resources_text.append(str(resource.get("name", "Recurso")))
	var resource_summary := ", ".join(resources_text)
	if resource_summary.is_empty():
		resource_summary = "Sin datos registrados"
	expanded_region_info_label.text = "%s\n%s · Grado %s\n%s\n\nRECURSOS\n%s\n\nCarta ilustrada a partir del terreno real." % [
		_location_caption(sec),
		str(info.get("biome_display", "Bioma sin registrar")),
		str(info.get("grade_roman", "I")),
		str(info.get("hazard_name", "Riesgo sin registrar")),
		resource_summary,
	]


func _sector_caption(sec: Vector2i) -> String:
	if sec.x < 0:
		return "Sin sector cargado"
	return "Sector [%d, %d]" % [sec.x, sec.y]


func _location_caption(sec: Vector2i) -> String:
	if sec == TUTORIAL_SECTOR:
		return "Costa del Naufragio"
	return _sector_caption(sec)


func _set_map_status(caption: String) -> void:
	if expanded_map_status_label != null:
		expanded_map_status_label.text = caption


func _on_local_minimap_draw() -> void:
	if local_minimap == null:
		return
	_draw_local_map(local_minimap, LOCAL_MINIMAP_SIZE, local_minimap_texture, false)


func _on_expanded_local_minimap_draw() -> void:
	if expanded_local_minimap == null:
		return
	_draw_local_map(expanded_local_minimap, _expanded_map_view_size(), expanded_map_texture, true)


func _expanded_map_view_size() -> Vector2:
	if expanded_local_minimap != null and expanded_local_minimap.size.x > 1.0:
		return expanded_local_minimap.size
	return EXPANDED_LOCAL_MAP_SIZE


func _world_map_view_size() -> Vector2:
	if world_map_canvas != null and world_map_canvas.size.x > 1.0:
		return world_map_canvas.size
	return WORLD_MAP_VIEW_SIZE


func _draw_local_map(target: Control, map_size: Vector2, texture: Texture2D, expanded: bool) -> void:
	var zoom := expanded_map_zoom if expanded else 1.0
	var pan := expanded_map_pan if expanded else Vector2.ZERO
	var scaled_size := map_size * zoom
	var rect := Rect2((map_size - scaled_size) * 0.5 + pan, scaled_size)
	if expanded:
		if _regional_map_surface_active():
			regional_map_surface.call("set_view", texture, rect)
		else:
			target.draw_rect(rect, Color(0.025, 0.04, 0.06, 0.96), true)
			if texture != null:
				target.draw_texture_rect(texture, rect, false)
	else:
		_draw_local_minimap_surface(target, map_size, texture)

	# Los pictogramas mantienen escala cartografica y no crecen con Tab.
	var visual_scale := 0.76 if expanded else 0.58

	if current_sector == TUTORIAL_SECTOR:
		var ship_position := _world_position_to_local_map(Vector3(
			TUTORIAL_SHIP_POSITION.x,
			TUTORIAL_SHIP_POSITION.y + 3.0,
			TUTORIAL_SHIP_POSITION.z
		), map_size, expanded)
		ship_position = _transform_expanded_map_point(ship_position, map_size, expanded)
		var boat_tilt := 1.0 if expanded else (
			LOCAL_MINIMAP_DIAMOND_HALF_SIZE.y * local_minimap_tilt
			/ LOCAL_MINIMAP_DIAMOND_HALF_SIZE.x
		)
		_draw_boat_minimap_marker(target, ship_position, visual_scale, boat_tilt)

	if player != null:
		var player_position := _world_position_to_local_map(player.global_position, map_size, expanded)
		player_position = _transform_expanded_map_point(player_position, map_size, expanded)
		var facing := Vector2(0.0, -1.0)
		if player.has_method("get_facing_direction_xz"):
			facing = player.call("get_facing_direction_xz")
		var marker_basis := _world_marker_basis(player.global_position, facing, map_size, expanded)
		_draw_player_minimap_marker(
			target,
			player_position,
			marker_basis.forward,
			marker_basis.side,
			visual_scale
		)

	_draw_map_ping(target, map_size, expanded)

	if expanded:
		_draw_chunk_exits(target, map_size)
		if map_legend_visible:
			_draw_map_legend(target)

		# Norte fijo y discreto: funciona como rotulo cartografico, no como cursor.
		target.draw_string(
			ThemeDB.fallback_font,
			Vector2(map_size.x - 28.0, 28.0),
			"N",
			HORIZONTAL_ALIGNMENT_CENTER,
			18.0,
			16,
			Color("f1e6c8")
		)
		target.draw_rect(Rect2(Vector2.ZERO, map_size), Color("9b8760"), false, 1.5 * visual_scale)


func _draw_local_minimap_surface(target: Control, map_size: Vector2, texture: Texture2D) -> void:
	var center := map_size * 0.5
	var half_size := Vector2(
		LOCAL_MINIMAP_DIAMOND_HALF_SIZE.x,
		LOCAL_MINIMAP_DIAMOND_HALF_SIZE.y * local_minimap_tilt
	)
	var points := PackedVector2Array([
		center + Vector2(0.0, -half_size.y),
		center + Vector2(half_size.x, 0.0),
		center + Vector2(0.0, half_size.y),
		center + Vector2(-half_size.x, 0.0),
	])
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(0.0, 6.0))
	target.draw_colored_polygon(shadow_points, Color(0.01, 0.015, 0.02, 0.62))
	if texture != null:
		var uv_half := Vector2.ONE * (0.5 / local_minimap_zoom)
		var uv_center := Vector2.ONE * 0.5
		target.draw_polygon(
			points,
			PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
			PackedVector2Array([
				uv_center + Vector2(-uv_half.x, -uv_half.y),
				uv_center + Vector2(uv_half.x, -uv_half.y),
				uv_center + Vector2(uv_half.x, uv_half.y),
				uv_center + Vector2(-uv_half.x, uv_half.y),
			]),
			texture
		)
	else:
		target.draw_colored_polygon(points, Color("5c6f55"))
	var closed_points := PackedVector2Array(points)
	closed_points.append(points[0])
	# El terreno sigue siendo dinamico; solo el marco procede del kit visual.
	# Una sombra neutra corta mantiene el pergamino legible sobre arena o nieve.
	if MINIMAP_FRAME_TEXTURE != null:
		var frame_rect := Rect2(
			center - Vector2(half_size.x + 10.0, half_size.y + 9.0),
			Vector2((half_size.x + 10.0) * 2.0, (half_size.y + 9.0) * 2.0)
		)
		target.draw_texture_rect(MINIMAP_FRAME_TEXTURE, frame_rect, false)
	else:
		target.draw_polyline(closed_points, Color("756246"), 11.0, true)
		target.draw_polyline(closed_points, Color("d7c39a"), 8.0, true)
		target.draw_polyline(closed_points, Color("f0e6cf"), 2.0, true)

	_draw_minimap_compass_indicators(target, center, half_size)


func _draw_minimap_compass_indicators(target: Control, center: Vector2, half_size: Vector2) -> void:
	# En proyeccion isometrica romboidal:
	# Arriba-Derecha = Norte (N)
	# Arriba-Izquierda = Oeste (O)
	# Abajo-Derecha = Este (E)
	# Abajo-Izquierda = Sur (S)
	var font := ThemeDB.fallback_font
	var font_size := 11
	var gold_color := Color("f5e6c4")
	var shadow_color := Color("1a140d")

	var cardinal_points := [
		{"label": "N", "pos": center + Vector2(half_size.x * 0.48, -half_size.y * 0.48) + Vector2(6, -6), "col": Color("ff6b6b")},
		{"label": "S", "pos": center + Vector2(-half_size.x * 0.48, half_size.y * 0.48) + Vector2(-12, 6), "col": gold_color},
		{"label": "E", "pos": center + Vector2(half_size.x * 0.48, half_size.y * 0.48) + Vector2(6, 6), "col": gold_color},
		{"label": "O", "pos": center + Vector2(-half_size.x * 0.48, -half_size.y * 0.48) + Vector2(-12, -6), "col": gold_color},
	]

	for cp in cardinal_points:
		var pos: Vector2 = cp["pos"]
		var label: String = cp["label"]
		var color: Color = cp["col"]
		target.draw_string(font, pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
		target.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _world_position_to_local_map(world_position: Vector3, map_size: Vector2, expanded: bool) -> Vector2:
	if not expanded:
		return _world_xz_to_diamond_minimap(Vector2(world_position.x, world_position.z), map_size)
	if _regional_map_surface_active():
		return _project_sector_map_uv(
			_world_xz_to_local_uv(Vector2(world_position.x, world_position.z)),
			map_size
		)
	return _world_xz_to_local_minimap(Vector2(world_position.x, world_position.z), map_size)


func _transform_expanded_map_point(point: Vector2, map_size: Vector2, expanded: bool) -> Vector2:
	if not expanded:
		return (point - map_size * 0.5) * local_minimap_zoom + map_size * 0.5
	if _regional_map_surface_active():
		return point
	return (point - map_size * 0.5) * expanded_map_zoom + map_size * 0.5 + expanded_map_pan


func _draw_chunk_exits(target: Control, map_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bounds := _sector_walkable_bounds()
	for exit_data in sector_portal_openings:
		var direction := String(exit_data.get("side", ""))
		var opening_center := float(exit_data.get("center", 0.0))
		var position := Vector2.ZERO
		match direction:
			"N":
				position = Vector2(
					(opening_center - bounds.position.x) / maxf(bounds.size.x, 0.001) * map_size.x,
					20.0
				)
			"E":
				position = Vector2(
					map_size.x - 30.0,
					(opening_center - bounds.position.y) / maxf(bounds.size.y, 0.001) * map_size.y
				)
			"S":
				position = Vector2(
					(opening_center - bounds.position.x) / maxf(bounds.size.x, 0.001) * map_size.x,
					map_size.y - 18.0
				)
			"O":
				position = Vector2(
					20.0,
					(opening_center - bounds.position.y) / maxf(bounds.size.y, 0.001) * map_size.y
				)
			_:
				continue
		target.draw_circle(position, 12.0, Color("25231fd9"))
		target.draw_circle(position, 12.0, Color("c5b27e"), false, 1.5)
		target.draw_string(
			font,
			position + Vector2(-6.0, 5.0),
			direction,
			HORIZONTAL_ALIGNMENT_CENTER,
			12.0,
			12,
			Color("eee3c5")
		)


func _draw_map_legend(target: Control) -> void:
	var rect := Rect2(Vector2(12.0, 12.0), Vector2(112.0, 56.0))
	target.draw_rect(rect, Color("171a1de8"), true)
	target.draw_rect(rect, Color("9b8760"), false, 1.0)
	var font := ThemeDB.fallback_font
	var entries := ["▲ Jugador", "◆ Objetivo", "○ Salida"]
	for index in range(entries.size()):
		target.draw_string(
			font,
			Vector2(20.0, 28.0 + float(index) * 15.0),
			entries[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			92.0,
			10,
			Color("eee3c5")
		)


func _world_xz_to_local_minimap(world_xz: Vector2, map_size := LOCAL_MINIMAP_SIZE) -> Vector2:
	var uv := _world_xz_to_local_uv(world_xz)
	return Vector2(uv.x * map_size.x, uv.y * map_size.y)


func _world_xz_to_diamond_minimap(world_xz: Vector2, map_size := LOCAL_MINIMAP_SIZE) -> Vector2:
	var uv := _world_xz_to_local_uv(world_xz)
	var center := map_size * 0.5
	var tilted_half_height := LOCAL_MINIMAP_DIAMOND_HALF_SIZE.y * local_minimap_tilt
	return center + Vector2(
		(uv.x - uv.y) * LOCAL_MINIMAP_DIAMOND_HALF_SIZE.x,
		(uv.x + uv.y - 1.0) * tilted_half_height
	)


func _world_xz_to_local_uv(world_xz: Vector2) -> Vector2:
	var bounds := Rect2(Vector2.ZERO, Vector2(512.0, 512.0))
	if ocean_water != null:
		bounds = ocean_water.sector_bounds
	return Vector2(
		(world_xz.x - bounds.position.x) / maxf(bounds.size.x, 0.001),
		(world_xz.y - bounds.position.y) / maxf(bounds.size.y, 0.001)
	)


func _world_marker_basis(
	world_origin: Vector3,
	world_facing: Vector2,
	map_size: Vector2,
	expanded: bool
) -> Dictionary:
	var facing := world_facing.normalized()
	if facing.length_squared() < 0.001:
		facing = Vector2(0.0, -1.0)
	var side := Vector2(-facing.y, facing.x)
	if expanded:
		if not _regional_map_surface_active():
			var flat_forward := Vector2(facing.x, facing.y).normalized()
			return {
				"forward": flat_forward,
				"side": Vector2(-flat_forward.y, flat_forward.x),
			}
	var origin_point := _world_position_to_local_map(world_origin, map_size, expanded)
	var forward_point := _world_position_to_local_map(
		world_origin + Vector3(facing.x, 0.0, facing.y) * 18.0,
		map_size,
		expanded
	)
	var side_point := _world_position_to_local_map(
		world_origin + Vector3(side.x, 0.0, side.y) * 18.0,
		map_size,
		expanded
	)
	origin_point = _transform_expanded_map_point(origin_point, map_size, expanded)
	forward_point = _transform_expanded_map_point(forward_point, map_size, expanded)
	side_point = _transform_expanded_map_point(side_point, map_size, expanded)
	var forward_delta := forward_point - origin_point
	var side_delta := side_point - origin_point
	# La camara inclinada comprime el eje de profundidad. La orientacion debe
	# seguir esa proyeccion, pero el icono del jugador no debe quedar aplastado.
	var flat_forward := forward_delta.normalized()
	if flat_forward.length_squared() < 0.001:
		flat_forward = Vector2(facing.x, facing.y).normalized()
	var flat_side := Vector2(-flat_forward.y, flat_forward.x)
	if flat_side.dot(side_delta) < 0.0:
		flat_side = -flat_side
	return {
		"forward": flat_forward,
		"side": flat_side,
	}


func _tilted_icon_offset(offset: Vector2, visual_scale: float, vertical_scale: float) -> Vector2:
	return Vector2(offset.x, offset.y * vertical_scale) * visual_scale


func _draw_boat_minimap_marker(
	target: Control,
	position: Vector2,
	visual_scale: float,
	vertical_scale: float
) -> void:
	var dark := Color("332a22")
	var parchment := Color("f3ead0")
	var sail := Color("b85d3f")
	var hull_outline := PackedVector2Array([
		position + _tilted_icon_offset(Vector2(-7.5, 3.0), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(7.5, 3.0), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(4.5, 7.0), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(-4.5, 7.0), visual_scale, vertical_scale),
	])
	target.draw_colored_polygon(hull_outline, dark)
	target.draw_line(
		position + _tilted_icon_offset(Vector2(0.0, 3.5), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(0.0, -8.0), visual_scale, vertical_scale),
		dark,
		2.0 * visual_scale,
		true
	)
	target.draw_colored_polygon(PackedVector2Array([
		position + _tilted_icon_offset(Vector2(-0.8, -7.0), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(-0.8, 1.5), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(-7.0, 0.5), visual_scale, vertical_scale),
	]), sail)
	target.draw_colored_polygon(PackedVector2Array([
		position + _tilted_icon_offset(Vector2(0.8, -5.5), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(0.8, 1.5), visual_scale, vertical_scale),
		position + _tilted_icon_offset(Vector2(5.8, 0.8), visual_scale, vertical_scale),
	]), parchment)


func _draw_player_minimap_marker(
	target: Control,
	position: Vector2,
	forward: Vector2,
	side: Vector2,
	visual_scale: float
) -> void:
	# Flecha compacta: conserva la lectura direccional incluso sobre costa y relieve.
	target.draw_colored_polygon(PackedVector2Array([
		position + forward * 11.0 * visual_scale,
		position + side * 6.0 * visual_scale - forward * 5.0 * visual_scale,
		position + side * 2.0 * visual_scale - forward * 3.0 * visual_scale,
		position - forward * 8.0 * visual_scale,
		position - side * 2.0 * visual_scale - forward * 3.0 * visual_scale,
		position - side * 6.0 * visual_scale - forward * 5.0 * visual_scale,
	]), Color(0.05, 0.06, 0.07, 0.96))
	target.draw_colored_polygon(PackedVector2Array([
		position + forward * 8.5 * visual_scale,
		position + side * 3.8 * visual_scale - forward * 3.5 * visual_scale,
		position + side * 1.2 * visual_scale - forward * 2.2 * visual_scale,
		position - forward * 5.5 * visual_scale,
		position - side * 1.2 * visual_scale - forward * 2.2 * visual_scale,
		position - side * 3.8 * visual_scale - forward * 3.5 * visual_scale,
	]), map_marker_color)


func _draw_map_ping(target: Control, map_size: Vector2, expanded: bool) -> void:
	if map_ping_uv.x < 0.0 or map_ping_uv.y < 0.0:
		return
	var position := Vector2.ZERO
	if expanded:
		position = _project_sector_map_uv(map_ping_uv, map_size)
		if not _regional_map_surface_active():
			position = _transform_expanded_map_point(position, map_size, true)
	else:
		var center := map_size * 0.5
		position = center + Vector2(
			(map_ping_uv.x - map_ping_uv.y) * LOCAL_MINIMAP_DIAMOND_HALF_SIZE.x,
			(map_ping_uv.x + map_ping_uv.y - 1.0) * LOCAL_MINIMAP_DIAMOND_HALF_SIZE.y * local_minimap_tilt
		)
		position = _transform_expanded_map_point(position, map_size, false)
	var color: Color = [Color("f2c96d"), Color("e75f58"), Color("63aee8")][map_ping_mode]
	var radius := 7.0 if expanded else 4.5
	target.draw_circle(position, radius + 3.0, Color(0.04, 0.05, 0.06, 0.9), false, 2.0)
	target.draw_circle(position, radius, color, false, 2.0)
	target.draw_circle(position, 2.0, color, true)


func _toggle_local_map() -> void:
	local_map_expanded = not local_map_expanded
	if not local_map_expanded and world_map_backdrop != null:
		world_map_backdrop.visible = false
	if expanded_map_backdrop != null:
		expanded_map_backdrop.visible = local_map_expanded
	if local_map_expanded and expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()
	_sync_persistent_hud_visibility()
	_refresh_player_input_enabled()


func _open_regional_map() -> void:
	if world_map_backdrop != null:
		world_map_backdrop.visible = false
	local_map_expanded = true
	if expanded_map_backdrop != null:
		expanded_map_backdrop.visible = true
	_sync_regional_map_view()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()
	_sync_persistent_hud_visibility()
	_refresh_player_input_enabled()


func _on_expanded_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_change_expanded_map_zoom(0.15)
			expanded_local_minimap.accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_change_expanded_map_zoom(-0.15)
			expanded_local_minimap.accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and mouse_button.double_click:
			if mouse_button.ctrl_pressed:
				_set_map_ping_mode(1)
			elif mouse_button.shift_pressed:
				_set_map_ping_mode(2)
			var view_size := _expanded_map_view_size()
			map_ping_uv = _unproject_sector_map_position(mouse_button.position, view_size)
			expanded_local_minimap.queue_redraw()
			if local_minimap != null:
				local_minimap.queue_redraw()
			expanded_local_minimap.accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			expanded_map_dragging = mouse_button.pressed
			expanded_local_minimap.mouse_default_cursor_shape = (
				Control.CURSOR_CAN_DROP
				if mouse_button.pressed
				else (Control.CURSOR_CROSS if map_ping_mode == 1 else Control.CURSOR_DRAG)
			)
			expanded_map_last_mouse = mouse_button.position
			expanded_local_minimap.accept_event()
	elif event is InputEventMouseMotion and expanded_map_dragging:
		var mouse_motion := event as InputEventMouseMotion
		expanded_map_pan += mouse_motion.position - expanded_map_last_mouse
		expanded_map_last_mouse = mouse_motion.position
		_clamp_expanded_map_pan()
		_sync_regional_map_view()
		expanded_local_minimap.queue_redraw()
		expanded_local_minimap.accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_change_expanded_map_zoom((magnify.factor - 1.0) * 0.9)
		expanded_local_minimap.accept_event()
	elif event is InputEventPanGesture:
		var pan_gesture := event as InputEventPanGesture
		expanded_map_pan -= pan_gesture.delta * 18.0
		_clamp_expanded_map_pan()
		_sync_regional_map_view()
		expanded_local_minimap.queue_redraw()
		expanded_local_minimap.accept_event()


func _change_expanded_map_zoom(delta: float) -> void:
	expanded_map_zoom = clampf(expanded_map_zoom + delta, 1.0, 2.5)
	_clamp_expanded_map_pan()
	_sync_regional_map_view()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func _clamp_expanded_map_pan() -> void:
	var view_size := _expanded_map_view_size()
	var scaled_size := view_size * expanded_map_zoom
	var allowance := Vector2(
		maxf(scaled_size.x - view_size.x, 0.0) * 0.5,
		maxf(scaled_size.y - view_size.y, 0.0) * 0.5
	)
	expanded_map_pan.x = clampf(expanded_map_pan.x, -allowance.x, allowance.x)
	expanded_map_pan.y = clampf(expanded_map_pan.y, -allowance.y, allowance.y)


func _toggle_world_map() -> void:
	if world_map_backdrop == null:
		return
	var opening := not world_map_backdrop.visible
	world_map_backdrop.visible = opening
	if opening:
		local_map_expanded = true
		if expanded_map_backdrop != null:
			expanded_map_backdrop.visible = false
		if world_map_canvas != null:
			world_map_canvas.queue_redraw()
	else:
		local_map_expanded = false
		if expanded_map_backdrop != null:
			expanded_map_backdrop.visible = false
	_sync_persistent_hud_visibility()
	_refresh_player_input_enabled()


func _sync_persistent_hud_visibility() -> void:
	var show_persistent := not local_map_expanded
	if minimap_hud_module != null:
		minimap_hud_module.visible = show_persistent
	if gameplay_hud != null and gameplay_hud.has_method("set_persistent_hud_visible"):
		gameplay_hud.call("set_persistent_hud_visible", show_persistent)


func _on_world_map_draw() -> void:
	if world_map_canvas == null:
		return
	var map_size := _world_map_view_size()
	var texture_rect := _world_map_texture_rect(map_size)
	if world_map_surface != null:
		world_map_surface.call("set_view", world_map_texture, texture_rect)
	else:
		world_map_canvas.draw_rect(Rect2(Vector2.ZERO, map_size), Color("0d1419"), true)
		if world_map_texture != null:
			world_map_canvas.draw_texture_rect(world_map_texture, texture_rect, false)

	# La grilla es una ayuda de inspeccion y solo aparece en zoom cercano. En la
	# vista completa el jugador percibe regiones continuas, no celdas tecnicas.
	if world_map_zoom >= 4.0:
		for column in range(world_map_columns + 1):
			var u := clampf(
				float(column) * world_map_sector_pixels / WORLD_MAP_IMAGE_SIZE.x,
				0.0,
				1.0
			)
			world_map_canvas.draw_line(
				_world_map_project_uv(Vector2(u, 0.0), texture_rect),
				_world_map_project_uv(Vector2(u, 1.0), texture_rect),
				Color(0.02, 0.03, 0.03, 0.26),
				0.8
			)
		for row in range(world_map_rows + 1):
			var v := clampf(
				float(row) * world_map_sector_pixels / WORLD_MAP_IMAGE_SIZE.y,
				0.0,
				1.0
			)
			world_map_canvas.draw_line(
				_world_map_project_uv(Vector2(0.0, v), texture_rect),
				_world_map_project_uv(Vector2(1.0, v), texture_rect),
				Color(0.02, 0.03, 0.03, 0.26),
				0.8
			)
	if world_map_zoom >= 5.0:
		for key in available_sectors:
			var sec: Vector2i = available_sectors[key]
			_draw_world_map_sector_outline(texture_rect, sec, Color("c5b27e38"), 0.75)

	if current_sector.x >= 0:
		_draw_world_map_sector_fill(texture_rect, current_sector, Color(1.0, 0.78, 0.16, 0.16))
		_draw_world_map_sector_outline(texture_rect, current_sector, Color(1.0, 0.86, 0.30, 0.96), 2.5)
		world_map_canvas.draw_circle(
			_world_map_sector_center(texture_rect, current_sector),
			3.5,
			map_marker_color
		)
	if _is_world_map_sector_inside(world_map_hovered_sector):
		_draw_world_map_sector_outline(texture_rect, world_map_hovered_sector, Color(1.0, 1.0, 1.0, 0.92), 2.0)
	if _is_world_map_sector_inside(world_map_selected_sector):
		_draw_world_map_sector_fill(texture_rect, world_map_selected_sector, Color(0.96, 0.75, 0.25, 0.16))
		_draw_world_map_sector_outline(texture_rect, world_map_selected_sector, Color(0.96, 0.78, 0.36, 1.0), 3.0)
	var atlas_border := PackedVector2Array([
		_world_map_project_uv(Vector2.ZERO, texture_rect),
		_world_map_project_uv(Vector2(1.0, 0.0), texture_rect),
		_world_map_project_uv(Vector2.ONE, texture_rect),
		_world_map_project_uv(Vector2(0.0, 1.0), texture_rect),
		_world_map_project_uv(Vector2.ZERO, texture_rect),
	])
	world_map_canvas.draw_polyline(atlas_border, Color("9b8760"), 1.5, true)


func _world_map_sector_rect(texture_rect: Rect2, sector_coord: Vector2i) -> Rect2:
	var polygon := _world_map_sector_polygon(texture_rect, sector_coord)
	if polygon.is_empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _world_map_project_uv(uv: Vector2, texture_rect: Rect2) -> Vector2:
	if world_map_surface != null:
		world_map_surface.call("set_view", world_map_texture, texture_rect)
		return world_map_surface.call("project_uv", uv) as Vector2
	return texture_rect.position + uv * texture_rect.size


func _world_map_unproject_point(point: Vector2, texture_rect: Rect2) -> Vector2:
	if world_map_surface != null:
		world_map_surface.call("set_view", world_map_texture, texture_rect)
		return world_map_surface.call("unproject_point", point) as Vector2
	return Vector2(
		(point.x - texture_rect.position.x) / maxf(texture_rect.size.x, 0.001),
		(point.y - texture_rect.position.y) / maxf(texture_rect.size.y, 0.001)
	)


func _world_map_sector_uv_bounds(sector_coord: Vector2i) -> Rect2:
	var art_sector := _world_map_art_sector_coord(sector_coord)
	var start_pixels := Vector2(art_sector) * world_map_sector_pixels
	var end_pixels := Vector2(
		minf(start_pixels.x + world_map_sector_pixels, WORLD_MAP_IMAGE_SIZE.x),
		minf(start_pixels.y + world_map_sector_pixels, WORLD_MAP_IMAGE_SIZE.y)
	)
	return Rect2(start_pixels / WORLD_MAP_IMAGE_SIZE, (end_pixels - start_pixels) / WORLD_MAP_IMAGE_SIZE)


func _world_map_art_sector_coord(logical_sector: Vector2i) -> Vector2i:
	return WORLD_MAP_ART_SECTOR_SWAPS.get(logical_sector, logical_sector) as Vector2i


func _world_map_logical_sector_coord(art_sector: Vector2i) -> Vector2i:
	# El intercambio es simetrico, de modo que la misma tabla sirve como inversa.
	return WORLD_MAP_ART_SECTOR_SWAPS.get(art_sector, art_sector) as Vector2i


func _world_map_sector_polygon(texture_rect: Rect2, sector_coord: Vector2i) -> PackedVector2Array:
	var uv_rect := _world_map_sector_uv_bounds(sector_coord)
	return PackedVector2Array([
		_world_map_project_uv(uv_rect.position, texture_rect),
		_world_map_project_uv(Vector2(uv_rect.end.x, uv_rect.position.y), texture_rect),
		_world_map_project_uv(uv_rect.end, texture_rect),
		_world_map_project_uv(Vector2(uv_rect.position.x, uv_rect.end.y), texture_rect),
	])


func _world_map_sector_center(texture_rect: Rect2, sector_coord: Vector2i) -> Vector2:
	return _world_map_project_uv(_world_map_sector_uv_bounds(sector_coord).get_center(), texture_rect)


func _draw_world_map_sector_fill(texture_rect: Rect2, sector_coord: Vector2i, color: Color) -> void:
	world_map_canvas.draw_colored_polygon(_world_map_sector_polygon(texture_rect, sector_coord), color)


func _draw_world_map_sector_outline(
	texture_rect: Rect2,
	sector_coord: Vector2i,
	color: Color,
	width: float
) -> void:
	var polygon := _world_map_sector_polygon(texture_rect, sector_coord)
	polygon.append(polygon[0])
	world_map_canvas.draw_polyline(polygon, color, width, true)


func _is_world_map_sector_inside(sector_coord: Vector2i) -> bool:
	return sector_coord.x >= 0 and sector_coord.y >= 0 \
		and sector_coord.x < world_map_columns and sector_coord.y < world_map_rows


func _world_map_texture_rect(map_size: Vector2) -> Rect2:
	var fit_scale := minf(
		map_size.x / WORLD_MAP_IMAGE_SIZE.x,
		map_size.y / WORLD_MAP_IMAGE_SIZE.y
	)
	var draw_size := WORLD_MAP_IMAGE_SIZE * fit_scale * world_map_zoom
	return Rect2((map_size - draw_size) * 0.5 + world_map_pan, draw_size)


func _on_world_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_change_world_map_zoom(0.2)
			world_map_canvas.accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_change_world_map_zoom(-0.2)
			world_map_canvas.accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				world_map_dragging = true
				world_map_canvas.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
				world_map_drag_distance = 0.0
				world_map_last_mouse = mouse_button.position
			else:
				if world_map_drag_distance <= 6.0:
					_select_world_map_sector_at(mouse_button.position)
				world_map_dragging = false
				world_map_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
			world_map_canvas.accept_event()
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if world_map_dragging:
			var drag_delta := mouse_motion.position - world_map_last_mouse
			world_map_drag_distance += drag_delta.length()
			world_map_pan += drag_delta
			world_map_last_mouse = mouse_motion.position
			_clamp_world_map_pan()
		_update_world_map_hover(mouse_motion.position)
		world_map_canvas.queue_redraw()
		world_map_canvas.accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_change_world_map_zoom((magnify.factor - 1.0) * 1.2)
		world_map_canvas.accept_event()
	elif event is InputEventPanGesture:
		var pan_gesture := event as InputEventPanGesture
		world_map_pan -= pan_gesture.delta * 18.0
		_clamp_world_map_pan()
		world_map_canvas.queue_redraw()
		world_map_canvas.accept_event()


func _change_world_map_zoom(delta: float) -> void:
	world_map_zoom = clampf(world_map_zoom + delta, 1.0, 18.0)
	_clamp_world_map_pan()
	if world_map_canvas != null:
		world_map_canvas.queue_redraw()


func _center_world_map_on_current_sector() -> void:
	if current_sector.x < 0:
		return
	var view_size := _world_map_view_size()
	var fit_scale := minf(
		view_size.x / WORLD_MAP_IMAGE_SIZE.x,
		view_size.y / WORLD_MAP_IMAGE_SIZE.y
	)
	var base_sector_width := world_map_sector_pixels * fit_scale
	world_map_zoom = clampf(
		view_size.x / maxf(base_sector_width * WORLD_MAP_REGION_VISIBLE_COLUMNS, 0.001),
		1.0,
		18.0
	)
	var draw_size := WORLD_MAP_IMAGE_SIZE * fit_scale * world_map_zoom
	var art_sector := _world_map_art_sector_coord(current_sector)
	var sector_center_pixels := (Vector2(art_sector) + Vector2.ONE * 0.5) * world_map_sector_pixels
	var marker_without_pan := (view_size - draw_size) * 0.5
	marker_without_pan += sector_center_pixels / WORLD_MAP_IMAGE_SIZE * draw_size
	world_map_pan = view_size * 0.5 - marker_without_pan
	_clamp_world_map_pan()
	if world_map_canvas != null:
		world_map_canvas.queue_redraw()


func _reset_world_map_view() -> void:
	world_map_zoom = 1.0
	world_map_pan = Vector2.ZERO
	world_map_hovered_sector = Vector2i(-1, -1)
	world_map_selected_sector = Vector2i(-1, -1)
	if world_map_info_card != null:
		world_map_info_card.visible = false
	if world_map_canvas != null:
		world_map_canvas.queue_redraw()


func _update_world_map_hover(local_position: Vector2) -> void:
	var view_size := _world_map_view_size()
	var texture_rect := _world_map_texture_rect(view_size)
	var normalized := _world_map_unproject_point(local_position, texture_rect)
	if not Rect2(Vector2.ZERO, view_size).has_point(local_position) \
	or normalized.x < 0.0 or normalized.x > 1.0 \
	or normalized.y < 0.0 or normalized.y > 1.0:
		world_map_hovered_sector = Vector2i(-1, -1)
	else:
		var image_pixel := normalized * WORLD_MAP_IMAGE_SIZE
		var art_sector := Vector2i(
			int(floor(image_pixel.x / world_map_sector_pixels)),
			int(floor(image_pixel.y / world_map_sector_pixels))
		)
		world_map_hovered_sector = _world_map_logical_sector_coord(art_sector)
		if not _is_world_map_sector_inside(world_map_hovered_sector):
			world_map_hovered_sector = Vector2i(-1, -1)
	if world_map_hover_label != null:
		if _is_world_map_sector_inside(world_map_hovered_sector):
			var info: Dictionary = MapDataManager.get_sector_info(world_map_hovered_sector)
			world_map_hover_label.text = "%s - %s - Grado %s - [%d, %d]" % [
				str(info.get("name", "Territorio")),
				str(info.get("biome_display", "Bioma desconocido")),
				str(info.get("grade_roman", "I")),
				world_map_hovered_sector.x,
				world_map_hovered_sector.y,
			]
		else:
			world_map_hover_label.text = "Atlas %d x %d - sectores territoriales de 5 km" % [
				world_map_columns,
				world_map_rows,
			]


func _select_world_map_sector_at(local_position: Vector2) -> void:
	_update_world_map_hover(local_position)
	if not _is_world_map_sector_inside(world_map_hovered_sector):
		return
	world_map_selected_sector = world_map_hovered_sector
	var info: Dictionary = MapDataManager.get_sector_info(world_map_selected_sector)
	var resource_names: PackedStringArray = []
	var resources: Array = info.get("resources", []) as Array
	for index in range(mini(resources.size(), 3)):
		var resource: Dictionary = resources[index] as Dictionary
		resource_names.append(str(resource.get("name", "Recurso desconocido")))
	var resources_text := ", ".join(resource_names)
	if resources_text.is_empty():
		resources_text = "Sin datos"
	var language := str(info.get("language", info.get("idioma", "Sin registrar")))
	if world_map_info_label != null:
		world_map_info_label.text = "%s\n\nBioma  %s\nGrado  %s\nIdioma  %s\nRecursos  %s\nSector  [%d, %d]" % [
			str(info.get("name", "Territorio")),
			str(info.get("biome_display", "Desconocido")),
			str(info.get("grade_roman", "I")),
			language,
			resources_text,
			world_map_selected_sector.x,
			world_map_selected_sector.y,
		]
	if world_map_info_card != null:
		world_map_info_card.visible = true
	if world_map_canvas != null:
		world_map_canvas.queue_redraw()


func _clamp_world_map_pan() -> void:
	var view_size := _world_map_view_size()
	var rect := _world_map_texture_rect(view_size)
	var allowance := Vector2(
		maxf(rect.size.x - view_size.x, 0.0) * 0.5,
		maxf(rect.size.y - view_size.y, 0.0) * 0.5
	)
	world_map_pan.x = clampf(world_map_pan.x, -allowance.x, allowance.x)
	world_map_pan.y = clampf(world_map_pan.y, -allowance.y, allowance.y)


func _toggle_map_legend() -> void:
	map_legend_visible = not map_legend_visible
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()


func _queue_local_minimap_redraw_if_needed() -> void:
	if local_minimap == null or player == null:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	if player_xz.distance_squared_to(_last_minimap_player_xz) < 0.01:
		return
	_last_minimap_player_xz = player_xz
	local_minimap.queue_redraw()
	if expanded_local_minimap != null and local_map_expanded:
		expanded_local_minimap.queue_redraw()


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

	if ocean_water != null:
		ocean_water.configure_for_sector(sec, terrain)
	clear_sector_portal_openings()
	_setup_sector_content()
	_load_local_minimap_texture()
	expanded_map_texture = local_minimap_texture
	_configure_regional_map_surface()
	_place_player_on_ground()
	expanded_map_zoom = 1.0
	expanded_map_pan = Vector2.ZERO
	_last_minimap_player_xz = Vector2(INF, INF)
	if local_minimap != null:
		local_minimap.queue_redraw()
	if expanded_local_minimap != null:
		expanded_local_minimap.queue_redraw()
	_set_progress(100.0)
	await get_tree().create_timer(0.25).timeout

	if progress_bar != null:
		progress_bar.visible = false
	if sector_label != null:
		sector_label.text = _location_caption(sec)
	if expanded_map_title_label != null:
		expanded_map_title_label.text = _location_caption(sec).to_upper()
	if expanded_sector_label != null:
		expanded_sector_label.text = "%s - %s" % [_location_caption(sec), _sector_caption(sec)]
	if expanded_region_info_label != null:
		_update_regional_map_info(sec)
	traveling = false


func _set_progress(value: float, caption := "") -> void:
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.value = value
	if not caption.is_empty() and sector_label != null:
		sector_label.text = caption
