extends Node2D

const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const SAVE_PATH := "res://data/map_design_biomes.json"
const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const SECTOR_EXPORT_PATH := "res://data/map_design_sectors_5km.json"
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const BASE_PROTOTYPE_WORLD_SCALE := 20.0
const CONTINENT_SCALE_MULTIPLIER := 10.0
const MAP_WORLD_SCALE := BASE_PROTOTYPE_WORLD_SCALE * CONTINENT_SCALE_MULTIPLIER
const MAP_WORLD_SIZE := MAP_IMAGE_SIZE * MAP_WORLD_SCALE
const GRID_CELL_SIDE_KM := 10.0
const GRID_STEP := GRID_CELL_SIDE_KM * 1000.0
const SECTOR_CELL_SIDE_KM := 5.0
const SECTOR_STEP := SECTOR_CELL_SIDE_KM * 1000.0
const PAN_SPEED_SCREEN_PIXELS := 320.0
const FAST_PAN_MULTIPLIER := 3.0
const SLOW_PAN_MULTIPLIER := 0.35
const TOOL_BIOMES := 0
const TOOL_SURFACE_BUCKET := 1
const TOOL_BARRIER_BRUSH := 2
const BARRIER_THRESHOLD := 0.72
const BARRIER_DILATION_RADIUS := 2
const BARRIER_BRUSH_RADIUS := 5
const MINIMAP_SIZE := Vector2(300.0, 168.0)
const MINIMAP_PANEL_SIZE := Vector2(332.0, 242.0)

const OCEAN_COLOR := Color(0.08, 0.12, 0.16)
const GRID_COLOR := Color(0.04, 0.05, 0.05, 0.42)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.28)
const BORDER_COLOR := Color(0.05, 0.06, 0.06, 0.95)

var camera: Camera2D
var ui_layer: CanvasLayer
var hud_root: PanelContainer
var minimap_panel: PanelContainer
var minimap_view: Control
var minimap_label: Label
var notes_label: Label
var current_label: Label
var hover_label: Label
var status_label: Label
var mode_biomes_button: Button
var mode_surface_button: Button
var mode_barrier_button: Button
var biome_palette: VBoxContainer
var surface_palette: VBoxContainer
var surface_detail_row: HBoxContainer
var barrier_palette: VBoxContainer
var biome_buttons: Array[Button] = []
var surface_buttons: Array[Button] = []
var surface_detail_buttons: Array[Button] = []
var view_buttons: Dictionary = {}
var map_texture: Texture2D
var source_image: Image
var surface_image: Image
var surface_texture: ImageTexture
var barrier_image: Image
var barrier_texture: ImageTexture
var barrier_mask := PackedByteArray()
var biome_cells: Dictionary = {}
var tool_mode := TOOL_BIOMES
var selected_biome := 1
var selected_surface := 1
var surface_detail_cell_side_km := 2.0
var hovered_cell := Vector2i(-1, -1)
var dragging := false
var painting := false
var erasing := false
var surface_painting := false
var surface_erasing := false
var last_surface_bucket_cell := Vector2i(-999999, -999999)
var last_surface_bucket_erase := false
var barrier_drawing := false
var barrier_erasing := false
var last_mouse := Vector2.ZERO
var show_grid := true
var show_map := true
var show_surface_mask := true
var show_biomes := true
var show_barriers := true
var show_sectors := true
var minimap_hover_valid := false
var minimap_hover_world := Vector2.ZERO


func _ready() -> void:
	map_texture = load(MAP_TEXTURE_PATH) as Texture2D
	_setup_surface_mask()
	_setup_camera()
	_setup_ui()
	_load_layer()
	_load_surface_mask()
	_load_barrier_mask()
	_set_status("Capas listas. Tab alterna entre biomas y balde de tierra/agua.")
	queue_redraw()


func _process(delta: float) -> void:
	_process_camera_movement(delta)
	_queue_minimap_redraw()
	var next_hover := _world_to_cell(get_global_mouse_position())
	if not _is_cell_inside(next_hover):
		next_hover = Vector2i(-1, -1)
	if next_hover != hovered_cell:
		hovered_cell = next_hover
		_update_ui()
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		_handle_mouse_button(mouse_button)
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_mouse_motion(mouse_motion)
	elif event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		_handle_key(key_event)


func _draw() -> void:
	var map_rect := Rect2(-MAP_WORLD_SIZE * 0.5, MAP_WORLD_SIZE)
	draw_rect(map_rect.grow(9000.0), OCEAN_COLOR, true)
	if show_map and map_texture != null:
		draw_texture_rect(map_texture, map_rect, false, Color.WHITE)
	else:
		draw_rect(map_rect, Color(0.92, 0.92, 0.88), true)

	if show_surface_mask:
		_draw_surface_mask(map_rect)
	if show_biomes:
		_draw_painted_cells()
	if show_grid:
		_draw_grid(map_rect)
		if tool_mode != TOOL_BIOMES:
			_draw_surface_detail_grid(map_rect)
	if show_sectors:
		_draw_sector_grid(map_rect)
	if show_barriers:
		_draw_barriers(map_rect)
	_draw_hover_cell()
	draw_rect(map_rect, BORDER_COLOR, false, 180.0)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "LayerPainterCamera"
	add_child(camera)
	camera.make_current()
	_reset_camera()


func _setup_surface_mask() -> void:
	if map_texture != null:
		source_image = map_texture.get_image()
	else:
		source_image = Image.create(int(MAP_IMAGE_SIZE.x), int(MAP_IMAGE_SIZE.y), false, Image.FORMAT_RGBA8)
	source_image.convert(Image.FORMAT_RGBA8)
	_build_barrier_mask()
	_create_empty_surface_mask()


func _create_empty_surface_mask() -> void:
	surface_image = Image.create(int(MAP_IMAGE_SIZE.x), int(MAP_IMAGE_SIZE.y), false, Image.FORMAT_RGBA8)
	surface_image.fill(Color.TRANSPARENT)
	_refresh_surface_texture()


func _build_barrier_mask() -> void:
	var width := int(MAP_IMAGE_SIZE.x)
	var height := int(MAP_IMAGE_SIZE.y)
	var raw_mask := PackedByteArray()
	raw_mask.resize(width * height)
	for y in range(height):
		for x in range(width):
			var color := source_image.get_pixel(x, y)
			var luminance := (color.r + color.g + color.b) / 3.0
			var index := y * width + x
			raw_mask[index] = 1 if color.a > 0.2 and luminance < BARRIER_THRESHOLD else 0

	barrier_mask.resize(width * height)
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			barrier_mask[index] = _is_near_raw_barrier(raw_mask, x, y, width, height)
	_refresh_barrier_texture()


func _is_near_raw_barrier(raw_mask: PackedByteArray, x: int, y: int, width: int, height: int) -> int:
	var min_x := maxi(0, x - BARRIER_DILATION_RADIUS)
	var max_x := mini(width - 1, x + BARRIER_DILATION_RADIUS)
	var min_y := maxi(0, y - BARRIER_DILATION_RADIUS)
	var max_y := mini(height - 1, y + BARRIER_DILATION_RADIUS)
	for sample_y in range(min_y, max_y + 1):
		for sample_x in range(min_x, max_x + 1):
			if raw_mask[sample_y * width + sample_x] == 1:
				return 1
	return 0


