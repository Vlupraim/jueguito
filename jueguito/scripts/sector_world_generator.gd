extends Node3D

const SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const PLAYER_SCENE_PATH := "res://scenes/characters/player/player.tscn"
const WATER_SHADER := preload("res://shaders/water_simple.gdshader")
const MAP_IMAGE_SIZE := Vector2i(1672, 941)
const SECTOR_SIDE_METERS := 5000.0
const METERS_PER_PIXEL := 200.0
const SECTOR_PIXELS := 25
const TERRAIN_RESOLUTION := 80
const GRID_STEP_METERS := 5000.0
const WATER_COLLISION_GRID := 40
const WATER_LEVEL := 2.0
const WATER_AREA_HEIGHT := 260.0
const MAX_WADE_DISTANCE_METERS := 15.0
const AUTO_BEACH_RADIUS_PIXELS := 4
const WATER_SHORE_RADIUS_PIXELS := 9
const UNKNOWN_SURFACE_SEARCH_RADIUS_PIXELS := 4
const SECTOR_EDGE_BLEND_RATIO := 0.10
const MOUNTAIN_BROAD_OFFSET := 0.24
const MOUNTAIN_BROAD_SCALE := 0.55

const BASE_SPEED := 520.0
const FAST_MULTIPLIER := 4.0
const SLOW_MULTIPLIER := 0.30
const LOOK_SENSITIVITY := 0.006
const MIN_CAMERA_HEIGHT := 18.0
const MAX_CAMERA_HEIGHT := 6200.0
const EDITOR_MINIMAP_SIZE := Vector2(260.0, 260.0)
const EDITOR_MINIMAP_PANEL_SIZE := Vector2(296.0, 416.0)
const EDITOR_MINIMAP_SAMPLES := 64
const EDITOR_MINIMAP_GRID_STEP_METERS := 1000.0
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TERRAIN3D_EXPORT_RESOLUTION := 512  # multiplo de region_size (256) -> sector = 2x2 regiones limpias

const SURFACE_UNKNOWN := 0
const SURFACE_LAND := 1
const SURFACE_WATER := 2
const SURFACE_COAST := 3
const SURFACE_DEEP_WATER := 4

var sector_data: Dictionary = {}
var surface_image: Image
var all_sectors: Array[Vector2i] = []
var playable_sectors: Array[Vector2i] = []
var selected_sector := Vector2i.ZERO
var selected_sector_index := 0
var selected_all_sector_index := 0
var selection_note := "Sector jugable inicial"
var height_noise: FastNoiseLite
var detail_noise: FastNoiseLite

var terrain_instance: MeshInstance3D
var water_instance: MeshInstance3D
var grid_instance: MeshInstance3D
var terrain_body: StaticBody3D
var terrain_collision: CollisionShape3D
var water_area: Area3D
var water_blocker_body: StaticBody3D
var prop_root: Node3D
var player_instance: Node3D
var editor_cursor: MeshInstance3D
var camera: Camera3D
var ui_layer: CanvasLayer
var info_label: Label
var editor_minimap_panel: PanelContainer
var editor_minimap_view: Control
var editor_minimap_label: Label
var editor_status_label: Label
var export_button: Button
var water_collision_shapes_count := 0
var water_blocker_shapes_count := 0
var looking := false
var show_grid := true
var free_camera_enabled := false
var terrain3d_export_in_progress := false
var yaw := 0.0
var pitch := -0.62
var editor_minimap_hover_valid := false
var editor_minimap_hover_local := Vector2.ZERO
var editor_selected_point_valid := false
var editor_selected_point := Vector3.ZERO
var editor_status_text := "Editor 3D listo: usa el minimapa para ubicarte dentro del sector."


func _ready() -> void:
	_setup_environment()
	_load_sector_data()
	_load_surface_mask()
	_build_sector_lists()
	_choose_initial_sector()
	_setup_scene_nodes()
	_setup_camera()
	_setup_player()
	_setup_ui()
	_regenerate_sector()


func _process(delta: float) -> void:
	_keep_player_in_world()
	_queue_editor_minimap_redraw()
	if not free_camera_enabled:
		return
	var movement := _get_camera_movement()
	if movement != Vector3.ZERO:
		var multiplier := 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			multiplier = FAST_MULTIPLIER
		elif Input.is_key_pressed(KEY_CTRL):
			multiplier = SLOW_MULTIPLIER
		camera.position += movement.normalized() * BASE_SPEED * multiplier * delta
		camera.position.y = clampf(camera.position.y, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var camera_key_event: InputEventKey = event as InputEventKey
		if camera_key_event.keycode == KEY_V:
			_toggle_camera_mode()
			return

	if event is InputEventMouseButton:
		if _is_pointer_over_editor_ui():
			looking = false
			return
		if not free_camera_enabled:
			return
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			looking = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_camera_height(0.86)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_camera_height(1.16)
	elif event is InputEventMouseMotion and looking:
		if _is_pointer_over_editor_ui():
			return
		if not free_camera_enabled:
			return
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		yaw -= mouse_motion.relative.x * LOOK_SENSITIVITY
		pitch -= mouse_motion.relative.y * LOOK_SENSITIVITY
		pitch = clampf(pitch, -1.38, -0.08)
		_apply_camera_rotation()
	elif event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_R:
			if free_camera_enabled:
				_reset_camera()
			else:
				_place_player_at_spawn()
		elif key_event.keycode == KEY_B:
			_cycle_player_camera_mode()
		elif key_event.keycode == KEY_G:
			show_grid = not show_grid
			grid_instance.visible = show_grid
		elif key_event.ctrl_pressed and key_event.keycode == KEY_E:
			_export_current_sector_for_terrain3d()
		elif key_event.keycode == KEY_N:
			_select_relative_sector(1)
		elif key_event.keycode == KEY_P:
			_select_relative_sector(-1)
		elif key_event.keycode == KEY_T:
			_select_next_surface("land", "tierra")
		elif key_event.keycode == KEY_C:
			_select_next_surface("coast", "costa")
		elif key_event.keycode == KEY_O:
			_select_next_surface("water", "agua")
		elif key_event.keycode == KEY_F:
			_select_next_surface("deep_water", "agua profunda")
		else:
			var biome_number := _number_from_key(key_event.keycode)
			if biome_number >= 0 and biome_number <= 7:
				_select_next_biome(biome_number)


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.52, 0.70, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.90, 0.94, 1.0)
	environment.ambient_light_energy = 0.95
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SolPrototipo"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.4
	add_child(sun)