func _refresh_barrier_texture() -> void:
	var width := int(MAP_IMAGE_SIZE.x)
	var height := int(MAP_IMAGE_SIZE.y)
	barrier_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	barrier_image.fill(Color.TRANSPARENT)
	for y in range(height):
		for x in range(width):
			if barrier_mask[y * width + x] == 1:
				barrier_image.set_pixel(x, y, Color(0.02, 0.02, 0.02, 0.68))
	barrier_texture = ImageTexture.create_from_image(barrier_image)


func _refresh_surface_texture() -> void:
	if surface_texture == null:
		surface_texture = ImageTexture.create_from_image(surface_image)
	else:
		surface_texture.update(surface_image)


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	hud_root = PanelContainer.new()
	hud_root.name = "ToolHud"
	hud_root.position = Vector2(16, 16)
	hud_root.custom_minimum_size = Vector2(292, 0)
	hud_root.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_theme_stylebox_override("panel", _make_panel_style(Color(0.94, 0.95, 0.92, 0.94), Color(0.12, 0.14, 0.13, 0.42), 8, 12))
	ui_layer.add_child(hud_root)

	var panel_layout := VBoxContainer.new()
	panel_layout.add_theme_constant_override("separation", 8)
	hud_root.add_child(panel_layout)

	notes_label = Label.new()
	notes_label.name = "PainterNotes"
	notes_label.text = "Capas del mapa"
	notes_label.add_theme_font_size_override("font_size", 18)
	notes_label.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08))
	panel_layout.add_child(notes_label)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	panel_layout.add_child(mode_row)

	mode_biomes_button = _make_mode_button("Biomas")
	mode_biomes_button.pressed.connect(_set_tool_mode.bind(TOOL_BIOMES))
	mode_row.add_child(mode_biomes_button)

	mode_surface_button = _make_mode_button("Tierra/agua")
	mode_surface_button.pressed.connect(_set_tool_mode.bind(TOOL_SURFACE_BUCKET))
	mode_row.add_child(mode_surface_button)

	mode_barrier_button = _make_mode_button("Lineas")
	mode_barrier_button.pressed.connect(_set_tool_mode.bind(TOOL_BARRIER_BRUSH))
	mode_row.add_child(mode_barrier_button)

	current_label = Label.new()
	current_label.name = "CurrentSelection"
	current_label.add_theme_font_size_override("font_size", 14)
	current_label.add_theme_color_override("font_color", Color(0.10, 0.12, 0.12))
	panel_layout.add_child(current_label)

	hover_label = Label.new()
	hover_label.name = "HoverCell"
	hover_label.add_theme_font_size_override("font_size", 13)
	hover_label.add_theme_color_override("font_color", Color(0.18, 0.21, 0.21))
	panel_layout.add_child(hover_label)

	panel_layout.add_child(HSeparator.new())

	biome_palette = VBoxContainer.new()
	biome_palette.add_theme_constant_override("separation", 5)
	panel_layout.add_child(biome_palette)
	for biome_id in range(1, 8):
		var button := _make_palette_button(_get_biome_name(biome_id), _get_biome_color(biome_id))
		button.pressed.connect(_select_biome.bind(biome_id))
		biome_buttons.append(button)
		biome_palette.add_child(button)

	surface_palette = VBoxContainer.new()
	surface_palette.add_theme_constant_override("separation", 5)
	panel_layout.add_child(surface_palette)
	for surface_id in range(1, 5):
		var button := _make_palette_button(_get_surface_name(surface_id), _get_surface_color(surface_id))
		button.pressed.connect(_select_surface.bind(surface_id))
		surface_buttons.append(button)
		surface_palette.add_child(button)

	surface_detail_row = HBoxContainer.new()
	surface_detail_row.add_theme_constant_override("separation", 5)
	panel_layout.add_child(surface_detail_row)
	for detail_km in [10.0, 5.0, 2.0, 1.0]:
		var detail_button := _make_detail_button(str(int(detail_km)) + " km", detail_km)
		surface_detail_buttons.append(detail_button)
		surface_detail_row.add_child(detail_button)

	barrier_palette = VBoxContainer.new()
	barrier_palette.add_theme_constant_override("separation", 5)
	panel_layout.add_child(barrier_palette)
	var barrier_note := Label.new()
	barrier_note.text = "Izquierdo: cerrar linea\nDerecho: borrar linea"
	barrier_note.add_theme_font_size_override("font_size", 13)
	barrier_note.add_theme_color_override("font_color", Color(0.14, 0.16, 0.16))
	barrier_palette.add_child(barrier_note)

	panel_layout.add_child(HSeparator.new())

	var view_grid := GridContainer.new()
	view_grid.columns = 2
	view_grid.add_theme_constant_override("h_separation", 6)
	view_grid.add_theme_constant_override("v_separation", 6)
	panel_layout.add_child(view_grid)
	view_grid.add_child(_make_view_toggle("Boceto", "map"))
	view_grid.add_child(_make_view_toggle("Mascara", "mask"))
	view_grid.add_child(_make_view_toggle("Biomas", "biomes"))
	view_grid.add_child(_make_view_toggle("Grilla", "grid"))
	view_grid.add_child(_make_view_toggle("Lineas", "barriers"))
	view_grid.add_child(_make_view_toggle("Sectores", "sectors"))

	var file_row := HBoxContainer.new()
	file_row.add_theme_constant_override("separation", 6)
	panel_layout.add_child(file_row)

	var save_button := _make_action_button("Guardar")
	save_button.pressed.connect(_save_all_layers)
	file_row.add_child(save_button)

	var load_button := _make_action_button("Cargar")
	load_button.pressed.connect(_load_all_layers)
	file_row.add_child(load_button)

	var export_sectors_button := _make_action_button("Export sectores")
	export_sectors_button.pressed.connect(_export_sector_map)
	panel_layout.add_child(export_sectors_button)

	status_label = Label.new()
	status_label.name = "PainterStatus"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.10, 0.12, 0.14))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(status_label)

	_setup_minimap()
	_update_ui()


func _setup_minimap() -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.name = "NavigationMinimap"
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.anchor_top = 0.0
	minimap_panel.anchor_bottom = 0.0
	minimap_panel.offset_left = -MINIMAP_PANEL_SIZE.x - 16.0
	minimap_panel.offset_right = -16.0
	minimap_panel.offset_top = 16.0
	minimap_panel.offset_bottom = 16.0 + MINIMAP_PANEL_SIZE.y
	minimap_panel.custom_minimum_size = MINIMAP_PANEL_SIZE
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.94, 0.95, 0.92, 0.92), Color(0.10, 0.12, 0.12, 0.38), 8, 10))
	ui_layer.add_child(minimap_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	minimap_panel.add_child(layout)

	var title := Label.new()
	title.text = "Navegacion del mapa"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08))
	layout.add_child(title)

	minimap_view = Control.new()
	minimap_view.name = "MinimapView"
	minimap_view.custom_minimum_size = MINIMAP_SIZE
	minimap_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap_view.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_view.draw.connect(_draw_minimap)
	minimap_view.gui_input.connect(_handle_minimap_input)
	minimap_view.mouse_exited.connect(_clear_minimap_hover)
	layout.add_child(minimap_view)

	minimap_label = Label.new()
	minimap_label.name = "MinimapHover"
	minimap_label.add_theme_font_size_override("font_size", 12)
	minimap_label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.14))
	minimap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(minimap_label)

	_update_minimap_label()


func _draw_minimap() -> void:
	if minimap_view == null:
		return
	var full_rect := Rect2(Vector2.ZERO, minimap_view.size)
	minimap_view.draw_rect(full_rect, Color(0.08, 0.13, 0.16, 0.94), true)
	var map_rect := _minimap_content_rect()
	if show_map and map_texture != null:
		minimap_view.draw_texture_rect(map_texture, map_rect, false, Color.WHITE)
	else:
		minimap_view.draw_rect(map_rect, Color(0.88, 0.89, 0.84), true)
	if show_surface_mask and surface_texture != null:
		minimap_view.draw_texture_rect(surface_texture, map_rect, false, Color(1.0, 1.0, 1.0, 0.80))
	if show_biomes:
		_draw_minimap_biomes(map_rect)
	if show_barriers and barrier_texture != null:
		minimap_view.draw_texture_rect(barrier_texture, map_rect, false, Color(1.0, 1.0, 1.0, 0.78))
	if show_grid:
		_draw_minimap_grid(map_rect, GRID_STEP, Color(0.02, 0.03, 0.03, 0.28), 1.0)
	if show_sectors:
		_draw_minimap_grid(map_rect, SECTOR_STEP, Color(0.98, 0.98, 0.95, 0.20), 1.0)
	_draw_minimap_hover_sector(map_rect)
	_draw_minimap_camera_rect(map_rect)
	minimap_view.draw_rect(map_rect, Color(0.92, 0.92, 0.86, 0.88), false, 1.0)


func _draw_minimap_biomes(map_rect: Rect2) -> void:
	for key in biome_cells.keys():
		var cell := _cell_from_key(str(key))
		if _is_cell_inside(cell):
			var biome_id := int(biome_cells[key])
			var rect := _minimap_rect_for_world_rect(_cell_rect(cell), map_rect)
			minimap_view.draw_rect(rect, _get_biome_color(biome_id), true)


func _draw_minimap_grid(map_rect: Rect2, step: float, color: Color, width: float) -> void:
	var world_left := -MAP_WORLD_SIZE.x * 0.5
	var world_right := MAP_WORLD_SIZE.x * 0.5
	var world_top := -MAP_WORLD_SIZE.y * 0.5
	var world_bottom := MAP_WORLD_SIZE.y * 0.5
	var x := world_left
	while x <= world_right + 0.1:
		var start := _world_to_minimap_position(Vector2(x, world_top), map_rect)
		var end := _world_to_minimap_position(Vector2(x, world_bottom), map_rect)
		minimap_view.draw_line(start, end, color, width, true)
		x += step
	var y := world_top
	while y <= world_bottom + 0.1:
		var start := _world_to_minimap_position(Vector2(world_left, y), map_rect)
		var end := _world_to_minimap_position(Vector2(world_right, y), map_rect)
		minimap_view.draw_line(start, end, color, width, true)
		y += step


func _draw_minimap_hover_sector(map_rect: Rect2) -> void:
	if not minimap_hover_valid:
		return
	var sector := _world_to_sector_cell(minimap_hover_world)
	if not _is_sector_cell_inside(sector):
		return
	var sector_rect := _minimap_rect_for_world_rect(_sector_rect(sector), map_rect)
	minimap_view.draw_rect(sector_rect, Color(1.0, 0.82, 0.24, 0.20), true)
	minimap_view.draw_rect(sector_rect, Color(1.0, 0.86, 0.30, 0.92), false, 2.0)
	var marker := _world_to_minimap_position(minimap_hover_world, map_rect)
	minimap_view.draw_circle(marker, 3.5, Color(1.0, 0.86, 0.25, 0.95))


func _draw_minimap_camera_rect(map_rect: Rect2) -> void:
	if camera == null:
		return
	var viewport_size := get_viewport_rect().size
	var zoom_value := maxf(camera.zoom.x, 0.0001)
	var visible_world_size := viewport_size / zoom_value
	var camera_world_rect := Rect2(camera.position - visible_world_size * 0.5, visible_world_size)
	var camera_minimap_rect := _minimap_rect_for_world_rect(camera_world_rect, map_rect)
	minimap_view.draw_rect(camera_minimap_rect, Color(0.18, 0.38, 0.90, 0.12), true)
	minimap_view.draw_rect(camera_minimap_rect, Color(0.20, 0.50, 1.0, 0.95), false, 2.0)


func _handle_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_minimap_hover(mouse_motion.position)
		minimap_view.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			_update_minimap_hover(mouse_button.position)
			if minimap_hover_valid and (mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_RIGHT):
				var zoom_to_sector := mouse_button.double_click or mouse_button.button_index == MOUSE_BUTTON_RIGHT
				_focus_world_position(minimap_hover_world, zoom_to_sector)
				minimap_view.accept_event()


func _update_minimap_hover(local_position: Vector2) -> void:
	var map_rect := _minimap_content_rect()
	if not map_rect.has_point(local_position):
		minimap_hover_valid = false
		_update_minimap_label()
		_queue_minimap_redraw()
		return
	minimap_hover_valid = true
	minimap_hover_world = _minimap_local_to_world_position(local_position, map_rect)
	_update_minimap_label()
	_queue_minimap_redraw()


func _clear_minimap_hover() -> void:
	minimap_hover_valid = false
	_update_minimap_label()
	_queue_minimap_redraw()


func _focus_world_position(world_position: Vector2, zoom_to_sector: bool) -> void:
	var half_world := MAP_WORLD_SIZE * 0.5
	camera.position = Vector2(
		clampf(world_position.x, -half_world.x, half_world.x),
		clampf(world_position.y, -half_world.y, half_world.y)
	)
	if zoom_to_sector:
		_zoom_to_sector_view()
	var sector := _world_to_sector_cell(camera.position)
	var action_text := "zoom al sector " if zoom_to_sector else "centrado en sector "
	_set_status("Minimapa: " + action_text + _sector_cell_label(sector) + ".")
	_update_ui()
	queue_redraw()
	_queue_minimap_redraw()


func _zoom_to_sector_view() -> void:
	var viewport_size := get_viewport_rect().size
	var target_world_span := SECTOR_STEP * 2.2
	var next_zoom := minf(viewport_size.x / target_world_span, viewport_size.y / target_world_span)
	next_zoom = clampf(next_zoom, 0.0025, 0.35)
	camera.zoom = Vector2(next_zoom, next_zoom)


func _minimap_content_rect() -> Rect2:
	if minimap_view == null:
		return Rect2(Vector2.ZERO, MINIMAP_SIZE)
	var view_size := minimap_view.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = MINIMAP_SIZE
	var map_aspect := MAP_WORLD_SIZE.x / MAP_WORLD_SIZE.y
	var view_aspect := view_size.x / view_size.y
	var content_size := Vector2.ZERO
	if view_aspect > map_aspect:
		content_size.y = view_size.y
		content_size.x = content_size.y * map_aspect
	else:
		content_size.x = view_size.x
		content_size.y = content_size.x / map_aspect
	return Rect2((view_size - content_size) * 0.5, content_size)


func _world_to_minimap_position(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(world_position.x + MAP_WORLD_SIZE.x * 0.5) / MAP_WORLD_SIZE.x,
		(world_position.y + MAP_WORLD_SIZE.y * 0.5) / MAP_WORLD_SIZE.y
	)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)