func _load_sector_data() -> void:
	if not FileAccess.file_exists(SECTOR_DATA_PATH):
		sector_data = {"scale": {"columns": 1, "rows": 1}, "sectors": {}}
		return
	var text := FileAccess.get_file_as_string(SECTOR_DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		sector_data = parsed
	else:
		sector_data = {"scale": {"columns": 1, "rows": 1}, "sectors": {}}


func _load_surface_mask() -> void:
	surface_image = Image.new()
	var error := surface_image.load(ProjectSettings.globalize_path(SURFACE_MASK_PATH))
	if error != OK:
		surface_image = Image.create(MAP_IMAGE_SIZE.x, MAP_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		surface_image.fill(Color.TRANSPARENT)
		return
	surface_image.convert(Image.FORMAT_RGBA8)


func _build_sector_lists() -> void:
	all_sectors.clear()
	playable_sectors.clear()
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		all_sectors.append(Vector2i.ZERO)
		playable_sectors.append(Vector2i.ZERO)
		return
	var sectors: Dictionary = sectors_value as Dictionary
	for key in sectors.keys():
		var value: Variant = sectors[key]
		if not (value is Dictionary):
			continue
		var sector: Dictionary = value as Dictionary
		var coord_value: Variant = sector.get("coord", [0, 0])
		if not (coord_value is Array):
			continue
		var coord_array: Array = coord_value as Array
		if coord_array.size() < 2:
			continue
		var coord := Vector2i(int(coord_array[0]), int(coord_array[1]))
		all_sectors.append(coord)
		var land_pixels := _surface_count(sector, "land") + _surface_count(sector, "coast")
		var water_pixels := _surface_count(sector, "water") + _surface_count(sector, "deep_water")
		if land_pixels > 0 and land_pixels >= water_pixels * 0.18:
			playable_sectors.append(coord)
	if all_sectors.is_empty():
		all_sectors.append(Vector2i.ZERO)
	if playable_sectors.is_empty():
		playable_sectors.append(Vector2i.ZERO)


func _choose_initial_sector() -> void:
	var scale_value: Variant = sector_data.get("scale", {})
	var center := Vector2(33.0, 19.0)
	if scale_value is Dictionary:
		var scale: Dictionary = scale_value as Dictionary
		center = Vector2(float(scale.get("columns", 67)) * 0.5, float(scale.get("rows", 38)) * 0.5)

	var best_index := 0
	var best_distance := 999999999.0
	for index in range(playable_sectors.size()):
		var sector := playable_sectors[index]
		var distance := Vector2(float(sector.x), float(sector.y)).distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	selected_sector_index = best_index
	selected_sector = playable_sectors[selected_sector_index]
	_sync_all_sector_index_to_selected()


func _setup_scene_nodes() -> void:
	terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "TerrenoGeneradoSector5km"
	add_child(terrain_instance)

	terrain_body = StaticBody3D.new()
	terrain_body.name = "ColliderTierraCosta"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 1
	add_child(terrain_body)

	terrain_collision = CollisionShape3D.new()
	terrain_collision.name = "TrimeshTierraCosta"
	terrain_body.add_child(terrain_collision)

	water_instance = MeshInstance3D.new()
	water_instance.name = "AguaGeneradaSector5km"
	add_child(water_instance)

	water_area = Area3D.new()
	water_area.name = "AreaAgua"
	water_area.collision_layer = 2
	water_area.collision_mask = 1
	water_area.monitoring = true
	water_area.monitorable = true
	add_child(water_area)

	water_blocker_body = StaticBody3D.new()
	water_blocker_body.name = "BloqueoAguaParaPersonajes"
	water_blocker_body.collision_layer = 4
	water_blocker_body.collision_mask = 1
	add_child(water_blocker_body)

	grid_instance = MeshInstance3D.new()
	grid_instance.name = "GrillaLocal5km"
	add_child(grid_instance)

	prop_root = Node3D.new()
	prop_root.name = "MarcadoresRecursosV0"
	add_child(prop_root)

	_setup_editor_cursor()


func _setup_editor_cursor() -> void:
	editor_cursor = MeshInstance3D.new()
	editor_cursor.name = "MarcadorEditor3D"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 58.0
	mesh.bottom_radius = 58.0
	mesh.height = 8.0
	mesh.radial_segments = 48
	editor_cursor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.82, 0.18, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	editor_cursor.material_override = material
	editor_cursor.visible = false
	add_child(editor_cursor)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CamaraSector"
	camera.far = 22000.0
	camera.fov = 64.0
	add_child(camera)
	camera.make_current()
	_reset_camera()


func _setup_player() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		return
	player_instance = player_scene.instantiate() as Node3D
	player_instance.name = "PlayerTest"
	add_child(player_instance)
	_make_player_camera_current()


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	info_label = Label.new()
	info_label.name = "SectorGeneratorInfo"
	info_label.position = Vector2(18, 16)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94))
	info_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	info_label.add_theme_constant_override("shadow_offset_x", 2)
	info_label.add_theme_constant_override("shadow_offset_y", 2)
	ui_layer.add_child(info_label)

	_setup_editor_minimap()


func _setup_editor_minimap() -> void:
	editor_minimap_panel = PanelContainer.new()
	editor_minimap_panel.name = "Editor3DMinimapPanel"
	editor_minimap_panel.anchor_left = 1.0
	editor_minimap_panel.anchor_right = 1.0
	editor_minimap_panel.anchor_top = 0.0
	editor_minimap_panel.anchor_bottom = 0.0
	editor_minimap_panel.offset_left = -EDITOR_MINIMAP_PANEL_SIZE.x - 18.0
	editor_minimap_panel.offset_right = -18.0
	editor_minimap_panel.offset_top = 18.0
	editor_minimap_panel.offset_bottom = 18.0 + EDITOR_MINIMAP_PANEL_SIZE.y
	editor_minimap_panel.custom_minimum_size = EDITOR_MINIMAP_PANEL_SIZE
	editor_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_minimap_panel.add_theme_stylebox_override("panel", _make_editor_panel_style(Color(0.08, 0.10, 0.11, 0.78), Color(0.82, 0.86, 0.76, 0.28), 8, 10))
	ui_layer.add_child(editor_minimap_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	editor_minimap_panel.add_child(layout)

	var title := Label.new()
	title.text = "Editor de sector 3D"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
	layout.add_child(title)

	editor_minimap_view = Control.new()
	editor_minimap_view.name = "Editor3DMinimap"
	editor_minimap_view.custom_minimum_size = EDITOR_MINIMAP_SIZE
	editor_minimap_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_minimap_view.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_minimap_view.draw.connect(_draw_editor_minimap)
	editor_minimap_view.gui_input.connect(_handle_editor_minimap_input)
	editor_minimap_view.mouse_exited.connect(_clear_editor_minimap_hover)
	layout.add_child(editor_minimap_view)

	editor_minimap_label = Label.new()
	editor_minimap_label.name = "Editor3DMinimapLabel"
	editor_minimap_label.add_theme_font_size_override("font_size", 12)
	editor_minimap_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88))
	editor_minimap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(editor_minimap_label)

	editor_status_label = Label.new()
	editor_status_label.name = "Editor3DStatus"
	editor_status_label.add_theme_font_size_override("font_size", 12)
	editor_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.46))
	editor_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(editor_status_label)

	export_button = Button.new()
	export_button.text = "Export Terrain3D"
	export_button.custom_minimum_size = Vector2(0.0, 34.0)
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_export_current_sector_for_terrain3d)
	layout.add_child(export_button)

	_update_editor_minimap_label()


func _draw_editor_minimap() -> void:
	if editor_minimap_view == null:
		return
	var full_rect := Rect2(Vector2.ZERO, editor_minimap_view.size)
	editor_minimap_view.draw_rect(full_rect, Color(0.05, 0.08, 0.09, 0.96), true)
	var map_rect := _editor_minimap_content_rect()
	var sector_rect := _sector_pixel_rect(selected_sector)
	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var sample_size := map_rect.size / float(EDITOR_MINIMAP_SAMPLES)
	for y_index in range(EDITOR_MINIMAP_SAMPLES):
		var z_ratio := (float(y_index) + 0.5) / float(EDITOR_MINIMAP_SAMPLES)
		for x_index in range(EDITOR_MINIMAP_SAMPLES):
			var x_ratio := (float(x_index) + 0.5) / float(EDITOR_MINIMAP_SAMPLES)
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			var sample_rect := Rect2(
				map_rect.position + Vector2(float(x_index) * sample_size.x, float(y_index) * sample_size.y),
				sample_size + Vector2(0.6, 0.6)
			)
			editor_minimap_view.draw_rect(sample_rect, _editor_minimap_color(surface_id, biome_id), true)
	_draw_editor_minimap_grid(map_rect)
	_draw_editor_minimap_marker(map_rect, Vector2.ZERO, Color(1.0, 1.0, 1.0, 0.78), 3.0)
	if player_instance != null:
		_draw_editor_minimap_marker(map_rect, Vector2(player_instance.global_position.x, player_instance.global_position.z), Color(0.20, 0.42, 1.0, 0.96), 5.0)
	if camera != null:
		_draw_editor_minimap_marker(map_rect, Vector2(camera.global_position.x, camera.global_position.z), Color(0.20, 1.0, 0.55, 0.92), 4.0)
	if editor_selected_point_valid:
		_draw_editor_minimap_marker(map_rect, Vector2(editor_selected_point.x, editor_selected_point.z), Color(1.0, 0.78, 0.18, 0.98), 6.0)
	if editor_minimap_hover_valid:
		var hover_position := _local_to_editor_minimap_position(editor_minimap_hover_local, map_rect)
		editor_minimap_view.draw_line(hover_position + Vector2(-7.0, 0.0), hover_position + Vector2(7.0, 0.0), Color(1.0, 0.88, 0.28, 0.95), 1.5)
		editor_minimap_view.draw_line(hover_position + Vector2(0.0, -7.0), hover_position + Vector2(0.0, 7.0), Color(1.0, 0.88, 0.28, 0.95), 1.5)
	editor_minimap_view.draw_rect(map_rect, Color(0.95, 0.93, 0.80, 0.85), false, 1.5)