func _minimap_local_to_world_position(local_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(local_position.x - map_rect.position.x) / map_rect.size.x,
		(local_position.y - map_rect.position.y) / map_rect.size.y
	)
	normalized.x = clampf(normalized.x, 0.0, 1.0)
	normalized.y = clampf(normalized.y, 0.0, 1.0)
	return Vector2(
		normalized.x * MAP_WORLD_SIZE.x - MAP_WORLD_SIZE.x * 0.5,
		normalized.y * MAP_WORLD_SIZE.y - MAP_WORLD_SIZE.y * 0.5
	)


func _minimap_rect_for_world_rect(world_rect: Rect2, map_rect: Rect2) -> Rect2:
	var start := _world_to_minimap_position(world_rect.position, map_rect)
	var end := _world_to_minimap_position(world_rect.end, map_rect)
	var rect_position := Vector2(minf(start.x, end.x), minf(start.y, end.y))
	var rect_size := Vector2(absf(end.x - start.x), absf(end.y - start.y))
	return Rect2(rect_position, rect_size)


func _update_minimap_label() -> void:
	if minimap_label == null:
		return
	if not minimap_hover_valid:
		minimap_label.text = "Pasa el mouse para ubicarte.\nClick: centrar | doble click o derecho: zoom 5 km."
		return
	var region := _world_to_cell(minimap_hover_world)
	var sector := _world_to_sector_cell(minimap_hover_world)
	var detail := _world_to_surface_cell(minimap_hover_world)
	var local_km := (minimap_hover_world + MAP_WORLD_SIZE * 0.5) / 1000.0
	minimap_label.text = "Region " + _cell_label(region) + " | Sector " + _sector_cell_label(sector) + "\nDetalle " + _surface_cell_label(detail) + " | km " + str(int(local_km.x)) + ", " + str(int(local_km.y))


func _queue_minimap_redraw() -> void:
	if minimap_view != null:
		minimap_view.queue_redraw()


func _make_panel_style(bg_color: Color, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
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


func _make_button_style(bg_color: Color, border_color: Color, radius: int = 6) -> StyleBoxFlat:
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
	style.content_margin_left = 10
	style.content_margin_top = 7
	style.content_margin_right = 10
	style.content_margin_bottom = 7
	return style


func _make_mode_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.82, 0.84, 0.80, 0.95), Color(0.22, 0.24, 0.22, 0.30)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.88, 0.90, 0.86, 0.98), Color(0.22, 0.24, 0.22, 0.45)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.22, 0.34, 0.42, 0.95), Color(0.08, 0.13, 0.16, 0.75)))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


func _make_palette_button(text: String, source_color: Color) -> Button:
	var normal_color := source_color
	normal_color.a = 0.78
	var hover_color := source_color.lightened(0.18)
	hover_color.a = 0.86
	var pressed_color := source_color.darkened(0.18)
	pressed_color.a = 0.92
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_color, Color(0.08, 0.09, 0.08, 0.40)))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_color, Color(0.08, 0.09, 0.08, 0.55)))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_color, Color(0.03, 0.04, 0.03, 0.80)))
	button.add_theme_color_override("font_color", Color(0.04, 0.05, 0.05))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


func _make_view_toggle(text: String, view_key: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.80, 0.82, 0.79, 0.88), Color(0.14, 0.16, 0.14, 0.28), 5))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.86, 0.88, 0.84, 0.94), Color(0.14, 0.16, 0.14, 0.38), 5))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.28, 0.38, 0.42, 0.96), Color(0.08, 0.12, 0.14, 0.62), 5))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.pressed.connect(_toggle_view.bind(view_key))
	view_buttons[view_key] = button
	return button


func _make_detail_button(text: String, detail_km: float) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.80, 0.82, 0.79, 0.88), Color(0.14, 0.16, 0.14, 0.28), 5))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.86, 0.88, 0.84, 0.94), Color(0.14, 0.16, 0.14, 0.38), 5))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.32, 0.42, 0.34, 0.96), Color(0.09, 0.13, 0.10, 0.62), 5))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.pressed.connect(_set_surface_detail.bind(detail_km))
	return button


func _make_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.78, 0.80, 0.77, 0.95), Color(0.16, 0.18, 0.16, 0.35)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.84, 0.87, 0.83, 0.98), Color(0.16, 0.18, 0.16, 0.45)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.35, 0.42, 0.38, 0.98), Color(0.09, 0.11, 0.10, 0.70)))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


func _is_pointer_over_hud() -> bool:
	if hud_root == null:
		return false
	var mouse_position := get_viewport().get_mouse_position()
	if hud_root.get_global_rect().has_point(mouse_position):
		return true
	if minimap_panel != null and minimap_panel.get_global_rect().has_point(mouse_position):
		return true
	return false


func _process_camera_movement(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		var multiplier := 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			multiplier = FAST_PAN_MULTIPLIER
		elif Input.is_key_pressed(KEY_CTRL):
			multiplier = SLOW_PAN_MULTIPLIER
		camera.position += pan.normalized() * PAN_SPEED_SCREEN_PIXELS * multiplier * delta / max(camera.zoom.x, 0.004)


func _handle_mouse_button(mouse_button: InputEventMouseButton) -> void:
	if _is_pointer_over_hud():
		if mouse_button.pressed or mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_RIGHT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = false
			painting = false
			erasing = false
			surface_painting = false
			surface_erasing = false
			return
	if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = mouse_button.pressed
		last_mouse = mouse_button.position
	elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_mouse(1.12)
	elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_mouse(1.0 / 1.12)
	elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if tool_mode == TOOL_BIOMES:
			painting = mouse_button.pressed and not mouse_button.shift_pressed
			erasing = mouse_button.pressed and mouse_button.shift_pressed
			if mouse_button.pressed:
				_apply_brush(mouse_button.shift_pressed)
		elif tool_mode == TOOL_SURFACE_BUCKET and mouse_button.pressed:
			surface_painting = not mouse_button.shift_pressed
			surface_erasing = mouse_button.shift_pressed
			_reset_surface_drag_cache()
			_bucket_fill_surface(mouse_button.shift_pressed)
		elif tool_mode == TOOL_SURFACE_BUCKET:
			surface_painting = false
			surface_erasing = false
		elif tool_mode == TOOL_BARRIER_BRUSH:
			barrier_drawing = mouse_button.pressed and not mouse_button.shift_pressed
			barrier_erasing = mouse_button.pressed and mouse_button.shift_pressed
			if mouse_button.pressed:
				_apply_barrier_brush(mouse_button.shift_pressed)
	elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if tool_mode == TOOL_BIOMES:
			erasing = mouse_button.pressed
			if mouse_button.pressed:
				_apply_brush(true)
		elif tool_mode == TOOL_SURFACE_BUCKET and mouse_button.pressed:
			surface_painting = false
			surface_erasing = true
			_reset_surface_drag_cache()
			_bucket_fill_surface(true)
		elif tool_mode == TOOL_SURFACE_BUCKET:
			surface_erasing = false
		elif tool_mode == TOOL_BARRIER_BRUSH:
			barrier_erasing = mouse_button.pressed
			if mouse_button.pressed:
				_apply_barrier_brush(true)


func _handle_mouse_motion(mouse_motion: InputEventMouseMotion) -> void:
	if _is_pointer_over_hud():
		painting = false
		erasing = false
		surface_painting = false
		surface_erasing = false
		barrier_drawing = false
		barrier_erasing = false
		return
	if dragging:
		var drag_delta: Vector2 = mouse_motion.position - last_mouse
		camera.position -= drag_delta / max(camera.zoom.x, 0.004)
		last_mouse = mouse_motion.position
	elif tool_mode == TOOL_BIOMES and painting:
		_apply_brush(false)
	elif tool_mode == TOOL_BIOMES and erasing:
		_apply_brush(true)
	elif tool_mode == TOOL_SURFACE_BUCKET and surface_painting:
		_bucket_fill_surface(false)
	elif tool_mode == TOOL_SURFACE_BUCKET and surface_erasing:
		_bucket_fill_surface(true)
	elif tool_mode == TOOL_BARRIER_BRUSH and barrier_drawing:
		_apply_barrier_brush(false)
	elif tool_mode == TOOL_BARRIER_BRUSH and barrier_erasing:
		_apply_barrier_brush(true)


func _handle_key(key_event: InputEventKey) -> void:
	var number := int(key_event.keycode) - int(KEY_0)
	if key_event.keycode == KEY_TAB:
		_toggle_tool_mode()
	elif tool_mode == TOOL_BIOMES and number >= 1 and number <= 7:
		_select_biome(number)
	elif tool_mode == TOOL_SURFACE_BUCKET and number >= 1 and number <= 4:
		_select_surface(number)
	elif key_event.ctrl_pressed and key_event.keycode == KEY_S:
		_save_all_layers()
	elif key_event.ctrl_pressed and key_event.keycode == KEY_L:
		_load_all_layers()
	elif key_event.keycode == KEY_R:
		_reset_camera()
	elif key_event.keycode == KEY_G:
		_toggle_view("grid")
	elif key_event.keycode == KEY_B:
		_toggle_view("map")
	elif key_event.keycode == KEY_M:
		_toggle_view("mask")
	elif key_event.keycode == KEY_C:
		_toggle_view("biomes")
	elif key_event.keycode == KEY_L:
		_toggle_view("barriers")
	elif key_event.keycode == KEY_X:
		_toggle_view("sectors")
	elif key_event.keycode == KEY_DELETE and _is_cell_inside(hovered_cell):
		_erase_cell(hovered_cell)


func _toggle_tool_mode() -> void:
	if tool_mode == TOOL_BIOMES:
		_set_tool_mode(TOOL_SURFACE_BUCKET)
	elif tool_mode == TOOL_SURFACE_BUCKET:
		_set_tool_mode(TOOL_BARRIER_BRUSH)
	else:
		_set_tool_mode(TOOL_BIOMES)


func _set_tool_mode(next_mode: int) -> void:
	tool_mode = next_mode
	painting = false
	erasing = false
	surface_painting = false
	surface_erasing = false
	_reset_surface_drag_cache()
	barrier_drawing = false
	barrier_erasing = false
	if tool_mode == TOOL_BIOMES:
		_set_status("Modo biomas: pinta recuadros de 10 km x 10 km.")
	elif tool_mode == TOOL_SURFACE_BUCKET:
		_set_status("Modo balde: rellena tierra/agua dentro del detalle elegido.")
	else:
		_set_status("Modo lineas: repasa barreras para cerrar costas o corregir fugas.")
	_update_ui()
	queue_redraw()


func _select_biome(biome_id: int) -> void:
	selected_biome = biome_id
	_set_tool_mode(TOOL_BIOMES)
	_set_status("Bioma seleccionado: " + _get_biome_name(selected_biome))


func _select_surface(surface_id: int) -> void:
	selected_surface = surface_id
	_set_tool_mode(TOOL_SURFACE_BUCKET)
	_set_status("Superficie seleccionada: " + _get_surface_name(selected_surface))


func _set_surface_detail(detail_km: float) -> void:
	surface_detail_cell_side_km = detail_km
	_reset_surface_drag_cache()
	_set_tool_mode(TOOL_SURFACE_BUCKET)
	_set_status("Detalle tierra/agua: " + str(int(surface_detail_cell_side_km)) + " km x " + str(int(surface_detail_cell_side_km)) + " km.")


func _toggle_view(view_key: String) -> void:
	match view_key:
		"map":
			show_map = not show_map
		"mask":
			show_surface_mask = not show_surface_mask
		"biomes":
			show_biomes = not show_biomes
		"grid":
			show_grid = not show_grid
		"barriers":
			show_barriers = not show_barriers
		"sectors":
			show_sectors = not show_sectors
	_sync_hud_buttons()
	queue_redraw()


func _reset_camera() -> void:
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.0042, 0.0042)


func _zoom_at_mouse(factor: float) -> void:
	var before := get_global_mouse_position()
	var next_zoom := clampf(camera.zoom.x * factor, 0.0025, 0.35)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after := get_global_mouse_position()
	camera.position += before - after


func _apply_brush(erase: bool = false) -> void:
	var cell := _world_to_cell(get_global_mouse_position())
	if not _is_cell_inside(cell):
		return
	if erase:
		_erase_cell(cell)
	else:
		var key := _cell_key(cell)
		if biome_cells.get(key, -1) != selected_biome:
			biome_cells[key] = selected_biome
			_set_status("Pintado " + _cell_label(cell) + " como " + _get_biome_name(selected_biome))
			queue_redraw()


func _erase_cell(cell: Vector2i) -> void:
	var key := _cell_key(cell)
	if biome_cells.has(key):
		biome_cells.erase(key)
		_set_status("Celda borrada: " + _cell_label(cell))
		queue_redraw()


func _bucket_fill_surface(erase: bool = false) -> void:
	var mouse_world_position := get_global_mouse_position()
	var start_detail_cell := _world_to_surface_cell(mouse_world_position)
	if not _is_surface_cell_inside(start_detail_cell):
		_set_status("Balde fuera de la grilla de detalle.")
		return
	var cell_bounds := _surface_cell_pixel_bounds(start_detail_cell)
	var min_x := cell_bounds[0]
	var max_x := cell_bounds[1]
	var min_y := cell_bounds[2]
	var max_y := cell_bounds[3]

	var start_pixel := _world_to_image_pixel(mouse_world_position)
	if not _is_pixel_inside(start_pixel):
		_set_status("Balde fuera del mapa.")
		return
	var start_index := _pixel_to_index(start_pixel)
	if barrier_mask[start_index] == 1:
		_set_status("Ese punto es una linea/borde del boceto. Haz clic dentro de una region.")
		return
	if start_detail_cell == last_surface_bucket_cell and erase == last_surface_bucket_erase:
		return
	last_surface_bucket_cell = start_detail_cell
	last_surface_bucket_erase = erase

	var fill_color := Color.TRANSPARENT
	var action_name := "Borrado"
	if not erase:
		fill_color = _get_surface_color(selected_surface)
		action_name = "Relleno " + _get_surface_name(selected_surface)

	var width := int(MAP_IMAGE_SIZE.x)
	var height := int(MAP_IMAGE_SIZE.y)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	queue.append(start_index)
	var head := 0
	var painted_pixels := 0

	while head < queue.size():
		var index: int = queue[head]
		head += 1
		if visited[index] == 1:
			continue
		visited[index] = 1
		if barrier_mask[index] == 1:
			continue

		var y := int(index / width)
		var x := index - y * width
		if x < min_x or x >= max_x or y < min_y or y >= max_y:
			continue
		surface_image.set_pixel(x, y, fill_color)
		painted_pixels += 1

		if x > min_x:
			queue.append(index - 1)
		if x < max_x - 1:
			queue.append(index + 1)
		if y > min_y:
			queue.append(index - width)
		if y < max_y - 1:
			queue.append(index + width)

	_refresh_surface_texture()
	_set_status(action_name + " en detalle " + _surface_cell_label(start_detail_cell) + ": " + str(painted_pixels) + " pixeles.")
	queue_redraw()