func _draw_editor_minimap_grid(map_rect: Rect2) -> void:
	var steps := int(SECTOR_SIDE_METERS / EDITOR_MINIMAP_GRID_STEP_METERS)
	for index in range(steps + 1):
		var local_value := -SECTOR_SIDE_METERS * 0.5 + float(index) * EDITOR_MINIMAP_GRID_STEP_METERS
		var x_a := _local_to_editor_minimap_position(Vector2(local_value, -SECTOR_SIDE_METERS * 0.5), map_rect)
		var x_b := _local_to_editor_minimap_position(Vector2(local_value, SECTOR_SIDE_METERS * 0.5), map_rect)
		var z_a := _local_to_editor_minimap_position(Vector2(-SECTOR_SIDE_METERS * 0.5, local_value), map_rect)
		var z_b := _local_to_editor_minimap_position(Vector2(SECTOR_SIDE_METERS * 0.5, local_value), map_rect)
		var color := Color(0.02, 0.03, 0.03, 0.24)
		if index == 0 or index == steps:
			color = Color(0.02, 0.03, 0.03, 0.55)
		editor_minimap_view.draw_line(x_a, x_b, color, 1.0, true)
		editor_minimap_view.draw_line(z_a, z_b, color, 1.0, true)


func _draw_editor_minimap_marker(map_rect: Rect2, local_xz: Vector2, color: Color, radius: float) -> void:
	if not _is_local_xz_inside_sector(local_xz):
		return
	editor_minimap_view.draw_circle(_local_to_editor_minimap_position(local_xz, map_rect), radius, color)


func _handle_editor_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_editor_minimap_hover(mouse_motion.position)
		editor_minimap_view.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			_update_editor_minimap_hover(mouse_button.position)
			if editor_minimap_hover_valid and (mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_RIGHT):
				var force_free_camera := mouse_button.button_index == MOUSE_BUTTON_RIGHT or mouse_button.double_click
				_use_editor_minimap_point(editor_minimap_hover_local, force_free_camera)
				editor_minimap_view.accept_event()


func _update_editor_minimap_hover(local_position: Vector2) -> void:
	var map_rect := _editor_minimap_content_rect()
	if not map_rect.has_point(local_position):
		editor_minimap_hover_valid = false
		_update_editor_minimap_label()
		_queue_editor_minimap_redraw()
		return
	editor_minimap_hover_valid = true
	editor_minimap_hover_local = _editor_minimap_position_to_local(local_position, map_rect)
	_update_editor_minimap_label()
	_queue_editor_minimap_redraw()


func _clear_editor_minimap_hover() -> void:
	editor_minimap_hover_valid = false
	_update_editor_minimap_label()
	_queue_editor_minimap_redraw()


func _use_editor_minimap_point(local_xz: Vector2, force_free_camera: bool) -> void:
	_set_editor_cursor(local_xz)
	if free_camera_enabled or force_free_camera:
		if force_free_camera and not free_camera_enabled:
			free_camera_enabled = true
			camera.make_current()
		_move_free_camera_to_local(local_xz)
		editor_status_text = "Camara libre movida a " + _local_meter_label(local_xz) + "."
	else:
		_move_player_to_local(local_xz)
	_update_ui()
	_update_editor_minimap_label()
	_queue_editor_minimap_redraw()


func _move_player_to_local(local_xz: Vector2) -> void:
	if player_instance == null:
		return
	var ground_info := get_player_ground_info(Vector3(local_xz.x, 0.0, local_xz.y))
	if not bool(ground_info.get("walkable", false)):
		editor_status_text = "No puedo poner al jugador ahi: superficie no caminable."
		return
	var ground_position: Vector3 = ground_info.get("position", Vector3(local_xz.x, 0.0, local_xz.y))
	player_instance.global_position = ground_position + Vector3.UP * 1.45
	if player_instance.has_method("mark_safe_position"):
		player_instance.call("mark_safe_position")
	editor_status_text = "Jugador movido a " + _local_meter_label(local_xz) + "."


func _move_free_camera_to_local(local_xz: Vector2) -> void:
	var terrain_position := _terrain_position_for_local(local_xz)
	camera.position = Vector3(local_xz.x, clampf(terrain_position.y + 980.0, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT), local_xz.y + 1250.0)
	yaw = 0.0
	pitch = -0.72
	_apply_camera_rotation()


func _set_editor_cursor(local_xz: Vector2) -> void:
	editor_selected_point = _terrain_position_for_local(local_xz) + Vector3.UP * 10.0
	editor_selected_point_valid = true
	if editor_cursor != null:
		editor_cursor.global_position = editor_selected_point
		editor_cursor.visible = true


func _terrain_position_for_local(local_xz: Vector2) -> Vector3:
	var x_ratio := local_xz.x / SECTOR_SIDE_METERS + 0.5
	var z_ratio := local_xz.y / SECTOR_SIDE_METERS + 0.5
	x_ratio = clampf(x_ratio, 0.0, 0.9999)
	z_ratio = clampf(z_ratio, 0.0, 0.9999)
	var sector_rect := _sector_pixel_rect(selected_sector)
	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	return _terrain_point_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)