func _reset_surface_drag_cache() -> void:
	last_surface_bucket_cell = Vector2i(-999999, -999999)
	last_surface_bucket_erase = false


func _apply_barrier_brush(erase: bool = false) -> void:
	var center := _world_to_image_pixel(get_global_mouse_position())
	if not _is_pixel_inside(center):
		return
	var width := int(MAP_IMAGE_SIZE.x)
	var height := int(MAP_IMAGE_SIZE.y)
	var radius_squared := BARRIER_BRUSH_RADIUS * BARRIER_BRUSH_RADIUS
	var min_x := maxi(0, center.x - BARRIER_BRUSH_RADIUS)
	var max_x := mini(width - 1, center.x + BARRIER_BRUSH_RADIUS)
	var min_y := maxi(0, center.y - BARRIER_BRUSH_RADIUS)
	var max_y := mini(height - 1, center.y + BARRIER_BRUSH_RADIUS)
	var pixel_color := Color(0.02, 0.02, 0.02, 0.68)
	if erase:
		pixel_color = Color.TRANSPARENT
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius_squared:
				var index := y * width + x
				barrier_mask[index] = 0 if erase else 1
				barrier_image.set_pixel(x, y, pixel_color)
	if barrier_texture != null:
		barrier_texture.update(barrier_image)
	_set_status("Lineas: " + ("borrando" if erase else "dibujando") + " barrera.")
	queue_redraw()


func _draw_painted_cells() -> void:
	for key in biome_cells.keys():
		var cell := _cell_from_key(str(key))
		if _is_cell_inside(cell):
			var biome_id := int(biome_cells[key])
			var rect := _cell_rect(cell)
			draw_rect(rect, _get_biome_color(biome_id), true)
			draw_rect(rect, Color(0.02, 0.02, 0.02, 0.18), false, 42.0)


func _draw_surface_mask(map_rect: Rect2) -> void:
	if surface_texture != null:
		draw_texture_rect(surface_texture, map_rect, false, Color.WHITE)


func _draw_barriers(map_rect: Rect2) -> void:
	if barrier_texture != null:
		draw_texture_rect(barrier_texture, map_rect, false, Color.WHITE)


func _draw_grid(map_rect: Rect2) -> void:
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), GRID_COLOR, 52.0, true)
		x += GRID_STEP
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), GRID_COLOR, 52.0, true)
		y += GRID_STEP


func _draw_surface_detail_grid(map_rect: Rect2) -> void:
	var step := _surface_detail_step()
	var detail_color := Color(0.04, 0.06, 0.07, 0.18)
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), detail_color, 18.0, true)
		x += step
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), detail_color, 18.0, true)
		y += step


func _draw_sector_grid(map_rect: Rect2) -> void:
	var sector_color := Color(0.02, 0.025, 0.03, 0.34)
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), sector_color, 30.0, true)
		x += SECTOR_STEP
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), sector_color, 30.0, true)
		y += SECTOR_STEP


func _draw_hover_cell() -> void:
	if not _is_cell_inside(hovered_cell):
		return
	var rect := _cell_rect(hovered_cell)
	draw_rect(rect, HOVER_COLOR, false, 120.0)


func _save_all_layers() -> void:
	_save_layer()
	_save_surface_mask()
	_save_barrier_mask()


func _load_all_layers() -> void:
	_load_layer()
	_load_surface_mask()
	_load_barrier_mask()