func _editor_minimap_content_rect() -> Rect2:
	if editor_minimap_view == null:
		return Rect2(Vector2.ZERO, EDITOR_MINIMAP_SIZE)
	var view_size := editor_minimap_view.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = EDITOR_MINIMAP_SIZE
	var side := minf(view_size.x, view_size.y)
	return Rect2((view_size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _local_to_editor_minimap_position(local_xz: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(local_xz.x + SECTOR_SIDE_METERS * 0.5) / SECTOR_SIDE_METERS,
		(local_xz.y + SECTOR_SIDE_METERS * 0.5) / SECTOR_SIDE_METERS
	)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)


func _editor_minimap_position_to_local(local_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(local_position.x - map_rect.position.x) / map_rect.size.x,
		(local_position.y - map_rect.position.y) / map_rect.size.y
	)
	normalized.x = clampf(normalized.x, 0.0, 1.0)
	normalized.y = clampf(normalized.y, 0.0, 1.0)
	return Vector2(
		normalized.x * SECTOR_SIDE_METERS - SECTOR_SIDE_METERS * 0.5,
		normalized.y * SECTOR_SIDE_METERS - SECTOR_SIDE_METERS * 0.5
	)


func _is_local_xz_inside_sector(local_xz: Vector2) -> bool:
	var half_size := SECTOR_SIDE_METERS * 0.5
	return local_xz.x >= -half_size and local_xz.x <= half_size and local_xz.y >= -half_size and local_xz.y <= half_size


func _update_editor_minimap_label() -> void:
	if editor_minimap_label == null:
		return
	if not editor_minimap_hover_valid:
		editor_minimap_label.text = "Hover: sin punto\nClick: mover vista activa | derecho/doble: camara libre."
	else:
		var sector_rect := _sector_pixel_rect(selected_sector)
		var x_ratio := editor_minimap_hover_local.x / SECTOR_SIDE_METERS + 0.5
		var z_ratio := editor_minimap_hover_local.y / SECTOR_SIDE_METERS + 0.5
		var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
		editor_minimap_label.text = "Hover " + _local_meter_label(editor_minimap_hover_local) + "\nSuperficie: " + _surface_display_name(surface_id)
	if editor_status_label != null:
		editor_status_label.text = editor_status_text


func _queue_editor_minimap_redraw() -> void:
	if editor_minimap_view != null:
		editor_minimap_view.queue_redraw()


func _is_pointer_over_editor_ui() -> bool:
	if editor_minimap_panel == null:
		return false
	return editor_minimap_panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _local_meter_label(local_xz: Vector2) -> String:
	return "x " + str(int(local_xz.x)) + " m, z " + str(int(local_xz.y)) + " m"


func _make_editor_panel_style(bg_color: Color, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style


func _export_current_sector_for_terrain3d() -> void:
	if terrain3d_export_in_progress:
		return
	terrain3d_export_in_progress = true
	_set_export_buttons_enabled(false)
	editor_status_text = "Exportando sector " + _sector_label(selected_sector) + "..."
	_update_editor_minimap_label()
	await get_tree().process_frame
	if _export_sector_for_terrain3d(selected_sector):
		editor_status_text = "Export Terrain3D listo: " + _terrain3d_export_resource_dir(selected_sector)
	terrain3d_export_in_progress = false
	_set_export_buttons_enabled(true)
	_update_editor_minimap_label()


func _set_export_buttons_enabled(enabled: bool) -> void:
	if export_button != null:
		export_button.disabled = not enabled


func _export_sector_for_terrain3d(sector_to_export: Vector2i, update_status: bool = true) -> bool:
	var original_sector := selected_sector
	var original_height_noise := height_noise
	var original_detail_noise := detail_noise
	selected_sector = sector_to_export
	_setup_noises()

	var export_resource_dir := _terrain3d_export_resource_dir(sector_to_export)
	var export_absolute_dir := ProjectSettings.globalize_path(export_resource_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(export_absolute_dir)
	if dir_error != OK:
		if update_status:
			editor_status_text = "No pude crear carpeta de export Terrain3D."
			_update_editor_minimap_label()
		selected_sector = original_sector
		height_noise = original_height_noise
		detail_noise = original_detail_noise
		return false

	var sector_rect := _sector_pixel_rect(sector_to_export)
	var sector := _get_sector_dict(sector_to_export)
	var biome_id := int(sector.get("biome_id", 0))
	var resolution := TERRAIN3D_EXPORT_RESOLUTION
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	var min_height := INF
	var max_height := -INF
	var surface_reference := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)

	for y_index in range(resolution):
		var z_ratio := float(y_index) / float(resolution - 1)
		for x_index in range(resolution):
			var x_ratio := float(x_index) / float(resolution - 1)
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			var terrain_point := _terrain_point_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)
			var height := terrain_point.y
			var index := y_index * resolution + x_index
			heights[index] = height
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
			surface_reference.set_pixel(x_index, y_index, _editor_minimap_color(surface_id, biome_id))

	var height_image := Image.create(resolution, resolution, false, Image.FORMAT_RF)
	var height_preview := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var height_span := maxf(0.001, max_height - min_height)
	for y_index in range(resolution):
		for x_index in range(resolution):
			var index := y_index * resolution + x_index
			var height := heights[index]
			height_image.set_pixel(x_index, y_index, Color(height, 0.0, 0.0, 1.0))
			var preview_value := clampf((height - min_height) / height_span, 0.0, 1.0)
			height_preview.set_pixel(x_index, y_index, Color(preview_value, preview_value, preview_value, 1.0))

	var height_path := export_absolute_dir.path_join("height.exr")
	var preview_path := export_absolute_dir.path_join("height_preview.png")
	var surface_path := export_absolute_dir.path_join("surface_reference.png")
	var metadata_path := export_absolute_dir.path_join("metadata.json")
	var height_error := height_image.save_exr(height_path, true)
	var preview_error := height_preview.save_png(preview_path)
	var surface_error := surface_reference.save_png(surface_path)
	if height_error != OK or preview_error != OK or surface_error != OK:
		if update_status:
			editor_status_text = "Export incompleto: revise permisos o soporte EXR."
			_update_editor_minimap_label()
		selected_sector = original_sector
		height_noise = original_height_noise
		detail_noise = original_detail_noise
		return false

	var metadata := {
		"version": 1,
		"source": "sector_world_generator",
		"sector": [sector_to_export.x, sector_to_export.y],
		"sector_side_meters": SECTOR_SIDE_METERS,
		"meters_per_source_pixel": METERS_PER_PIXEL,
		"export_resolution": resolution,
		"meters_per_export_pixel": SECTOR_SIDE_METERS / float(resolution - 1),
		"height_min": min_height,
		"height_max": max_height,
		"height_units": "meters",
		"heightmap": "height.exr",
		"height_preview": "height_preview.png",
		"surface_reference": "surface_reference.png",
		"terrain3d_note": "Importa height.exr como base de altura. Usa sector_side_meters como escala horizontal y esta metadata para recordar el rango vertical.",
	}
	var file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		if update_status:
			editor_status_text = "Export listo, pero no pude escribir metadata.json."
			_update_editor_minimap_label()
		selected_sector = original_sector
		height_noise = original_height_noise
		detail_noise = original_detail_noise
		return false
	file.store_string(JSON.stringify(metadata, "\t"))
	selected_sector = original_sector
	height_noise = original_height_noise
	detail_noise = original_detail_noise
	return true


func _terrain3d_export_resource_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EXPORT_DIR + "/sector_" + str(sector.x) + "_" + str(sector.y)


func _sector_label(sector: Vector2i) -> String:
	return "[" + str(sector.x) + ", " + str(sector.y) + "]"


func _regenerate_sector() -> void:
	editor_selected_point_valid = false
	if editor_cursor != null:
		editor_cursor.visible = false
	_setup_noises()
	terrain_instance.mesh = _build_terrain_mesh()
	terrain_instance.material_override = _make_terrain_material()
	water_instance.mesh = _build_water_mesh()
	water_instance.material_override = _make_water_material()
	_rebuild_terrain_collision()
	_rebuild_water_area()
	_rebuild_water_blocker()
	_place_player_at_spawn()
	grid_instance.mesh = _build_grid_mesh()
	grid_instance.material_override = _make_grid_material()
	grid_instance.visible = show_grid
	_rebuild_props()
	_update_ui()


func _setup_noises() -> void:
	var seed_base := selected_sector.x * 73856093 + selected_sector.y * 19349663 + 311
	height_noise = FastNoiseLite.new()
	height_noise.seed = seed_base
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency = 0.00058

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = seed_base + 913
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.0032


func _build_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var sector_rect := _sector_pixel_rect(selected_sector)
	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var half_size := SECTOR_SIDE_METERS * 0.5

	for z_index in range(TERRAIN_RESOLUTION + 1):
		var z_ratio := float(z_index) / float(TERRAIN_RESOLUTION)
		var local_z := lerpf(-half_size, half_size, z_ratio)
		for x_index in range(TERRAIN_RESOLUTION + 1):
			var x_ratio := float(x_index) / float(TERRAIN_RESOLUTION)
			var local_x := lerpf(-half_size, half_size, x_ratio)
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			var shore_influence := _shore_influence(x_ratio, z_ratio, sector_rect, surface_id)
			var edge_falloff := _sector_edge_falloff(x_ratio, z_ratio)
			var height := _height_for(local_x, local_z, x_ratio, z_ratio, surface_id, biome_id, shore_influence, edge_falloff)
			vertices.append(Vector3(local_x, height, local_z))
			colors.append(_color_for(surface_id, biome_id, height, shore_influence))

	for z_index in range(TERRAIN_RESOLUTION):
		for x_index in range(TERRAIN_RESOLUTION):
			var a := z_index * (TERRAIN_RESOLUTION + 1) + x_index
			var b := a + 1
			var c := a + TERRAIN_RESOLUTION + 1
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_water_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var sector_rect := _sector_pixel_rect(selected_sector)
	var half_size := SECTOR_SIDE_METERS * 0.5

	for z_index in range(TERRAIN_RESOLUTION):
		var z0_ratio := float(z_index) / float(TERRAIN_RESOLUTION)
		var z1_ratio := float(z_index + 1) / float(TERRAIN_RESOLUTION)
		var z_mid_ratio := (z0_ratio + z1_ratio) * 0.5
		var z0 := lerpf(-half_size, half_size, z0_ratio)
		var z1 := lerpf(-half_size, half_size, z1_ratio)
		for x_index in range(TERRAIN_RESOLUTION):
			var x0_ratio := float(x_index) / float(TERRAIN_RESOLUTION)
			var x1_ratio := float(x_index + 1) / float(TERRAIN_RESOLUTION)
			var x_mid_ratio := (x0_ratio + x1_ratio) * 0.5
			var surface_id := _sample_surface_id(x_mid_ratio, z_mid_ratio, sector_rect)
			if surface_id != SURFACE_WATER and surface_id != SURFACE_DEEP_WATER:
				continue
			var x0 := lerpf(-half_size, half_size, x0_ratio)
			var x1 := lerpf(-half_size, half_size, x1_ratio)
			var base_index := vertices.size()
			vertices.append(Vector3(x0, WATER_LEVEL, z0))
			vertices.append(Vector3(x1, WATER_LEVEL, z0))
			vertices.append(Vector3(x0, WATER_LEVEL, z1))
			vertices.append(Vector3(x1, WATER_LEVEL, z1))
			# COLOR.r es el factor de profundidad que lee el shader: 0 normal, 1 profunda.
			var color := Color(0.0, 0.0, 0.0, 1.0)
			if surface_id == SURFACE_DEEP_WATER:
				color = Color(1.0, 1.0, 1.0, 1.0)
			for index in range(4):
				colors.append(color)
			indices.append(base_index)
			indices.append(base_index + 2)
			indices.append(base_index + 1)
			indices.append(base_index + 1)
			indices.append(base_index + 2)
			indices.append(base_index + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if vertices.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _rebuild_terrain_collision() -> void:
	var shape := _build_land_collision_shape()
	terrain_collision.shape = shape
	terrain_collision.disabled = shape == null


func _build_land_collision_shape() -> ConcavePolygonShape3D:
	var sector_rect := _sector_pixel_rect(selected_sector)
	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var faces := PackedVector3Array()

	for z_index in range(TERRAIN_RESOLUTION):
		var z0_ratio := float(z_index) / float(TERRAIN_RESOLUTION)
		var z1_ratio := float(z_index + 1) / float(TERRAIN_RESOLUTION)
		var z_mid_ratio := (z0_ratio + z1_ratio) * 0.5
		for x_index in range(TERRAIN_RESOLUTION):
			var x0_ratio := float(x_index) / float(TERRAIN_RESOLUTION)
			var x1_ratio := float(x_index + 1) / float(TERRAIN_RESOLUTION)
			var x_mid_ratio := (x0_ratio + x1_ratio) * 0.5
			var surface_id := _sample_surface_id(x_mid_ratio, z_mid_ratio, sector_rect)
			if not _is_walkable_surface(surface_id):
				continue

			var a := _terrain_point_at_ratio(x0_ratio, z0_ratio, sector_rect, biome_id)
			var b := _terrain_point_at_ratio(x1_ratio, z0_ratio, sector_rect, biome_id)
			var c := _terrain_point_at_ratio(x0_ratio, z1_ratio, sector_rect, biome_id)
			var d := _terrain_point_at_ratio(x1_ratio, z1_ratio, sector_rect, biome_id)
			faces.append(a)
			faces.append(c)
			faces.append(b)
			faces.append(b)
			faces.append(c)
			faces.append(d)
			faces.append(a)
			faces.append(b)
			faces.append(c)
			faces.append(b)
			faces.append(d)
			faces.append(c)

	if faces.is_empty():
		return null

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _rebuild_water_area() -> void:
	for child in water_area.get_children():
		water_area.remove_child(child)
		child.queue_free()

	water_collision_shapes_count = 0
	var sector_rect := _sector_pixel_rect(selected_sector)
	var cell_size := SECTOR_SIDE_METERS / float(WATER_COLLISION_GRID)
	for z_index in range(WATER_COLLISION_GRID):
		var run_start := -1
		for x_index in range(WATER_COLLISION_GRID + 1):
			var is_water := false
			if x_index < WATER_COLLISION_GRID:
				var x_ratio := (float(x_index) + 0.5) / float(WATER_COLLISION_GRID)
				var z_ratio := (float(z_index) + 0.5) / float(WATER_COLLISION_GRID)
				var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
				is_water = surface_id == SURFACE_WATER or surface_id == SURFACE_DEEP_WATER

			if is_water and run_start == -1:
				run_start = x_index
			elif not is_water and run_start != -1:
				_add_water_collision_run(run_start, x_index - 1, z_index, cell_size)
				run_start = -1


func _add_water_collision_run(run_start: int, run_end: int, z_index: int, cell_size: float) -> void:
	var run_width := run_end - run_start + 1
	if run_width <= 0:
		return
	var half_size := SECTOR_SIDE_METERS * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(run_width) * cell_size, WATER_AREA_HEIGHT, cell_size)

	var collider := CollisionShape3D.new()
	collider.name = "AguaRun_" + str(z_index) + "_" + str(run_start) + "_" + str(run_end)
	collider.shape = shape
	collider.position = Vector3(
		-half_size + (float(run_start) + float(run_width) * 0.5) * cell_size,
		WATER_LEVEL + WATER_AREA_HEIGHT * 0.5,
		-half_size + (float(z_index) + 0.5) * cell_size
	)
	water_area.add_child(collider)
	water_collision_shapes_count += 1


func _rebuild_water_blocker() -> void:
	for child in water_blocker_body.get_children():
		water_blocker_body.remove_child(child)
		child.queue_free()

	water_blocker_shapes_count = 0
	var sector_rect := _sector_pixel_rect(selected_sector)
	var cell_size := SECTOR_SIDE_METERS / float(WATER_COLLISION_GRID)
	for z_index in range(WATER_COLLISION_GRID):
		var run_start := -1
		for x_index in range(WATER_COLLISION_GRID + 1):
			var blocks_walker := false
			if x_index < WATER_COLLISION_GRID:
				var x_ratio := (float(x_index) + 0.5) / float(WATER_COLLISION_GRID)
				var z_ratio := (float(z_index) + 0.5) / float(WATER_COLLISION_GRID)
				blocks_walker = _is_blocking_water_for_walker(x_ratio, z_ratio, sector_rect)

			if blocks_walker and run_start == -1:
				run_start = x_index
			elif not blocks_walker and run_start != -1:
				_add_water_blocker_run(run_start, x_index - 1, z_index, cell_size)
				run_start = -1


func _add_water_blocker_run(run_start: int, run_end: int, z_index: int, cell_size: float) -> void:
	var run_width := run_end - run_start + 1
	if run_width <= 0:
		return
	var half_size := SECTOR_SIDE_METERS * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(run_width) * cell_size, WATER_AREA_HEIGHT, cell_size)

	var collider := CollisionShape3D.new()
	collider.name = "BloqueoAguaRun_" + str(z_index) + "_" + str(run_start) + "_" + str(run_end)
	collider.shape = shape
	collider.position = Vector3(
		-half_size + (float(run_start) + float(run_width) * 0.5) * cell_size,
		WATER_LEVEL + WATER_AREA_HEIGHT * 0.5,
		-half_size + (float(z_index) + 0.5) * cell_size
	)
	water_blocker_body.add_child(collider)
	water_blocker_shapes_count += 1