func _save_layer() -> void:
	var payload := {
		"version": 1,
		"scale": {
			"meters_per_pixel": MAP_WORLD_SCALE,
			"grid_cell_side_km": GRID_CELL_SIDE_KM,
			"grid_cell_area_km2": GRID_CELL_SIDE_KM * GRID_CELL_SIDE_KM,
		},
		"cells": biome_cells,
	}
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_set_status("No pude guardar en " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	_set_status("Capa guardada en " + SAVE_PATH)


func _save_surface_mask() -> void:
	var absolute_path := ProjectSettings.globalize_path(SURFACE_MASK_PATH)
	var error := surface_image.save_png(absolute_path)
	if error != OK:
		_set_status("Biomas guardados, pero no pude guardar mascara de superficie.")
		return
	_set_status("Capas guardadas: biomas + mascara tierra/agua.")


func _save_barrier_mask() -> void:
	var absolute_path := ProjectSettings.globalize_path("res://data/map_design_barriers.png")
	var error := barrier_image.save_png(absolute_path)
	if error != OK:
		_set_status("Capas guardadas, pero no pude guardar lineas.")
		return
	_set_status("Capas guardadas: biomas + mascara + lineas.")


func _load_layer() -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(absolute_path):
		biome_cells.clear()
		_set_status("No hay capa guardada todavia.")
		queue_redraw()
		return
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		_set_status("No pude leer " + SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("El archivo de biomas no tiene formato valido.")
		return
	var cells: Variant = parsed.get("cells", {})
	if typeof(cells) != TYPE_DICTIONARY:
		_set_status("El archivo de biomas no contiene celdas validas.")
		return
	biome_cells.clear()
	for key in cells.keys():
		biome_cells[str(key)] = int(cells[key])
	_set_status("Capa cargada: " + str(biome_cells.size()) + " celdas pintadas.")
	queue_redraw()


func _load_surface_mask() -> void:
	var absolute_path := ProjectSettings.globalize_path(SURFACE_MASK_PATH)
	if not FileAccess.file_exists(absolute_path):
		_create_empty_surface_mask()
		return
	var loaded_image := Image.new()
	var error := loaded_image.load(absolute_path)
	if error != OK:
		_create_empty_surface_mask()
		_set_status("No pude cargar la mascara de superficie.")
		return
	loaded_image.convert(Image.FORMAT_RGBA8)
	if loaded_image.get_width() != int(MAP_IMAGE_SIZE.x) or loaded_image.get_height() != int(MAP_IMAGE_SIZE.y):
		_create_empty_surface_mask()
		_set_status("La mascara tenia otro tamano; cree una nueva.")
		return
	surface_image = loaded_image
	_refresh_surface_texture()
	queue_redraw()


func _load_barrier_mask() -> void:
	var absolute_path := ProjectSettings.globalize_path("res://data/map_design_barriers.png")
	if not FileAccess.file_exists(absolute_path):
		return
	var loaded_image := Image.new()
	var error := loaded_image.load(absolute_path)
	if error != OK:
		_set_status("No pude cargar las lineas guardadas.")
		return
	loaded_image.convert(Image.FORMAT_RGBA8)
	if loaded_image.get_width() != int(MAP_IMAGE_SIZE.x) or loaded_image.get_height() != int(MAP_IMAGE_SIZE.y):
		_set_status("Las lineas guardadas tenian otro tamano; uso las del boceto.")
		return
	barrier_image = loaded_image
	_rebuild_barrier_mask_from_image()
	barrier_texture = ImageTexture.create_from_image(barrier_image)
	queue_redraw()


func _export_sector_map() -> void:
	var columns := int(ceil(MAP_WORLD_SIZE.x / SECTOR_STEP))
	var rows := int(ceil(MAP_WORLD_SIZE.y / SECTOR_STEP))
	var sectors := {}
	for y in range(rows):
		for x in range(columns):
			var sector := Vector2i(x, y)
			var macro_region := _sector_to_macro_region(sector)
			var biome_id := int(biome_cells.get(_cell_key(macro_region), 0))
			var surface_counts := _surface_counts_for_sector(sector)
			var dominant_surface_id := _dominant_surface_id(surface_counts)
			var key := _sector_key(sector)
			sectors[key] = {
				"coord": [x, y],
				"size_km": SECTOR_CELL_SIDE_KM,
				"macro_region": [macro_region.x, macro_region.y],
				"biome_id": biome_id,
				"biome": _get_biome_name(biome_id),
				"dominant_surface_id": dominant_surface_id,
				"dominant_surface": _get_surface_export_name(dominant_surface_id),
				"surface_counts": surface_counts,
			}

	var payload := {
		"version": 1,
		"scale": {
			"meters_per_pixel": MAP_WORLD_SCALE,
			"world_km": [MAP_WORLD_SIZE.x / 1000.0, MAP_WORLD_SIZE.y / 1000.0],
			"macro_region_side_km": GRID_CELL_SIDE_KM,
			"sector_side_km": SECTOR_CELL_SIDE_KM,
			"columns": columns,
			"rows": rows,
		},
		"sectors": sectors,
	}
	var absolute_path := ProjectSettings.globalize_path(SECTOR_EXPORT_PATH)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_set_status("No pude exportar sectores en " + SECTOR_EXPORT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	_set_status("Sectores exportados: " + str(columns * rows) + " sectores de 5 km.")


func _rebuild_barrier_mask_from_image() -> void:
	var width := int(MAP_IMAGE_SIZE.x)
	var height := int(MAP_IMAGE_SIZE.y)
	barrier_mask.resize(width * height)
	for y in range(height):
		for x in range(width):
			var color := barrier_image.get_pixel(x, y)
			barrier_mask[y * width + x] = 1 if color.a > 0.1 else 0


func _world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position + MAP_WORLD_SIZE * 0.5
	return Vector2i(int(floor(local_position.x / GRID_STEP)), int(floor(local_position.y / GRID_STEP)))


func _surface_detail_step() -> float:
	return surface_detail_cell_side_km * 1000.0


func _world_to_surface_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position + MAP_WORLD_SIZE * 0.5
	var step := _surface_detail_step()
	return Vector2i(int(floor(local_position.x / step)), int(floor(local_position.y / step)))


func _world_to_sector_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position + MAP_WORLD_SIZE * 0.5
	return Vector2i(int(floor(local_position.x / SECTOR_STEP)), int(floor(local_position.y / SECTOR_STEP)))


func _world_to_image_pixel(world_position: Vector2) -> Vector2i:
	var local_position := (world_position + MAP_WORLD_SIZE * 0.5) / MAP_WORLD_SCALE
	return Vector2i(int(floor(local_position.x)), int(floor(local_position.y)))


func _cell_pixel_bounds(cell: Vector2i) -> PackedInt32Array:
	var pixels_per_cell := GRID_STEP / MAP_WORLD_SCALE
	var start_x := int(floor(float(cell.x) * pixels_per_cell))
	var start_y := int(floor(float(cell.y) * pixels_per_cell))
	var end_x := int(ceil(float(cell.x + 1) * pixels_per_cell))
	var end_y := int(ceil(float(cell.y + 1) * pixels_per_cell))
	end_x = mini(int(MAP_IMAGE_SIZE.x), end_x)
	end_y = mini(int(MAP_IMAGE_SIZE.y), end_y)
	return PackedInt32Array([start_x, end_x, start_y, end_y])


func _surface_cell_pixel_bounds(cell: Vector2i) -> PackedInt32Array:
	var pixels_per_cell := _surface_detail_step() / MAP_WORLD_SCALE
	var start_x := int(floor(float(cell.x) * pixels_per_cell))
	var start_y := int(floor(float(cell.y) * pixels_per_cell))
	var end_x := int(ceil(float(cell.x + 1) * pixels_per_cell))
	var end_y := int(ceil(float(cell.y + 1) * pixels_per_cell))
	end_x = mini(int(MAP_IMAGE_SIZE.x), end_x)
	end_y = mini(int(MAP_IMAGE_SIZE.y), end_y)
	return PackedInt32Array([start_x, end_x, start_y, end_y])


func _sector_pixel_bounds(cell: Vector2i) -> PackedInt32Array:
	var pixels_per_cell := SECTOR_STEP / MAP_WORLD_SCALE
	var start_x := int(floor(float(cell.x) * pixels_per_cell))
	var start_y := int(floor(float(cell.y) * pixels_per_cell))
	var end_x := int(ceil(float(cell.x + 1) * pixels_per_cell))
	var end_y := int(ceil(float(cell.y + 1) * pixels_per_cell))
	end_x = mini(int(MAP_IMAGE_SIZE.x), end_x)
	end_y = mini(int(MAP_IMAGE_SIZE.y), end_y)
	return PackedInt32Array([start_x, end_x, start_y, end_y])


func _is_pixel_inside(pixel: Vector2i) -> bool:
	return pixel.x >= 0 and pixel.y >= 0 and pixel.x < int(MAP_IMAGE_SIZE.x) and pixel.y < int(MAP_IMAGE_SIZE.y)


func _pixel_to_index(pixel: Vector2i) -> int:
	return pixel.y * int(MAP_IMAGE_SIZE.x) + pixel.x


func _is_cell_inside(cell: Vector2i) -> bool:
	var columns := int(ceil(MAP_WORLD_SIZE.x / GRID_STEP))
	var rows := int(ceil(MAP_WORLD_SIZE.y / GRID_STEP))
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _is_surface_cell_inside(cell: Vector2i) -> bool:
	var step := _surface_detail_step()
	var columns := int(ceil(MAP_WORLD_SIZE.x / step))
	var rows := int(ceil(MAP_WORLD_SIZE.y / step))
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _is_sector_cell_inside(cell: Vector2i) -> bool:
	var columns := int(ceil(MAP_WORLD_SIZE.x / SECTOR_STEP))
	var rows := int(ceil(MAP_WORLD_SIZE.y / SECTOR_STEP))
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _cell_rect(cell: Vector2i) -> Rect2:
	var local_position := Vector2(float(cell.x) * GRID_STEP, float(cell.y) * GRID_STEP)
	var remaining_width := MAP_WORLD_SIZE.x - local_position.x
	var remaining_height := MAP_WORLD_SIZE.y - local_position.y
	var cell_size := Vector2(minf(GRID_STEP, remaining_width), minf(GRID_STEP, remaining_height))
	return Rect2(local_position - MAP_WORLD_SIZE * 0.5, cell_size)


func _sector_rect(cell: Vector2i) -> Rect2:
	var local_position := Vector2(float(cell.x) * SECTOR_STEP, float(cell.y) * SECTOR_STEP)
	var remaining_width := MAP_WORLD_SIZE.x - local_position.x
	var remaining_height := MAP_WORLD_SIZE.y - local_position.y
	var cell_size := Vector2(minf(SECTOR_STEP, remaining_width), minf(SECTOR_STEP, remaining_height))
	return Rect2(local_position - MAP_WORLD_SIZE * 0.5, cell_size)


func _cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)


func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _cell_label(cell: Vector2i) -> String:
	return "[" + str(cell.x) + ", " + str(cell.y) + "]"


func _surface_cell_label(cell: Vector2i) -> String:
	return "[" + str(cell.x) + ", " + str(cell.y) + "]"


func _sector_cell_label(cell: Vector2i) -> String:
	return "[" + str(cell.x) + ", " + str(cell.y) + "]"


func _sector_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)


func _sector_to_macro_region(sector: Vector2i) -> Vector2i:
	var world_x := float(sector.x) * SECTOR_STEP
	var world_y := float(sector.y) * SECTOR_STEP
	return Vector2i(int(floor(world_x / GRID_STEP)), int(floor(world_y / GRID_STEP)))


func _surface_counts_for_sector(sector: Vector2i) -> Dictionary:
	var bounds := _sector_pixel_bounds(sector)
	var counts := {
		"unknown": 0,
		"land": 0,
		"water": 0,
		"coast": 0,
		"deep_water": 0,
	}
	for y in range(bounds[2], bounds[3]):
		for x in range(bounds[0], bounds[1]):
			var surface_id := _surface_id_from_color(surface_image.get_pixel(x, y))
			var surface_key := _get_surface_export_name(surface_id)
			counts[surface_key] = int(counts[surface_key]) + 1
	return counts


func _dominant_surface_id(counts: Dictionary) -> int:
	var best_id := 0
	var best_count := -1
	for surface_id in [1, 2, 3, 4, 0]:
		var key := _get_surface_export_name(surface_id)
		var count := int(counts.get(key, 0))
		if count > best_count:
			best_count = count
			best_id = surface_id
	return best_id


func _update_ui() -> void:
	var hover_text := "fuera del mapa"
	if _is_cell_inside(hovered_cell):
		hover_text = _cell_label(hovered_cell)
	var detail_hover := _world_to_surface_cell(get_global_mouse_position())
	var detail_text := "fuera del mapa"
	if _is_surface_cell_inside(detail_hover):
		detail_text = _surface_cell_label(detail_hover)
	var sector_hover := _world_to_sector_cell(get_global_mouse_position())
	var sector_text := "fuera del mapa"
	if _is_sector_cell_inside(sector_hover):
		sector_text = _sector_cell_label(sector_hover)
	var mode_text := "Biomas por recuadro"
	var selection_text := _get_biome_name(selected_biome)
	if tool_mode == TOOL_SURFACE_BUCKET:
		mode_text = "Balde tierra/agua"
		selection_text = _get_surface_name(selected_surface)
	elif tool_mode == TOOL_BARRIER_BRUSH:
		mode_text = "Lineas / cierres"
		selection_text = "Barrera manual"
	notes_label.text = "Capas del mapa"
	current_label.text = "Modo: " + mode_text + "\nActual: " + selection_text
	hover_label.text = "Region: " + hover_text + " (10 km)\nSector: " + sector_text + " (5 km)\nDetalle: " + detail_text + " (" + str(int(surface_detail_cell_side_km)) + " km)"
	biome_palette.visible = tool_mode == TOOL_BIOMES
	surface_palette.visible = tool_mode == TOOL_SURFACE_BUCKET
	surface_detail_row.visible = tool_mode == TOOL_SURFACE_BUCKET
	barrier_palette.visible = tool_mode == TOOL_BARRIER_BRUSH
	_sync_hud_buttons()


func _sync_hud_buttons() -> void:
	if mode_biomes_button != null:
		mode_biomes_button.button_pressed = tool_mode == TOOL_BIOMES
	if mode_surface_button != null:
		mode_surface_button.button_pressed = tool_mode == TOOL_SURFACE_BUCKET
	if mode_barrier_button != null:
		mode_barrier_button.button_pressed = tool_mode == TOOL_BARRIER_BRUSH
	for index in range(biome_buttons.size()):
		biome_buttons[index].button_pressed = tool_mode == TOOL_BIOMES and selected_biome == index + 1
	for index in range(surface_buttons.size()):
		surface_buttons[index].button_pressed = tool_mode == TOOL_SURFACE_BUCKET and selected_surface == index + 1
	for index in range(surface_detail_buttons.size()):
		var detail_size: float = [10.0, 5.0, 2.0, 1.0][index]
		surface_detail_buttons[index].button_pressed = is_equal_approx(surface_detail_cell_side_km, detail_size)
	_set_view_button_state("map", show_map)
	_set_view_button_state("mask", show_surface_mask)
	_set_view_button_state("biomes", show_biomes)
	_set_view_button_state("grid", show_grid)
	_set_view_button_state("barriers", show_barriers)
	_set_view_button_state("sectors", show_sectors)


func _set_view_button_state(view_key: String, enabled: bool) -> void:
	if not view_buttons.has(view_key):
		return
	var button: Button = view_buttons[view_key] as Button
	if button != null:
		button.button_pressed = enabled


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


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


func _get_biome_color(biome_id: int) -> Color:
	match biome_id:
		1:
			return Color(0.22, 0.62, 0.28, 0.44)
		2:
			return Color(0.88, 0.68, 0.28, 0.48)
		3:
			return Color(0.06, 0.45, 0.28, 0.50)
		4:
			return Color(0.78, 0.90, 0.96, 0.56)
		5:
			return Color(0.46, 0.42, 0.38, 0.52)
		6:
			return Color(0.25, 0.38, 0.22, 0.54)
		7:
			return Color(0.55, 0.28, 0.72, 0.48)
		_:
			return Color.TRANSPARENT


func _get_surface_name(surface_id: int) -> String:
	match surface_id:
		1:
			return "Tierra"
		2:
			return "Agua"
		3:
			return "Costa"
		4:
			return "Agua profunda"
		_:
			return "Sin superficie"


func _get_surface_color(surface_id: int) -> Color:
	match surface_id:
		1:
			return Color(0.16, 0.58, 0.24, 0.36)
		2:
			return Color(0.05, 0.36, 0.78, 0.46)
		3:
			return Color(0.92, 0.74, 0.38, 0.48)
		4:
			return Color(0.02, 0.12, 0.42, 0.56)
		_:
			return Color.TRANSPARENT


func _surface_id_from_color(color: Color) -> int:
	if color.a <= 0.05:
		return 0
	if color.r > 0.70 and color.g > 0.50 and color.b < 0.50:
		return 3
	if color.g > color.r * 1.7 and color.g > color.b * 0.70 and color.r < 0.40:
		return 1
	if color.b > 0.35 and color.r < 0.08 and color.g < 0.20:
		return 4
	if color.b > 0.35 and color.r < 0.28 and color.g > 0.15:
		return 2
	return 0


func _get_surface_export_name(surface_id: int) -> String:
	match surface_id:
		1:
			return "land"
		2:
			return "water"
		3:
			return "coast"
		4:
			return "deep_water"
		_:
			return "unknown"