func _terrain_point_at_ratio(x_ratio: float, z_ratio: float, sector_rect: Rect2i, biome_id: int) -> Vector3:
	var half_size := SECTOR_SIDE_METERS * 0.5
	var local_x := lerpf(-half_size, half_size, x_ratio)
	var local_z := lerpf(-half_size, half_size, z_ratio)
	var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
	var shore_influence := _shore_influence(x_ratio, z_ratio, sector_rect, surface_id)
	var edge_falloff := _sector_edge_falloff(x_ratio, z_ratio)
	var height := _height_for(local_x, local_z, x_ratio, z_ratio, surface_id, biome_id, shore_influence, edge_falloff)
	return Vector3(local_x, height, local_z)


func _is_walkable_surface(surface_id: int) -> bool:
	return surface_id == SURFACE_LAND or surface_id == SURFACE_COAST


func _is_blocking_water_for_walker(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> bool:
	var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
	if surface_id != SURFACE_WATER and surface_id != SURFACE_DEEP_WATER:
		return false
	return _distance_to_walkable_meters(x_ratio, z_ratio, sector_rect) > MAX_WADE_DISTANCE_METERS


func _distance_to_walkable_meters(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> float:
	var pixel := _surface_pixel_from_ratio(x_ratio, z_ratio, sector_rect)
	var max_pixel_radius := int(ceil(MAX_WADE_DISTANCE_METERS / METERS_PER_PIXEL)) + 1
	var nearest_squared := INF
	for y_offset in range(-max_pixel_radius, max_pixel_radius + 1):
		for x_offset in range(-max_pixel_radius, max_pixel_radius + 1):
			var sample_x := clampi(pixel.x + x_offset, 0, surface_image.get_width() - 1)
			var sample_y := clampi(pixel.y + y_offset, 0, surface_image.get_height() - 1)
			if _is_walkable_surface(_surface_id_at_pixel(sample_x, sample_y)):
				var distance_squared := float(x_offset * x_offset + y_offset * y_offset)
				if distance_squared < nearest_squared:
					nearest_squared = distance_squared

	if nearest_squared == INF:
		return INF
	return sqrt(nearest_squared) * METERS_PER_PIXEL


func _place_player_at_spawn() -> void:
	if player_instance == null:
		return
	player_instance.global_position = _find_player_spawn_position()
	var character := player_instance as CharacterBody3D
	if character != null:
		character.velocity = Vector3.ZERO
	if not free_camera_enabled:
		_make_player_camera_current()
	if player_instance.has_method("mark_safe_position"):
		player_instance.call("mark_safe_position")


func _keep_player_in_world() -> void:
	if player_instance == null:
		return
	if player_instance.global_position.y < -500.0:
		_place_player_at_spawn()


func _find_player_spawn_position() -> Vector3:
	var sector_rect := _sector_pixel_rect(selected_sector)
	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var best_position := Vector3(0.0, 180.0, 0.0)
	var best_score := INF

	for z_index in range(5, 96, 3):
		var z_ratio := float(z_index) / 100.0
		for x_index in range(5, 96, 3):
			var x_ratio := float(x_index) / 100.0
			var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
			if not _is_walkable_surface(surface_id):
				continue
			var terrain_point := _terrain_point_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)
			var score := Vector2(x_ratio - 0.5, z_ratio - 0.5).length_squared()
			if score < best_score:
				best_score = score
				best_position = terrain_point

	return best_position + Vector3.UP * 1.45


func get_player_ground_info(world_position: Vector3) -> Dictionary:
	var x_ratio := world_position.x / SECTOR_SIDE_METERS + 0.5
	var z_ratio := world_position.z / SECTOR_SIDE_METERS + 0.5
	if x_ratio < 0.0 or x_ratio >= 1.0 or z_ratio < 0.0 or z_ratio >= 1.0:
		return {"walkable": false, "reason": "fuera_sector"}

	var sector_rect := _sector_pixel_rect(selected_sector)
	var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
	if not _is_walkable_surface(surface_id):
		return {"walkable": false, "reason": "superficie_bloqueada", "surface_id": surface_id}

	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var ground_position := _terrain_point_at_ratio(x_ratio, z_ratio, sector_rect, biome_id)
	return {
		"walkable": true,
		"position": ground_position,
		"surface_id": surface_id,
	}


func _build_grid_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half_size := SECTOR_SIDE_METERS * 0.5
	var steps := int(SECTOR_SIDE_METERS / GRID_STEP_METERS)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(steps + 1):
		var offset := -half_size + float(index) * GRID_STEP_METERS
		mesh.surface_add_vertex(Vector3(offset, 12.0, -half_size))
		mesh.surface_add_vertex(Vector3(offset, 12.0, half_size))
		mesh.surface_add_vertex(Vector3(-half_size, 12.0, offset))
		mesh.surface_add_vertex(Vector3(half_size, 12.0, offset))
	mesh.surface_end()
	return mesh


func _make_terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var colors := _water_colors_for_sector(selected_sector)
	material.set_shader_parameter("shallow_color", colors.shallow)
	material.set_shader_parameter("deep_color", colors.deep)
	return material


# Color del agua segun latitud del sector: indigo oscuro cerca de los polos
# (norte/sur), azul mar mas claro hacia el centro/ecuador.
func _water_colors_for_sector(sector: Vector2i) -> Dictionary:
	var sectors_y := float(MAP_IMAGE_SIZE.y) * METERS_PER_PIXEL / SECTOR_SIDE_METERS
	var latitude_ratio := clampf(float(sector.y) / maxf(sectors_y, 1.0), 0.0, 1.0)
	var pole_factor := absf(latitude_ratio - 0.5) * 2.0
	var shallow_center := Color(0.10, 0.45, 0.66, 0.60)
	var deep_center := Color(0.03, 0.20, 0.42, 0.78)
	var shallow_pole := Color(0.09, 0.19, 0.46, 0.64)
	var deep_pole := Color(0.02, 0.06, 0.22, 0.82)
	return {
		"shallow": shallow_center.lerp(shallow_pole, pole_factor),
		"deep": deep_center.lerp(deep_pole, pole_factor),
	}


func _make_grid_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.05, 0.04, 0.30)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _rebuild_props() -> void:
	for child in prop_root.get_children():
		child.queue_free()

	var sector := _get_sector_dict(selected_sector)
	var biome_id := int(sector.get("biome_id", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(selected_sector.x * 928371 + selected_sector.y * 123457 + biome_id * 379)
	var sector_rect := _sector_pixel_rect(selected_sector)
	var attempts := 0
	var placed := 0
	while placed < 48 and attempts < 420:
		attempts += 1
		var x := rng.randf_range(-SECTOR_SIDE_METERS * 0.47, SECTOR_SIDE_METERS * 0.47)
		var z := rng.randf_range(-SECTOR_SIDE_METERS * 0.47, SECTOR_SIDE_METERS * 0.47)
		var x_ratio := (x / SECTOR_SIDE_METERS) + 0.5
		var z_ratio := (z / SECTOR_SIDE_METERS) + 0.5
		var surface_id := _sample_surface_id(x_ratio, z_ratio, sector_rect)
		if surface_id != SURFACE_LAND and surface_id != SURFACE_COAST:
			continue
		var shore_influence := _shore_influence(x_ratio, z_ratio, sector_rect, surface_id)
		var edge_falloff := _sector_edge_falloff(x_ratio, z_ratio)
		var height := _height_for(x, z, x_ratio, z_ratio, surface_id, biome_id, shore_influence, edge_falloff)
		_add_marker(Vector3(x, height + 28.0, z), surface_id, biome_id, rng)
		placed += 1


func _add_marker(position: Vector3, surface_id: int, biome_id: int, rng: RandomNumberGenerator) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var radius := rng.randf_range(16.0, 42.0)
	sphere.radius = radius
	sphere.height = radius * 1.7
	marker.mesh = sphere
	marker.position = position

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if surface_id == SURFACE_COAST:
		material.albedo_color = Color(0.85, 0.67, 0.32, 1.0)
	elif biome_id == 4:
		material.albedo_color = Color(0.86, 0.92, 0.94, 1.0)
	elif biome_id == 5:
		material.albedo_color = Color(0.35, 0.34, 0.31, 1.0)
	elif biome_id == 2:
		material.albedo_color = Color(0.74, 0.58, 0.28, 1.0)
	else:
		material.albedo_color = Color(0.12, 0.34, 0.18, 1.0)
	marker.material_override = material
	prop_root.add_child(marker)


func _height_for(
	local_x: float,
	local_z: float,
	x_ratio: float,
	z_ratio: float,
	surface_id: int,
	biome_id: int,
	shore_influence: float,
	edge_falloff: float
) -> float:
	var noise_x := float(selected_sector.x) * SECTOR_SIDE_METERS + x_ratio * SECTOR_SIDE_METERS
	var noise_z := float(selected_sector.y) * SECTOR_SIDE_METERS + z_ratio * SECTOR_SIDE_METERS
	var broad := height_noise.get_noise_2d(noise_x, noise_z)
	var detail := detail_noise.get_noise_2d(noise_x, noise_z)
	var base_height := 6.5
	var biome_height := 16.0
	var detail_height := 1.3
	match biome_id:
		2:
			base_height = 4.5
			biome_height = 9.0
			detail_height = 0.9
		3:
			base_height = 7.5
			biome_height = 22.0
			detail_height = 1.6
		4:
			base_height = 10.0
			biome_height = 30.0
			detail_height = 1.8
		5:
			base_height = 16.0
			biome_height = 36.0
			detail_height = 1.8
		6:
			base_height = 3.5
			biome_height = 6.0
			detail_height = 0.8
		7:
			base_height = 11.0
			biome_height = 38.0
			detail_height = 2.0

	if surface_id == SURFACE_DEEP_WATER:
		var deep_floor := -10.0 + detail * 1.0
		var shallow_floor := 0.8 + broad * 1.2 + detail * 0.6
		return lerpf(deep_floor, shallow_floor, shore_influence)
	if surface_id == SURFACE_WATER:
		var open_water_floor := -4.0 + detail * 0.7
		var near_shore_floor := 1.4 + broad * 1.0 + detail * 0.5
		return lerpf(open_water_floor, near_shore_floor, shore_influence)
	if surface_id == SURFACE_COAST:
		return 5.0 + broad * 3.5 + detail * 1.1
	if surface_id == SURFACE_LAND:
		var broad_lift := maxf(0.0, broad + 0.12)
		if biome_id == 5:
			broad_lift = _smooth01(clampf((broad + MOUNTAIN_BROAD_OFFSET) * MOUNTAIN_BROAD_SCALE, 0.0, 1.0))
		var land_height := base_height + broad_lift * biome_height + detail * detail_height
		var beach_strength := _beach_strength(surface_id, shore_influence)
		if beach_strength > 0.0:
			var beach_height := 6.0 + broad * 3.0 + detail * 1.0
			land_height = lerpf(land_height, beach_height, beach_strength)

		if edge_falloff < 1.0:
			var edge_cap := 34.0 + maxf(0.0, broad + 0.2) * 30.0 + detail * 2.0
			if land_height > edge_cap:
				land_height = lerpf(edge_cap, land_height, edge_falloff)
		return land_height
	if surface_id == SURFACE_UNKNOWN:
		return 3.0 + broad * 2.0 + detail
	return 0.0


func _color_for(surface_id: int, biome_id: int, height: float, shore_influence: float) -> Color:
	if surface_id == SURFACE_DEEP_WATER:
		return Color(0.02, 0.09, 0.24, 1.0)
	if surface_id == SURFACE_WATER:
		return Color(0.05, 0.26, 0.52, 1.0)
	if surface_id == SURFACE_COAST:
		return Color(0.80, 0.69, 0.43, 1.0)

	var shade := clampf(0.86 + height / 920.0, 0.80, 1.20)
	var base_color := Color(0.28, 0.52, 0.25, 1.0)
	match biome_id:
		2:
			base_color = Color(0.67, 0.54, 0.29, 1.0)
		3:
			base_color = Color(0.08, 0.36, 0.20, 1.0)
		4:
			base_color = Color(0.74, 0.83, 0.84, 1.0)
		5:
			base_color = Color(0.40, 0.38, 0.33, 1.0)
		6:
			base_color = Color(0.20, 0.31, 0.19, 1.0)
		7:
			base_color = Color(0.42, 0.24, 0.48, 1.0)

	var beach_strength := _beach_strength(surface_id, shore_influence)
	if beach_strength > 0.0:
		var sand := Color(0.86, 0.77, 0.52, 1.0)
		base_color = base_color.lerp(sand, beach_strength)
	return base_color * shade


func _editor_minimap_color(surface_id: int, biome_id: int) -> Color:
	match surface_id:
		SURFACE_DEEP_WATER:
			return Color(0.03, 0.10, 0.30, 1.0)
		SURFACE_WATER:
			return Color(0.08, 0.32, 0.62, 1.0)
		SURFACE_COAST:
			return Color(0.83, 0.72, 0.46, 1.0)
		SURFACE_LAND:
			match biome_id:
				2:
					return Color(0.64, 0.53, 0.30, 1.0)
				3:
					return Color(0.10, 0.36, 0.20, 1.0)
				4:
					return Color(0.76, 0.85, 0.86, 1.0)
				5:
					return Color(0.41, 0.39, 0.34, 1.0)
				6:
					return Color(0.22, 0.32, 0.20, 1.0)
				7:
					return Color(0.42, 0.25, 0.48, 1.0)
				_:
					return Color(0.28, 0.52, 0.25, 1.0)
		_:
			return Color(0.42, 0.42, 0.39, 1.0)


func _surface_display_name(surface_id: int) -> String:
	match surface_id:
		SURFACE_LAND:
			return "Tierra"
		SURFACE_WATER:
			return "Agua"
		SURFACE_COAST:
			return "Costa"
		SURFACE_DEEP_WATER:
			return "Agua profunda"
		_:
			return "Sin definir"


func _sample_surface_id(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> int:
	var pixel := _surface_pixel_from_ratio(x_ratio, z_ratio, sector_rect)
	var surface_id := _surface_id_at_pixel(pixel.x, pixel.y)
	if surface_id != SURFACE_UNKNOWN:
		return surface_id
	return _nearest_defined_surface_id(pixel, UNKNOWN_SURFACE_SEARCH_RADIUS_PIXELS)


func _surface_pixel_from_ratio(x_ratio: float, z_ratio: float, sector_rect: Rect2i) -> Vector2i:
	var clamped_x := clampf(x_ratio, 0.0, 0.9999)
	var clamped_z := clampf(z_ratio, 0.0, 0.9999)
	var pixel_x := sector_rect.position.x + int(clamped_x * float(maxi(1, sector_rect.size.x)))
	var pixel_y := sector_rect.position.y + int(clamped_z * float(maxi(1, sector_rect.size.y)))
	pixel_x = clampi(pixel_x, 0, surface_image.get_width() - 1)
	pixel_y = clampi(pixel_y, 0, surface_image.get_height() - 1)
	return Vector2i(pixel_x, pixel_y)


func _shore_influence(x_ratio: float, z_ratio: float, sector_rect: Rect2i, surface_id: int) -> float:
	if surface_id == SURFACE_COAST:
		return 1.0

	var pixel := _surface_pixel_from_ratio(x_ratio, z_ratio, sector_rect)
	var search_radius := WATER_SHORE_RADIUS_PIXELS if surface_id == SURFACE_WATER or surface_id == SURFACE_DEEP_WATER else AUTO_BEACH_RADIUS_PIXELS
	var nearest := search_radius + 1
	for y_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			var distance := maxi(absi(x_offset), absi(y_offset))
			if distance <= 0 or distance >= nearest:
				continue
			var sample_x := clampi(pixel.x + x_offset, 0, surface_image.get_width() - 1)
			var sample_y := clampi(pixel.y + y_offset, 0, surface_image.get_height() - 1)
			var sample_id := _surface_id_at_pixel(sample_x, sample_y)
			if _is_shore_target(surface_id, sample_id):
				nearest = distance

	if nearest > search_radius:
		return 0.0
	var raw := 1.0 - float(nearest - 1) / float(search_radius)
	return _smooth01(raw)


func _is_shore_target(origin_surface_id: int, sample_surface_id: int) -> bool:
	if origin_surface_id == SURFACE_WATER or origin_surface_id == SURFACE_DEEP_WATER:
		return sample_surface_id == SURFACE_LAND or sample_surface_id == SURFACE_COAST
	return sample_surface_id == SURFACE_WATER or sample_surface_id == SURFACE_DEEP_WATER or sample_surface_id == SURFACE_COAST


func _nearest_defined_surface_id(pixel: Vector2i, search_radius: int) -> int:
	var best_surface := SURFACE_UNKNOWN
	var best_distance := INF
	for y_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			var sample_x := clampi(pixel.x + x_offset, 0, surface_image.get_width() - 1)
			var sample_y := clampi(pixel.y + y_offset, 0, surface_image.get_height() - 1)
			var surface_id := _surface_id_at_pixel(sample_x, sample_y)
			if surface_id == SURFACE_UNKNOWN:
				continue
			var distance := Vector2(float(x_offset), float(y_offset)).length_squared()
			if distance < best_distance:
				best_distance = distance
				best_surface = surface_id
	return best_surface


func _beach_strength(surface_id: int, shore_influence: float) -> float:
	if surface_id == SURFACE_COAST:
		return 1.0
	if surface_id == SURFACE_LAND:
		return clampf(shore_influence, 0.0, 1.0)
	return 0.0


func _sector_edge_falloff(x_ratio: float, z_ratio: float) -> float:
	var edge_distance := minf(minf(x_ratio, 1.0 - x_ratio), minf(z_ratio, 1.0 - z_ratio))
	return _smooth01(edge_distance / SECTOR_EDGE_BLEND_RATIO)


func _smooth01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _surface_id_at_pixel(pixel_x: int, pixel_y: int) -> int:
	return _surface_id_from_color(surface_image.get_pixel(pixel_x, pixel_y))


func _surface_id_from_color(color: Color) -> int:
	if color.a <= 0.05:
		return SURFACE_UNKNOWN
	if color.r > 0.70 and color.g > 0.50 and color.b < 0.50:
		return SURFACE_COAST
	if color.g > color.r * 1.7 and color.g > color.b * 0.70 and color.r < 0.40:
		return SURFACE_LAND
	if color.b > 0.35 and color.r < 0.08 and color.g < 0.20:
		return SURFACE_DEEP_WATER
	if color.b > 0.35 and color.r < 0.28 and color.g > 0.15:
		return SURFACE_WATER
	return SURFACE_UNKNOWN


func _sector_pixel_rect(sector: Vector2i) -> Rect2i:
	var x_start := sector.x * SECTOR_PIXELS
	var y_start := sector.y * SECTOR_PIXELS
	var x_end := mini(x_start + SECTOR_PIXELS, MAP_IMAGE_SIZE.x)
	var y_end := mini(y_start + SECTOR_PIXELS, MAP_IMAGE_SIZE.y)
	return Rect2i(x_start, y_start, maxi(1, x_end - x_start), maxi(1, y_end - y_start))


func _select_relative_sector(offset: int) -> void:
	if playable_sectors.is_empty():
		return
	selected_sector_index = wrapi(selected_sector_index + offset, 0, playable_sectors.size())
	selected_sector = playable_sectors[selected_sector_index]
	selection_note = "Sector jugable " + str(selected_sector_index + 1) + " / " + str(playable_sectors.size())
	_sync_all_sector_index_to_selected()
	_regenerate_sector()
	_reset_camera()


func _select_next_surface(surface_name: String, display_name: String) -> void:
	if all_sectors.is_empty():
		return
	for offset in range(1, all_sectors.size() + 1):
		var index := wrapi(selected_all_sector_index + offset, 0, all_sectors.size())
		var sector := _get_sector_dict(all_sectors[index])
		if _surface_count(sector, surface_name) > 0:
			_select_all_sector_index(index, "Prueba superficie: " + display_name)
			return
	selection_note = "No encontre sectores con " + display_name
	_update_ui()


func _select_next_biome(biome_id: int) -> void:
	if all_sectors.is_empty():
		return
	for offset in range(1, all_sectors.size() + 1):
		var index := wrapi(selected_all_sector_index + offset, 0, all_sectors.size())
		var sector := _get_sector_dict(all_sectors[index])
		if int(sector.get("biome_id", 0)) == biome_id and _has_any_defined_surface(sector):
			_select_all_sector_index(index, "Prueba bioma: " + _get_biome_name(biome_id))
			return
	selection_note = "No encontre sectores con bioma " + _get_biome_name(biome_id)
	_update_ui()


func _select_all_sector_index(index: int, note: String) -> void:
	selected_all_sector_index = wrapi(index, 0, all_sectors.size())
	selected_sector = all_sectors[selected_all_sector_index]
	selection_note = note
	_sync_playable_sector_index_to_selected()
	_regenerate_sector()
	_reset_camera()


func _sync_all_sector_index_to_selected() -> void:
	for index in range(all_sectors.size()):
		if all_sectors[index] == selected_sector:
			selected_all_sector_index = index
			return


func _sync_playable_sector_index_to_selected() -> void:
	for index in range(playable_sectors.size()):
		if playable_sectors[index] == selected_sector:
			selected_sector_index = index
			return


func _has_any_defined_surface(sector: Dictionary) -> bool:
	return _surface_count(sector, "land") > 0 \
		or _surface_count(sector, "coast") > 0 \
		or _surface_count(sector, "water") > 0 \
		or _surface_count(sector, "deep_water") > 0


func _get_sector_dict(sector: Vector2i) -> Dictionary:
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		return {}
	var sectors: Dictionary = sectors_value as Dictionary
	var value: Variant = sectors.get(_sector_key(sector), {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _surface_count(sector: Dictionary, surface_name: String) -> int:
	var counts_value: Variant = sector.get("surface_counts", {})
	if not (counts_value is Dictionary):
		return 0
	var counts: Dictionary = counts_value as Dictionary
	return int(counts.get(surface_name, 0))


func _sector_key(sector: Vector2i) -> String:
	return str(sector.x) + "," + str(sector.y)


func _number_from_key(keycode: int) -> int:
	match keycode:
		KEY_0:
			return 0
		KEY_1:
			return 1
		KEY_2:
			return 2
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
		KEY_7:
			return 7
		_:
			return -1


func _get_biome_name(biome_id: int) -> String:
	match biome_id:
		1:
			return "Templado"
		2:
			return "Desierto"
		3:
			return "Selva / humedo"
		4:
			return "Nieve / polar"
		5:
			return "Montana"
		6:
			return "Pantano"
		7:
			return "Arcano / raro"
		_:
			return "Sin bioma"


func _toggle_camera_mode() -> void:
	free_camera_enabled = not free_camera_enabled
	looking = false
	if free_camera_enabled:
		camera.make_current()
	else:
		_make_player_camera_current()
	_update_ui()


func _make_player_camera_current() -> void:
	if player_instance != null and player_instance.has_method("make_camera_current"):
		player_instance.call("make_camera_current")


func _cycle_player_camera_mode() -> void:
	if player_instance == null or not player_instance.has_method("cycle_camera_mode"):
		return
	player_instance.call("cycle_camera_mode")
	if not free_camera_enabled:
		_make_player_camera_current()
	var camera_label := "desconocida"
	if player_instance.has_method("get_camera_mode_label"):
		camera_label = str(player_instance.call("get_camera_mode_label"))
	editor_status_text = "Camara del jugador: " + camera_label + "."
	_update_ui()


func _update_ui() -> void:
	var sector := _get_sector_dict(selected_sector)
	var biome_name := str(sector.get("biome", "Sin bioma"))
	var surface_name := str(sector.get("dominant_surface", "unknown"))
	var camera_mode := "Jugador"
	if free_camera_enabled:
		camera_mode = "Libre debug"
	elif player_instance != null and player_instance.has_method("get_camera_mode_label"):
		camera_mode = "Jugador - " + str(player_instance.call("get_camera_mode_label"))
	info_label.text = "Generador local v0.1 - sector 5 km x 5 km\n" \
		+ "Sector: [" + str(selected_sector.x) + ", " + str(selected_sector.y) + "] | Bioma: " + biome_name + " | Superficie dominante: " + surface_name + "\n" \
		+ selection_note + "\n" \
		+ "N/P: sector jugable | 1-7: biomas | 0: sin bioma | T/C/O/F: tierra/costa/agua/profunda\n" \
		+ "Camara: " + camera_mode + " | V: alternar | B: preset jugador | WASD/Flechas: mover jugador o camara libre | R: reset | G: grilla 5 km\n" \
		+ "Minimapa editor: click mueve vista activa | derecho/doble click fuerza camara libre.\n" \
		+ "Jugador: Shift corre | rueda ajusta zoom. Camara libre: Q/E altura, derecho + mouse mira.\n" \
		+ "Colliders: tierra/costa caminable, agua detectable, bloqueo de agua para personaje > " + str(int(MAX_WADE_DISTANCE_METERS)) + " m.\n" \
		+ "Agua: " + str(water_collision_shapes_count) + " areas | bloqueo personaje: " + str(water_blocker_shapes_count) + " cajas."
	_update_editor_minimap_label()
	_queue_editor_minimap_redraw()


func _reset_camera() -> void:
	yaw = 0.0
	pitch = -0.62
	camera.position = Vector3(0.0, 980.0, 1450.0)
	_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	camera.rotation = Vector3(pitch, yaw, 0.0)


func _change_camera_height(factor: float) -> void:
	camera.position.y = clampf(camera.position.y * factor, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT)


func _get_camera_movement() -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement -= right
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		movement.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		movement.y -= 1.0
	return movement
