@tool
extends PanelContainer

const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const SECTOR_OVERRIDES_PATH := "res://data/terrain3d_sector_overrides.json"
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
const TERRAIN3D_ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const TERRAIN3D_MATERIAL_PATH := "res://assets/environment/terrain/jueguito_terrain_material.tres"
const NO_SECTOR := Vector2i(-9999, -9999)
const SECTOR_EXPORTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_sector_exporter.gd")
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const MAP_WORLD_SCALE := 200.0
const MAP_WORLD_SIZE := MAP_IMAGE_SIZE * MAP_WORLD_SCALE
const SECTOR_SIDE_METERS := 5000.0
const MAP_VIEW_SIZE := Vector2(320.0, 184.0)
const SELECTION_DRAG_THRESHOLD := 6.0
const SURFACE_UNKNOWN := 0
const SURFACE_LAND := 1
const SURFACE_WATER := 2
const SURFACE_COAST := 3
const SURFACE_DEEP_WATER := 4

var editor_interface
var sector_data: Dictionary = {}
var sector_overrides: Dictionary = {}
var map_texture: Texture2D
var surface_texture: Texture2D
var map_view: Control
var hover_label: Label
var selected_label: Label
var details_label: Label
var status_label: Label
var confirm_dialog: ConfirmationDialog
var root_layout: VBoxContainer
var options_scroll: ScrollContainer
var options_layout: VBoxContainer
var collapse_button: Button
var pin_button: Button
var progress_bar: ProgressBar
var progress_label: Label
var auto_import_check: CheckBox
var show_surface_check: CheckBox
var show_biomes_check: CheckBox
var use_biomes_check: CheckBox
var biome_override_option: OptionButton
var surface_override_option: OptionButton
var apply_override_button: Button
var clear_override_button: Button
var generate_import_button: Button
var generate_selection_button: Button
var regenerate_selection_button: Button
var clear_selection_button: Button
var load_sector_button: Button
var exported_sectors: Dictionary = {}
var multi_selected_sectors: Dictionary = {}
var selected_sector := Vector2i(33, 19)
var loaded_sector := NO_SECTOR
var hovered_sector := Vector2i(-1, -1)
var map_zoom := 1.0
var map_pan := Vector2.ZERO
var map_dragging := false
var map_drag_last := Vector2.ZERO
var selection_mouse_down := false
var selection_dragging := false
var selection_additive_drag := false
var selection_drag_start := Vector2.ZERO
var selection_drag_current := Vector2.ZERO
var selection_drag_base: Dictionary = {}
var generation_in_progress := false
var dock_collapsed := false
var dock_pinned := false
var batch_current_index := 0
var batch_total_count := 0
var pending_generation_action := ""
var pending_generation_skip_exported := true


func setup(p_editor_interface) -> void:
	editor_interface = p_editor_interface


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 560.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	map_texture = load(MAP_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(SURFACE_MASK_PATH):
		surface_texture = load(SURFACE_MASK_PATH) as Texture2D
	_load_sector_data()
	_load_sector_overrides()
	_build_ui()
	_refresh_exports()


func _exit_tree() -> void:
	if loaded_sector != NO_SECTOR and not generation_in_progress:
		_save_loaded_sector()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	root_layout = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 8)
	margin.add_child(root_layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_layout.add_child(header)

	var title := Label.new()
	title.text = "Mapa Sectores MMO"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	pin_button = Button.new()
	pin_button.text = "Pin"
	pin_button.tooltip_text = "Mantener desplegado"
	pin_button.toggle_mode = true
	pin_button.custom_minimum_size = Vector2(44.0, 28.0)
	pin_button.pressed.connect(_toggle_pinned)
	header.add_child(pin_button)

	collapse_button = Button.new()
	collapse_button.text = "-"
	collapse_button.tooltip_text = "Minimizar/restaurar"
	collapse_button.custom_minimum_size = Vector2(30.0, 28.0)
	collapse_button.pressed.connect(_toggle_collapsed)
	header.add_child(collapse_button)

	map_view = Control.new()
	map_view.custom_minimum_size = MAP_VIEW_SIZE
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_view.clip_contents = true
	map_view.draw.connect(_draw_map)
	map_view.gui_input.connect(_handle_map_input)
	map_view.mouse_exited.connect(_clear_hover)
	root_layout.add_child(map_view)

	options_scroll = ScrollContainer.new()
	options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_scroll.custom_minimum_size = Vector2(0.0, 180.0)
	root_layout.add_child(options_scroll)

	options_layout = VBoxContainer.new()
	options_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_layout.add_theme_constant_override("separation", 8)
	options_scroll.add_child(options_layout)

	var view_section := _make_section("Vista")
	hover_label = Label.new()
	hover_label.text = "Hover: -"
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_section.add_child(hover_label)

	var layer_row := HBoxContainer.new()
	layer_row.add_theme_constant_override("separation", 8)
	view_section.add_child(layer_row)

	show_surface_check = CheckBox.new()
	show_surface_check.text = "Superficies"
	show_surface_check.button_pressed = true
	show_surface_check.toggled.connect(_queue_map_redraw.unbind(1))
	layer_row.add_child(show_surface_check)

	show_biomes_check = CheckBox.new()
	show_biomes_check.text = "Biomas"
	show_biomes_check.button_pressed = false
	show_biomes_check.toggled.connect(_queue_map_redraw.unbind(1))
	layer_row.add_child(show_biomes_check)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	view_section.add_child(zoom_row)

	var zoom_out_button := Button.new()
	zoom_out_button.text = "Zoom -"
	zoom_out_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_out_button.pressed.connect(_zoom_map_from_center.bind(1.0 / 1.35))
	zoom_row.add_child(zoom_out_button)

	var reset_zoom_button := Button.new()
	reset_zoom_button.text = "100%"
	reset_zoom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_zoom_button.pressed.connect(_reset_map_view)
	zoom_row.add_child(reset_zoom_button)

	var zoom_in_button := Button.new()
	zoom_in_button.text = "Zoom +"
	zoom_in_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_in_button.pressed.connect(_zoom_map_from_center.bind(1.35))
	zoom_row.add_child(zoom_in_button)

	var sector_section := _make_section("Sector")
	selected_label = Label.new()
	selected_label.text = "Seleccionado: -"
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sector_section.add_child(selected_label)

	details_label = Label.new()
	details_label.text = "Sin sector."
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sector_section.add_child(details_label)

	var sector_options_row := HBoxContainer.new()
	sector_options_row.add_theme_constant_override("separation", 8)
	sector_section.add_child(sector_options_row)

	auto_import_check = CheckBox.new()
	auto_import_check.text = "Cargar al click"
	auto_import_check.button_pressed = true
	sector_options_row.add_child(auto_import_check)

	var open_painter_button := Button.new()
	open_painter_button.text = "Abrir pintor"
	open_painter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_painter_button.pressed.connect(_open_map_painter)
	sector_options_row.add_child(open_painter_button)

	var terrain_section := _make_section("Terrain3D")
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	terrain_section.add_child(button_row)

	var refresh_button := Button.new()
	refresh_button.text = "Actualizar exports"
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_refresh_exports)
	button_row.add_child(refresh_button)

	load_sector_button = Button.new()
	load_sector_button.text = "Cargar sector"
	load_sector_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_sector_button.tooltip_text = "Carga el sector. Si tiene ediciones guardadas, las recupera; si no, importa el terreno generado."
	load_sector_button.pressed.connect(_import_selected_sector_centered.bind(false))
	button_row.add_child(load_sector_button)

	var save_sector_button := Button.new()
	save_sector_button.text = "Guardar sector"
	save_sector_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_sector_button.tooltip_text = "Guarda tus ediciones manuales del sector y la libreria compartida de texturas Terrain3D."
	save_sector_button.pressed.connect(_save_current_sector_pressed)
	button_row.add_child(save_sector_button)

	var generation_section := _make_section("Generacion")
	use_biomes_check = CheckBox.new()
	use_biomes_check.text = "Usar biomas"
	use_biomes_check.button_pressed = false
	use_biomes_check.tooltip_text = "Apagado: genera solo con tierra, costa, agua y agua profunda."
	use_biomes_check.toggled.connect(_update_labels.unbind(1))
	generation_section.add_child(use_biomes_check)

	var override_hint := Label.new()
	override_hint.text = "Correccion de generacion"
	override_hint.add_theme_font_size_override("font_size", 12)
	generation_section.add_child(override_hint)

	var biome_row := HBoxContainer.new()
	biome_row.add_theme_constant_override("separation", 6)
	generation_section.add_child(biome_row)

	var biome_label := Label.new()
	biome_label.text = "Bioma"
	biome_label.custom_minimum_size = Vector2(72.0, 0.0)
	biome_row.add_child(biome_label)

	biome_override_option = OptionButton.new()
	biome_override_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biome_override_option.tooltip_text = "El bioma afecta el export cuando Usar biomas esta encendido. Mantener deja el valor del mapa base."
	_populate_biome_override_option()
	biome_row.add_child(biome_override_option)

	var surface_row := HBoxContainer.new()
	surface_row.add_theme_constant_override("separation", 6)
	generation_section.add_child(surface_row)

	var surface_label := Label.new()
	surface_label.text = "Terreno"
	surface_label.custom_minimum_size = Vector2(72.0, 0.0)
	surface_row.add_child(surface_label)

	surface_override_option = OptionButton.new()
	surface_override_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_override_option.tooltip_text = "Fuerza el tipo de terreno al regenerar: tierra, costa, agua o agua profunda."
	_populate_surface_override_option()
	surface_row.add_child(surface_override_option)

	var override_button_row := HBoxContainer.new()
	override_button_row.add_theme_constant_override("separation", 6)
	generation_section.add_child(override_button_row)

	apply_override_button = Button.new()
	apply_override_button.text = "Aplicar correccion"
	apply_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_override_button.tooltip_text = "Guarda la correccion para el sector o seleccion multiple. Luego usa Generar para reexportar."
	apply_override_button.pressed.connect(_apply_generation_overrides)
	override_button_row.add_child(apply_override_button)

	clear_override_button = Button.new()
	clear_override_button.text = "Limpiar correccion"
	clear_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_override_button.tooltip_text = "Quita la correccion y vuelve a usar el mapa base."
	clear_override_button.pressed.connect(_clear_generation_overrides)
	override_button_row.add_child(clear_override_button)

	generate_import_button = Button.new()
	generate_import_button.text = "Generar + cargar"
	generate_import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_import_button.tooltip_text = "Genera una base fresca del sector seleccionado. Pide confirmacion si ya existe."
	generate_import_button.pressed.connect(_request_generate_and_import_selected_sector)
	generation_section.add_child(generate_import_button)

	var batch_row := HBoxContainer.new()
	batch_row.add_theme_constant_override("separation", 6)
	generation_section.add_child(batch_row)

	generate_selection_button = Button.new()
	generate_selection_button.text = "Generar faltantes"
	generate_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_selection_button.tooltip_text = "Genera solo los sectores seleccionados que aun no tienen export. Es la opcion segura para selecciones grandes."
	generate_selection_button.pressed.connect(_request_generate_multi_selection.bind(true))
	batch_row.add_child(generate_selection_button)

	clear_selection_button = Button.new()
	clear_selection_button.text = "Limpiar"
	clear_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_selection_button.pressed.connect(_clear_multi_selection)
	batch_row.add_child(clear_selection_button)

	regenerate_selection_button = Button.new()
	regenerate_selection_button.text = "Regenerar seleccion"
	regenerate_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regenerate_selection_button.tooltip_text = "Vuelve a exportar todos los sectores seleccionados, incluso los verdes/exportados."
	regenerate_selection_button.pressed.connect(_request_generate_multi_selection.bind(false))
	generation_section.add_child(regenerate_selection_button)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	generation_section.add_child(progress_bar)

	progress_label = Label.new()
	progress_label.text = ""
	progress_label.visible = false
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	generation_section.add_child(progress_label)

	var generator_button := Button.new()
	generator_button.text = "Abrir generador para exportar sector"
	generator_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_button.pressed.connect(_open_sector_generator)
	terrain_section.add_child(generator_button)

	status_label = Label.new()
	status_label.text = "Abre el workspace Terrain3D y carga sectores exportados."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options_layout.add_child(status_label)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirmar generacion"
	confirm_dialog.ok_button_text = "Continuar"
	confirm_dialog.cancel_button_text = "Cancelar"
	confirm_dialog.confirmed.connect(_run_pending_generation)
	confirm_dialog.canceled.connect(_clear_pending_generation)
	add_child(confirm_dialog)


func _make_section(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if options_layout != null:
		options_layout.add_child(panel)
	else:
		root_layout.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	return box


func _populate_biome_override_option() -> void:
	if biome_override_option == null:
		return
	biome_override_option.clear()
	_add_option_item(biome_override_option, "Mantener base", -1)
	_add_option_item(biome_override_option, "Sin bioma", 0)
	_add_option_item(biome_override_option, "Templado", 1)
	_add_option_item(biome_override_option, "Desierto", 2)
	_add_option_item(biome_override_option, "Selva / humedo", 3)
	_add_option_item(biome_override_option, "Nieve / polar", 4)
	_add_option_item(biome_override_option, "Montana", 5)
	_add_option_item(biome_override_option, "Pantano", 6)
	_add_option_item(biome_override_option, "Arcano / raro", 7)


func _populate_surface_override_option() -> void:
	if surface_override_option == null:
		return
	surface_override_option.clear()
	_add_option_item(surface_override_option, "Mantener base", -1)
	_add_option_item(surface_override_option, "Tierra", SURFACE_LAND)
	_add_option_item(surface_override_option, "Agua", SURFACE_WATER)
	_add_option_item(surface_override_option, "Costa / arena", SURFACE_COAST)
	_add_option_item(surface_override_option, "Agua profunda", SURFACE_DEEP_WATER)


func _add_option_item(option: OptionButton, label: String, value: int) -> void:
	option.add_item(label)
	option.set_item_metadata(option.get_item_count() - 1, value)


func _refresh_exports() -> void:
	_load_sector_data()
	_load_sector_overrides()
	exported_sectors.clear()
	var absolute_dir := ProjectSettings.globalize_path(TERRAIN3D_EXPORT_DIR)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		_set_status("No existe carpeta de exports Terrain3D todavia.")
		_queue_map_redraw()
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name.begins_with("sector_"):
			var sector := _sector_from_export_folder(file_name)
			if sector.x >= 0 and sector.y >= 0:
				var resource_dir := TERRAIN3D_EXPORT_DIR + "/" + file_name
				var height_path := ProjectSettings.globalize_path(resource_dir + "/height.exr")
				if FileAccess.file_exists(height_path):
					exported_sectors[_sector_key(sector)] = resource_dir
		file_name = dir.get_next()

	_set_status("Exports encontrados: " + str(exported_sectors.size()) + ". Click en un sector verde para cargarlo.")
	_update_labels()
	_update_sector_guide()
	_queue_map_redraw()


func _draw_map() -> void:
	if map_view == null:
		return
	var full_rect := Rect2(Vector2.ZERO, map_view.size)
	map_view.draw_rect(full_rect, Color(0.06, 0.08, 0.09, 1.0), true)
	var map_rect := _map_content_rect()
	if map_texture != null:
		map_view.draw_texture_rect(map_texture, map_rect, false, Color.WHITE)
	else:
		map_view.draw_rect(map_rect, Color(0.82, 0.83, 0.78, 1.0), true)
	if show_biomes_check != null and show_biomes_check.button_pressed:
		_draw_biome_sectors(map_rect)
	if surface_texture != null and (show_surface_check == null or show_surface_check.button_pressed):
		map_view.draw_texture_rect(surface_texture, map_rect, false, Color(1.0, 1.0, 1.0, 0.62))
		_draw_surface_overrides(map_rect)
	_draw_exported_sectors(map_rect)
	_draw_multi_selected_sectors(map_rect)
	_draw_sector_grid(map_rect)
	_draw_sector_marker(map_rect, selected_sector, Color(1.0, 0.78, 0.16, 0.92), 2.5, true)
	if _is_sector_inside(hovered_sector):
		_draw_sector_marker(map_rect, hovered_sector, Color(1.0, 1.0, 1.0, 0.90), 2.0, false)
	if selection_dragging:
		_draw_selection_drag_rect()
	map_view.draw_rect(map_rect, Color(0.92, 0.92, 0.86, 0.92), false, 1.0)


func _draw_exported_sectors(map_rect: Rect2) -> void:
	for key in exported_sectors.keys():
		var sector := _sector_from_key(str(key))
		var sector_rect := _sector_rect_on_map(map_rect, sector)
		map_view.draw_rect(sector_rect, Color(0.10, 0.78, 0.34, 0.34), true)
		map_view.draw_rect(sector_rect, Color(0.10, 0.90, 0.42, 0.72), false, 1.0)


func _draw_biome_sectors(map_rect: Rect2) -> void:
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		return
	var sectors := sectors_value as Dictionary
	for key in sectors.keys():
		var value: Variant = sectors.get(key)
		if not (value is Dictionary):
			continue
		var sector_dict := value as Dictionary
		var sector := _sector_from_key(str(key))
		if not _is_sector_inside(sector):
			continue
		var biome_id := _effective_biome_id_for_sector(sector, sector_dict)
		if biome_id <= 0:
			continue
		var sector_rect := _sector_rect_on_map(map_rect, sector)
		map_view.draw_rect(sector_rect, _biome_color(biome_id, 0.30), true)


func _draw_surface_overrides(map_rect: Rect2) -> void:
	var sectors := _override_sectors_dict()
	for key in sectors.keys():
		var value: Variant = sectors.get(key)
		if not (value is Dictionary):
			continue
		var override := value as Dictionary
		var surface_id := int(override.get("surface_id", -1))
		if surface_id < SURFACE_LAND or surface_id > SURFACE_DEEP_WATER:
			continue
		var sector := _sector_from_key(str(key))
		if not _is_sector_inside(sector):
			continue
		var sector_rect := _sector_rect_on_map(map_rect, sector)
		map_view.draw_rect(sector_rect, _surface_color(surface_id, 0.38), true)
		map_view.draw_rect(sector_rect, Color(1.0, 0.86, 0.30, 0.90), false, 1.2)


func _draw_multi_selected_sectors(map_rect: Rect2) -> void:
	for key in multi_selected_sectors.keys():
		var sector := _sector_from_key(str(key))
		var sector_rect := _sector_rect_on_map(map_rect, sector)
		map_view.draw_rect(sector_rect, Color(0.18, 0.67, 1.0, 0.30), true)
		map_view.draw_rect(sector_rect, Color(0.40, 0.86, 1.0, 0.86), false, 1.4)


func _draw_selection_drag_rect() -> void:
	var drag_rect := Rect2(selection_drag_start, selection_drag_current - selection_drag_start).abs()
	map_view.draw_rect(drag_rect, Color(0.35, 0.72, 1.0, 0.16), true)
	map_view.draw_rect(drag_rect, Color(0.65, 0.90, 1.0, 0.92), false, 1.2)


func _draw_sector_grid(map_rect: Rect2) -> void:
	var columns := _sector_columns()
	var rows := _sector_rows()
	var grid_color := Color(0.02, 0.03, 0.03, 0.32)
	for x in range(columns + 1):
		var world_x := float(x) * SECTOR_SIDE_METERS
		var ratio_x := world_x / MAP_WORLD_SIZE.x
		var px := map_rect.position.x + ratio_x * map_rect.size.x
		map_view.draw_line(Vector2(px, map_rect.position.y), Vector2(px, map_rect.end.y), grid_color, 1.0)
	for y in range(rows + 1):
		var world_y := float(y) * SECTOR_SIDE_METERS
		var ratio_y := world_y / MAP_WORLD_SIZE.y
		var py := map_rect.position.y + ratio_y * map_rect.size.y
		map_view.draw_line(Vector2(map_rect.position.x, py), Vector2(map_rect.end.x, py), grid_color, 1.0)


func _draw_sector_marker(map_rect: Rect2, sector: Vector2i, color: Color, width: float, filled: bool) -> void:
	if not _is_sector_inside(sector):
		return
	var sector_rect := _sector_rect_on_map(map_rect, sector)
	if filled:
		var fill_color := color
		fill_color.a *= 0.22
		map_view.draw_rect(sector_rect, fill_color, true)
	map_view.draw_rect(sector_rect, color, false, width)


func _handle_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if selection_mouse_down:
			selection_drag_current = mouse_motion.position
			if not selection_dragging and selection_drag_start.distance_to(selection_drag_current) >= SELECTION_DRAG_THRESHOLD:
				selection_dragging = true
			if selection_dragging:
				_update_multi_selection_from_drag()
			else:
				_update_hover(mouse_motion.position)
			_queue_map_redraw()
		elif map_dragging:
			map_pan += mouse_motion.position - map_drag_last
			map_drag_last = mouse_motion.position
			_queue_map_redraw()
		else:
			_update_hover(mouse_motion.position)
		map_view.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map_at_position(1.18, mouse_button.position)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map_at_position(1.0 / 1.18, mouse_button.position)
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE or mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			map_dragging = mouse_button.pressed
			map_drag_last = mouse_button.position
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				selection_mouse_down = true
				selection_dragging = false
				selection_additive_drag = mouse_button.ctrl_pressed
				selection_drag_base = multi_selected_sectors.duplicate()
				selection_drag_start = mouse_button.position
				selection_drag_current = mouse_button.position
				_update_hover(mouse_button.position)
			else:
				if selection_mouse_down and selection_dragging:
					selection_drag_current = mouse_button.position
					_update_multi_selection_from_drag()
					_set_status("Seleccionados: " + str(multi_selected_sectors.size()) + ". Usa Generar faltantes para exportar solo lo nuevo, o Regenerar seleccion para rehacer todo.")
				elif selection_mouse_down:
					_update_hover(mouse_button.position)
					if _is_sector_inside(hovered_sector):
						selected_sector = hovered_sector
						if mouse_button.ctrl_pressed:
							_toggle_multi_selection(hovered_sector)
							_set_status("Seleccion multiple: " + str(multi_selected_sectors.size()) + " sectores.")
						else:
							if not multi_selected_sectors.is_empty():
								multi_selected_sectors.clear()
							if auto_import_check == null or auto_import_check.button_pressed:
								_import_selected_sector_centered()
						_update_labels()
						_update_sector_guide()
						_queue_map_redraw()
					elif not mouse_button.ctrl_pressed:
						_clear_multi_selection()
				selection_mouse_down = false
				selection_dragging = false
				selection_additive_drag = false
				selection_drag_base.clear()
				_queue_map_redraw()
			map_view.accept_event()


func _update_hover(local_position: Vector2) -> void:
	var map_rect := _map_content_rect()
	if not map_rect.has_point(local_position):
		hovered_sector = Vector2i(-1, -1)
	else:
		hovered_sector = _sector_at_map_position(local_position, map_rect)
	_update_labels()
	_queue_map_redraw()


func _update_multi_selection_from_drag() -> void:
	var map_rect := _map_content_rect()
	var drag_rect := Rect2(selection_drag_start, selection_drag_current - selection_drag_start).abs()
	var clipped := drag_rect.intersection(map_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		multi_selected_sectors = selection_drag_base.duplicate() if selection_additive_drag else {}
		_update_labels()
		return

	var start_sector := _sector_at_map_position(clipped.position, map_rect)
	var end_sector := _sector_at_map_position(clipped.end - Vector2(0.001, 0.001), map_rect)
	var min_x := mini(start_sector.x, end_sector.x)
	var max_x := maxi(start_sector.x, end_sector.x)
	var min_y := mini(start_sector.y, end_sector.y)
	var max_y := maxi(start_sector.y, end_sector.y)
	multi_selected_sectors.clear()
	if selection_additive_drag:
		multi_selected_sectors = selection_drag_base.duplicate()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sector := Vector2i(x, y)
			if _is_sector_inside(sector):
				multi_selected_sectors[_sector_key(sector)] = sector
	_update_labels()


func _toggle_multi_selection(sector: Vector2i) -> void:
	var key := _sector_key(sector)
	if multi_selected_sectors.has(key):
		multi_selected_sectors.erase(key)
	else:
		multi_selected_sectors[key] = sector
	_update_labels()
	_queue_map_redraw()


func _clear_multi_selection() -> void:
	multi_selected_sectors.clear()
	selection_mouse_down = false
	selection_dragging = false
	selection_additive_drag = false
	selection_drag_base.clear()
	_update_labels()
	_queue_map_redraw()
	_set_status("Seleccion multiple limpia.")


func _multi_selected_sector_list() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for value in multi_selected_sectors.values():
		if value is Vector2i:
			sectors.append(value as Vector2i)
	sectors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return sectors


func _clear_hover() -> void:
	hovered_sector = Vector2i(-1, -1)
	map_dragging = false
	selection_mouse_down = false
	selection_dragging = false
	_update_labels()
	_queue_map_redraw()


func _import_selected_sector_centered(force_fresh: bool = false) -> bool:
	var export_dir := str(exported_sectors.get(_sector_key(selected_sector), ""))
	if export_dir.is_empty():
		_set_status("Ese sector no tiene export Terrain3D. Usa Generar e importar sector.")
		return false

	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer. Abre terrain3d_sector_workspace.tscn o selecciona el Importer.")
		return false
	_ensure_importer_shared_resources(importer)

	# Guardar las ediciones del sector que estabamos editando antes de cambiar.
	if loaded_sector != NO_SECTOR and loaded_sector != selected_sector:
		_save_loaded_sector()

	var edit_dir := _sector_edit_dir(selected_sector)

	# Si el sector ya tiene ediciones guardadas y no estamos regenerando, cargarlas.
	if not force_fresh and _edit_dir_has_data(edit_dir):
		if importer.has_method("reset_terrain"):
			importer.call("reset_terrain", true)
		importer.set("data_directory", edit_dir)
		loaded_sector = selected_sector
		_set_status("Cargado " + _sector_label(selected_sector) + " con tus ediciones guardadas.")
		return true

	# Importacion fresca desde el height.exr generado por los scripts.
	var height_path := ProjectSettings.globalize_path(export_dir + "/height.exr")
	if not FileAccess.file_exists(height_path):
		_set_status("Falta height.exr para " + _sector_label(selected_sector) + ".")
		return false
	var control_path := ProjectSettings.globalize_path(export_dir + "/control.exr")
	var has_control := FileAccess.file_exists(control_path)

	if importer.has_method("reset_terrain"):
		importer.call("reset_terrain", true)
	importer.set("height_file_name", height_path)
	importer.set("control_file_name", control_path if has_control else "")
	importer.set("color_file_name", "")
	importer.set("import_position", Vector2i.ZERO)
	importer.set("import_scale", 1.0)
	importer.set("height_offset", 0.0)
	if importer.has_method("start_import"):
		importer.call("start_import", true)
	else:
		importer.set("run_import", true)
	if importer.has_method("update_heights"):
		importer.call("update_heights", true)

	# Al regenerar descartamos ediciones viejas: la base cambio.
	if force_fresh:
		_clear_edit_dir(edit_dir)

	# Persistir la carga y enlazar data_directory para que Ctrl+S tambien guarde.
	var saved_dir := _save_loaded_sector_to(importer, edit_dir)
	if saved_dir:
		importer.set("data_directory", edit_dir)

	loaded_sector = selected_sector
	if force_fresh:
		_set_status("Generado e importado " + _sector_label(selected_sector) + (" con materiales base." if has_control else " sin materiales base.") + " Listo para editar.")
	else:
		_set_status("Cargado " + _sector_label(selected_sector) + (" con materiales base." if has_control else " sin materiales base. Regeneralo para crear control.exr."))
	return true


func _save_current_sector_pressed() -> void:
	if loaded_sector == NO_SECTOR:
		_set_status("No hay sector cargado para guardar.")
		return
	if _save_loaded_sector():
		_set_status("Guardado " + _sector_label(loaded_sector) + " y libreria de texturas Terrain3D.")
	else:
		_set_status("No pude guardar el sector. Revisa que el nodo Importer este en la escena.")


func _save_loaded_sector() -> bool:
	if loaded_sector == NO_SECTOR:
		return false
	var importer := _find_importer_node()
	if importer == null:
		return false
	return _save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))


func _save_loaded_sector_to(importer: Node, edit_dir: String) -> bool:
	_ensure_importer_shared_resources(importer)
	var terrain_data = importer.get("data")
	if terrain_data == null:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(edit_dir))
	terrain_data.call("save_directory", edit_dir)
	return _save_importer_shared_resources(importer)


func _ensure_importer_shared_resources(importer: Node) -> void:
	if ResourceLoader.exists(TERRAIN3D_ASSETS_PATH):
		var current_assets: Variant = importer.get("assets")
		if not (current_assets is Resource) or (current_assets as Resource).resource_path != TERRAIN3D_ASSETS_PATH:
			importer.set("assets", load(TERRAIN3D_ASSETS_PATH))
	if ResourceLoader.exists(TERRAIN3D_MATERIAL_PATH):
		var current_material: Variant = importer.get("material")
		if not (current_material is Resource) or (current_material as Resource).resource_path != TERRAIN3D_MATERIAL_PATH:
			importer.set("material", load(TERRAIN3D_MATERIAL_PATH))


func _save_importer_shared_resources(importer: Node) -> bool:
	var ok := true
	var assets: Variant = importer.get("assets")
	if assets is Resource:
		var assets_resource := assets as Resource
		var assets_path := assets_resource.resource_path
		if assets_path.is_empty():
			assets_path = TERRAIN3D_ASSETS_PATH
		var assets_error := ResourceSaver.save(assets_resource, assets_path)
		ok = ok and assets_error == OK
	var material: Variant = importer.get("material")
	if material is Resource:
		var material_resource := material as Resource
		var material_path := material_resource.resource_path
		if material_path.is_empty():
			material_path = TERRAIN3D_MATERIAL_PATH
		var material_error := ResourceSaver.save(material_resource, material_path)
		ok = ok and material_error == OK
	return ok


func _sector_edit_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EDIT_DIR + "/sector_%d_%d" % [sector.x, sector.y]


func _edit_dir_has_data(edit_dir: String) -> bool:
	var dir := DirAccess.open(ProjectSettings.globalize_path(edit_dir))
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


func _clear_edit_dir(edit_dir: String) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(edit_dir))
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _request_generate_and_import_selected_sector() -> void:
	if generation_in_progress:
		return
	if not _is_sector_inside(selected_sector):
		_set_status("No hay sector valido para generar.")
		return
	var has_export := _has_export(selected_sector)
	var has_edits := _edit_dir_has_data(_sector_edit_dir(selected_sector))
	if has_export or has_edits:
		var existing_parts: Array[String] = []
		if has_export:
			existing_parts.append("export generado")
		if has_edits:
			existing_parts.append("ediciones guardadas")
		_ask_generation_confirmation(
			"single",
			true,
			"El sector " + _sector_label(selected_sector) + " ya tiene " + " y ".join(existing_parts) + ".\n\nGenerar + cargar crea una base fresca y puede reemplazar la edicion local al importarla.\n\nQuieres continuar?"
		)
		return
	_generate_and_import_selected_sector()


func _request_generate_multi_selection(skip_exported: bool) -> void:
	if generation_in_progress:
		return
	var selected_queue := _multi_selected_sector_list()
	if selected_queue.is_empty():
		_set_status("No hay sectores seleccionados. Arrastra sobre el mapa para seleccionar varios cuadros.")
		return
	var exported_count := _count_exported_sectors(selected_queue)
	var saved_count := _count_saved_edit_sectors(selected_queue)
	if skip_exported:
		if exported_count >= selected_queue.size():
			_set_status("Todos los sectores seleccionados ya estan exportados. Usa Regenerar seleccion si quieres rehacerlos.")
			return
		if exported_count > 0 or saved_count > 0:
			var pending_count := selected_queue.size() - exported_count
			_ask_generation_confirmation(
				"multi",
				true,
				"La seleccion tiene " + str(selected_queue.size()) + " sectores.\n\nYa exportados: " + str(exported_count) + "\nCon ediciones guardadas: " + str(saved_count) + "\n\nGenerar faltantes omitira los exportados y generara solo " + str(pending_count) + " sector(es) nuevo(s).\n\nQuieres continuar?"
			)
			return
		_generate_multi_selection(true)
		return
	_ask_generation_confirmation(
		"multi",
		false,
		"Vas a regenerar " + str(selected_queue.size()) + " sector(es) seleccionados.\n\nYa exportados: " + str(exported_count) + "\nCon ediciones guardadas: " + str(saved_count) + "\n\nEsto reexporta la base incluso si ya estaba verde/exportada. Luego podras cargarla como base fresca.\n\nQuieres continuar?"
	)


func _ask_generation_confirmation(action: String, skip_exported: bool, message: String) -> void:
	pending_generation_action = action
	pending_generation_skip_exported = skip_exported
	if confirm_dialog == null:
		_run_pending_generation()
		return
	confirm_dialog.dialog_text = message
	confirm_dialog.popup_centered(Vector2i(520, 260))


func _run_pending_generation() -> void:
	var action := pending_generation_action
	var skip_exported := pending_generation_skip_exported
	_clear_pending_generation()
	if action == "single":
		_generate_and_import_selected_sector()
	elif action == "multi":
		_generate_multi_selection(skip_exported)


func _clear_pending_generation() -> void:
	pending_generation_action = ""
	pending_generation_skip_exported = true


func _count_exported_sectors(sectors: Array[Vector2i]) -> int:
	var count := 0
	for sector in sectors:
		if _has_export(sector):
			count += 1
	return count


func _count_saved_edit_sectors(sectors: Array[Vector2i]) -> int:
	var count := 0
	for sector in sectors:
		if _edit_dir_has_data(_sector_edit_dir(sector)):
			count += 1
	return count


func _generate_and_import_selected_sector() -> void:
	if generation_in_progress:
		return
	generation_in_progress = true
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Preparando export...")
	var use_biomes := _generation_uses_biomes()
	_set_status("Generando " + _sector_label(selected_sector) + _generation_mode_suffix() + "...")
	await get_tree().process_frame

	var exporter: RefCounted = SECTOR_EXPORTER_SCRIPT.new()
	var result: Dictionary = await exporter.call("export_sector_async", selected_sector, Callable(self, "_update_generation_progress"), use_biomes)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "No pude generar el sector.")))
		_hide_generation_progress()
		generation_in_progress = false
		_set_generation_buttons_enabled(true)
		return

	_show_generation_progress(92.0, "Cargando en Terrain3D...")
	_refresh_exports()
	var max_height := float(result.get("height_max", 0.0))
	if _import_selected_sector_centered(true):
		_set_status("Generado e importado " + _sector_label(selected_sector) + _generation_mode_suffix() + " | altura max " + str(snappedf(max_height, 0.01)) + " m.")
	else:
		_set_status("Generado " + _sector_label(selected_sector) + ", pero no pude importarlo automaticamente. Abre terrain3d_sector_workspace.tscn y carga el sector.")
	_show_generation_progress(100.0, "Listo.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _generate_multi_selection(skip_exported: bool = true) -> void:
	if generation_in_progress:
		return
	var selected_queue := _multi_selected_sector_list()
	if selected_queue.is_empty():
		_set_status("No hay sectores seleccionados. Arrastra sobre el mapa para seleccionar varios cuadros.")
		return
	var skipped_count := 0
	var queue: Array[Vector2i] = []
	for sector in selected_queue:
		if skip_exported and _has_export(sector):
			skipped_count += 1
			continue
		queue.append(sector)
	if queue.is_empty():
		_set_status("Todos los sectores seleccionados ya estan exportados. Usa Regenerar seleccion si quieres rehacerlos.")
		return

	generation_in_progress = true
	batch_current_index = 0
	batch_total_count = queue.size()
	_set_generation_buttons_enabled(false)
	var skipped_text := " | omitidos " + str(skipped_count) if skipped_count > 0 else ""
	_show_generation_progress(0.0, "Preparando cola de " + str(batch_total_count) + " sectores" + skipped_text + "...")
	await get_tree().process_frame

	var exporter: RefCounted = SECTOR_EXPORTER_SCRIPT.new()
	var use_biomes := _generation_uses_biomes()
	var generated_count := 0
	for sector in queue:
		batch_current_index += 1
		selected_sector = sector
		_update_labels()
		_update_sector_guide()
		_queue_map_redraw()
		var result: Dictionary = await exporter.call("export_sector_async", sector, Callable(self, "_update_batch_generation_progress"), use_biomes)
		if not bool(result.get("ok", false)):
			_set_status("Cola detenida en " + _sector_label(sector) + ": " + str(result.get("message", "error desconocido")))
			_hide_generation_progress()
			generation_in_progress = false
			_set_generation_buttons_enabled(true)
			return
		generated_count += 1
		_refresh_exports()
		await get_tree().process_frame

	_show_generation_progress(100.0, "Cola lista.")
	var final_skip_text := " Omitidos por ya exportados: " + str(skipped_count) + "." if skipped_count > 0 else ""
	_set_status("Generados " + str(generated_count) + " sectores." + final_skip_text + " Quedaron marcados en verde para cargarlos cuando quieras.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _apply_generation_overrides() -> void:
	if generation_in_progress:
		return
	var biome_id := _selected_option_id(biome_override_option)
	var surface_id := _selected_option_id(surface_override_option)
	if biome_id < 0 and surface_id < 0:
		_set_status("Elige un bioma o terreno antes de aplicar una correccion.")
		return
	var targets := _override_target_sectors()
	if targets.is_empty():
		_set_status("No hay sector seleccionado para corregir.")
		return

	var sectors := _override_sectors_dict()
	for sector in targets:
		var key := _sector_key(sector)
		var override := _get_sector_override(sector).duplicate()
		if biome_id >= 0:
			override["biome_id"] = biome_id
		if surface_id >= SURFACE_LAND and surface_id <= SURFACE_DEEP_WATER:
			override["surface_id"] = surface_id
		if override.is_empty():
			sectors.erase(key)
		else:
			sectors[key] = override

	if not _save_sector_overrides():
		_set_status("No pude guardar " + SECTOR_OVERRIDES_PATH + ".")
		return
	var summary_parts: Array[String] = []
	if surface_id >= SURFACE_LAND and surface_id <= SURFACE_DEEP_WATER:
		summary_parts.append("terreno " + _surface_name_from_id(surface_id))
	if biome_id >= 0:
		summary_parts.append("bioma " + _biome_name_from_id(biome_id))
	_set_status("Correccion aplicada a " + str(targets.size()) + " sector(es): " + ", ".join(summary_parts) + ". Usa Generar para reexportar.")
	_update_labels()
	_queue_map_redraw()


func _clear_generation_overrides() -> void:
	if generation_in_progress:
		return
	var targets := _override_target_sectors()
	if targets.is_empty():
		_set_status("No hay sector seleccionado para limpiar.")
		return
	var sectors := _override_sectors_dict()
	var removed_count := 0
	for sector in targets:
		var key := _sector_key(sector)
		if sectors.has(key):
			sectors.erase(key)
			removed_count += 1
	if not _save_sector_overrides():
		_set_status("No pude guardar " + SECTOR_OVERRIDES_PATH + ".")
		return
	_set_status("Correcciones limpiadas: " + str(removed_count) + ". Esos sectores vuelven al mapa base al regenerar.")
	_update_labels()
	_queue_map_redraw()


func _override_target_sectors() -> Array[Vector2i]:
	if not multi_selected_sectors.is_empty():
		return _multi_selected_sector_list()
	if _is_sector_inside(selected_sector):
		return [selected_sector]
	return []


func _selected_option_id(option: OptionButton) -> int:
	if option == null:
		return -1
	var selected_index := option.get_selected()
	if selected_index < 0:
		return -1
	var value: Variant = option.get_item_metadata(selected_index)
	if value is int or value is float:
		return int(value)
	return -1


func _set_generation_buttons_enabled(enabled: bool) -> void:
	if generate_import_button != null:
		generate_import_button.disabled = not enabled
	if load_sector_button != null:
		load_sector_button.disabled = not enabled
	if generate_selection_button != null:
		generate_selection_button.disabled = not enabled
	if regenerate_selection_button != null:
		regenerate_selection_button.disabled = not enabled
	if clear_selection_button != null:
		clear_selection_button.disabled = not enabled
	if use_biomes_check != null:
		use_biomes_check.disabled = not enabled
	if biome_override_option != null:
		biome_override_option.disabled = not enabled
	if surface_override_option != null:
		surface_override_option.disabled = not enabled
	if apply_override_button != null:
		apply_override_button.disabled = not enabled
	if clear_override_button != null:
		clear_override_button.disabled = not enabled


func _show_generation_progress(value: float, message: String) -> void:
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.value = clampf(value, 0.0, 100.0)
	if progress_label != null:
		progress_label.visible = true
		progress_label.text = message


func _update_generation_progress(progress: float, message: String) -> void:
	_show_generation_progress(progress * 100.0, message)


func _update_batch_generation_progress(progress: float, message: String) -> void:
	var sector_offset := maxf(0.0, float(batch_current_index - 1))
	var total := maxf(1.0, float(batch_total_count))
	var batch_progress := (sector_offset + clampf(progress, 0.0, 1.0)) / total
	var label := "Sector " + str(batch_current_index) + "/" + str(batch_total_count) + ": " + message
	_show_generation_progress(batch_progress * 100.0, label)


func _hide_generation_progress() -> void:
	if progress_bar != null:
		progress_bar.visible = false
		progress_bar.value = 0.0
	if progress_label != null:
		progress_label.visible = false
		progress_label.text = ""


func _toggle_collapsed() -> void:
	if dock_pinned:
		_set_status("Panel pineado: desactiva Pin para minimizar.")
		return
	dock_collapsed = not dock_collapsed
	if collapse_button != null:
		collapse_button.text = "+" if dock_collapsed else "-"
	if root_layout != null:
		for index in range(root_layout.get_child_count()):
			var child := root_layout.get_child(index) as Control
			if child != null and child != root_layout.get_child(0):
				child.visible = not dock_collapsed
	custom_minimum_size = Vector2(220.0, 44.0) if dock_collapsed else Vector2(420.0, 560.0)


func _toggle_pinned() -> void:
	dock_pinned = pin_button != null and pin_button.button_pressed
	if collapse_button != null:
		collapse_button.disabled = dock_pinned
	if dock_pinned and dock_collapsed:
		dock_collapsed = false
		if collapse_button != null:
			collapse_button.text = "-"
		if root_layout != null:
			for index in range(root_layout.get_child_count()):
				var child := root_layout.get_child(index) as Control
				if child != null:
					child.visible = true
		custom_minimum_size = Vector2(420.0, 560.0)
	_set_status("Panel pineado." if dock_pinned else "Panel sin pin.")


func _open_sector_generator() -> void:
	if editor_interface == null:
		_set_status("No pude abrir el generador: editor_interface no disponible.")
		return
	editor_interface.open_scene_from_path("res://scenes/sector_world_generator.tscn")
	_set_status("Generador abierto. Ejecutalo con F6 y presiona Export Terrain3D para el sector actual.")


func _open_map_painter() -> void:
	if editor_interface == null:
		_set_status("No pude abrir el pintor: editor_interface no disponible.")
		return
	editor_interface.open_scene_from_path("res://scenes/map_layer_painter.tscn")
	_set_status("Pintor abierto. Edita superficies/biomas y vuelve a exportar sectores.")


func _find_importer_node() -> Node:
	if editor_interface == null:
		return null
	var selected_nodes: Array = editor_interface.get_selection().get_selected_nodes()
	for node in selected_nodes:
		if _looks_like_importer(node):
			return node
	var root: Node = editor_interface.get_edited_scene_root()
	if root == null:
		return null
	var importer := root.find_child("Importer", true, false)
	if _looks_like_importer(importer):
		return importer
	return null


func _looks_like_importer(node: Node) -> bool:
	return node != null and node.has_method("start_import") and node.has_method("reset_terrain")


func _update_sector_guide() -> void:
	if editor_interface == null:
		return
	var root: Node = editor_interface.get_edited_scene_root()
	if root == null:
		return
	var guide := root.find_child("SectorGuide", true, false)
	if guide != null:
		guide.set("origin_sector", selected_sector)


func _update_labels() -> void:
	if hover_label != null:
		var hover_text := "-"
		if _is_sector_inside(hovered_sector):
			hover_text = _sector_summary(hovered_sector)
			if _has_export(hovered_sector):
				hover_text += " exportado"
			else:
				hover_text += " sin export"
		hover_label.text = "Hover: " + hover_text + "\nZoom: x" + str(snappedf(map_zoom, 0.01))
	if selected_label != null:
		var selected_text := "Seleccionado: " + _sector_label(selected_sector) + (" exportado" if _has_export(selected_sector) else " sin export")
		if not multi_selected_sectors.is_empty():
			selected_text += "\nSeleccion multiple: " + str(multi_selected_sectors.size()) + " sectores"
		selected_label.text = selected_text
	if details_label != null:
		details_label.text = _sector_details_text(selected_sector)


func _load_sector_data() -> void:
	var data_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SECTOR_DATA_PATH))
	if data_text.is_empty():
		sector_data = {}
		return
	var parsed: Variant = JSON.parse_string(data_text)
	sector_data = parsed as Dictionary if parsed is Dictionary else {}


func _load_sector_overrides() -> void:
	sector_overrides = {"version": 1, "sectors": {}}
	var absolute_path := ProjectSettings.globalize_path(SECTOR_OVERRIDES_PATH)
	if not FileAccess.file_exists(absolute_path):
		return
	var data_text := FileAccess.get_file_as_string(absolute_path)
	if data_text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(data_text)
	if parsed is Dictionary:
		sector_overrides = parsed as Dictionary
	if not (sector_overrides.get("sectors", {}) is Dictionary):
		sector_overrides["sectors"] = {}


func _save_sector_overrides() -> bool:
	if not (sector_overrides.get("sectors", {}) is Dictionary):
		sector_overrides["sectors"] = {}
	sector_overrides["version"] = 1
	var absolute_path := ProjectSettings.globalize_path(SECTOR_OVERRIDES_PATH)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if dir_error != OK:
		return false
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(sector_overrides, "\t"))
	return true


func _sector_summary(sector: Vector2i) -> String:
	var info := _get_sector_dict(sector)
	if info.is_empty():
		return _sector_label(sector) + " | sin data"
	return _sector_label(sector) + " | " + _surface_name_for_sector(sector, info) + " | " + _biome_name_for_sector(sector, info)


func _sector_details_text(sector: Vector2i) -> String:
	if not _is_sector_inside(sector):
		return "Sector: -"
	var info := _get_sector_dict(sector)
	var lines: Array[String] = []
	lines.append("Superficie: " + _surface_name_for_sector(sector, info))
	lines.append("Bioma: " + _biome_name_for_sector(sector, info))
	var override := _get_sector_override(sector)
	if not override.is_empty():
		lines.append("Correccion: " + _override_summary(override))
	lines.append("Generacion: " + ("superficies + biomas" if _generation_uses_biomes() else "solo superficies"))
	if _has_export(sector):
		var metadata := _export_metadata_for_sector(sector)
		if metadata.is_empty():
			lines.append("Export: si")
		else:
			var min_height := snappedf(float(metadata.get("height_min", 0.0)), 0.01)
			var max_height := snappedf(float(metadata.get("height_max", 0.0)), 0.01)
			var uses_biomes := bool(metadata.get("use_biomes", true))
			lines.append("Export: si | altura " + str(min_height) + " a " + str(max_height) + " m")
			lines.append("Export modo: " + ("con biomas" if uses_biomes else "solo superficies"))
			var export_override := _metadata_override_summary(metadata)
			if not export_override.is_empty():
				lines.append("Export correccion: " + export_override)
	else:
		lines.append("Export: no")
	if not multi_selected_sectors.is_empty():
		lines.append("Seleccion multiple: " + str(multi_selected_sectors.size()) + " sectores")
	return "\n".join(lines)


func _get_sector_dict(sector: Vector2i) -> Dictionary:
	var sectors_value: Variant = sector_data.get("sectors", {})
	if not (sectors_value is Dictionary):
		return {}
	var sectors := sectors_value as Dictionary
	var value: Variant = sectors.get(_sector_key(sector), {})
	return value as Dictionary if value is Dictionary else {}


func _override_sectors_dict() -> Dictionary:
	var sectors_value: Variant = sector_overrides.get("sectors", {})
	if sectors_value is Dictionary:
		return sectors_value as Dictionary
	var sectors := {}
	sector_overrides["sectors"] = sectors
	return sectors


func _get_sector_override(sector: Vector2i) -> Dictionary:
	var sectors := _override_sectors_dict()
	var value: Variant = sectors.get(_sector_key(sector), {})
	return value as Dictionary if value is Dictionary else {}


func _effective_surface_id_for_sector(sector: Vector2i, info: Dictionary) -> int:
	var override := _get_sector_override(sector)
	if override.has("surface_id"):
		return int(override.get("surface_id", SURFACE_UNKNOWN))
	return int(info.get("dominant_surface_id", SURFACE_UNKNOWN))


func _effective_biome_id_for_sector(sector: Vector2i, info: Dictionary) -> int:
	var override := _get_sector_override(sector)
	if override.has("biome_id"):
		return int(override.get("biome_id", 0))
	return int(info.get("biome_id", 0))


func _surface_name_for_sector(sector: Vector2i, info: Dictionary) -> String:
	var override := _get_sector_override(sector)
	if override.has("surface_id"):
		return _surface_name_from_id(int(override.get("surface_id", SURFACE_UNKNOWN))) + " (corregido)"
	return _surface_name(info)


func _biome_name_for_sector(sector: Vector2i, info: Dictionary) -> String:
	var override := _get_sector_override(sector)
	if override.has("biome_id"):
		return _biome_name_from_id(int(override.get("biome_id", 0))) + " (corregido)"
	return _biome_name(info)


func _surface_name(info: Dictionary) -> String:
	if info.is_empty():
		return "Sin superficie"
	var surface_id := int(info.get("dominant_surface_id", SURFACE_UNKNOWN))
	if surface_id != SURFACE_UNKNOWN:
		return _surface_name_from_id(surface_id)
	var display := str(info.get("dominant_surface", "unknown"))
	match display:
		"land":
			return _surface_name_from_id(SURFACE_LAND)
		"water":
			return _surface_name_from_id(SURFACE_WATER)
		"deep_water":
			return _surface_name_from_id(SURFACE_DEEP_WATER)
		"coast":
			return _surface_name_from_id(SURFACE_COAST)
		_:
			return "Sin definir"


func _surface_name_from_id(surface_id: int) -> String:
	match surface_id:
		SURFACE_LAND:
			return "Tierra"
		SURFACE_WATER:
			return "Agua"
		SURFACE_COAST:
			return "Costa / arena"
		SURFACE_DEEP_WATER:
			return "Agua profunda"
		_:
			return "Sin definir"


func _biome_name(info: Dictionary) -> String:
	if info.is_empty():
		return "Sin bioma"
	var biome_id := int(info.get("biome_id", 0))
	if biome_id > 0:
		return _biome_name_from_id(biome_id)
	return str(info.get("biome", "Sin bioma"))


func _biome_name_from_id(biome_id: int) -> String:
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


func _override_summary(override: Dictionary) -> String:
	var parts: Array[String] = []
	if override.has("surface_id"):
		parts.append("terreno " + _surface_name_from_id(int(override.get("surface_id", SURFACE_UNKNOWN))))
	if override.has("biome_id"):
		parts.append("bioma " + _biome_name_from_id(int(override.get("biome_id", 0))))
	return ", ".join(parts) if not parts.is_empty() else "sin cambios"


func _metadata_override_summary(metadata: Dictionary) -> String:
	var parts: Array[String] = []
	var surface_id := int(metadata.get("override_surface_id", -1))
	var biome_id := int(metadata.get("override_biome_id", -1))
	if surface_id >= SURFACE_LAND and surface_id <= SURFACE_DEEP_WATER:
		parts.append("terreno " + _surface_name_from_id(surface_id))
	if biome_id >= 0:
		parts.append("bioma " + _biome_name_from_id(biome_id))
	return ", ".join(parts)


func _surface_color(surface_id: int, alpha: float) -> Color:
	match surface_id:
		SURFACE_LAND:
			return Color(0.32, 0.68, 0.36, alpha)
		SURFACE_WATER:
			return Color(0.10, 0.40, 0.78, alpha)
		SURFACE_COAST:
			return Color(0.95, 0.78, 0.36, alpha)
		SURFACE_DEEP_WATER:
			return Color(0.08, 0.14, 0.42, alpha)
		_:
			return Color(0.70, 0.70, 0.66, alpha)


func _export_metadata_for_sector(sector: Vector2i) -> Dictionary:
	var export_dir := str(exported_sectors.get(_sector_key(sector), ""))
	if export_dir.is_empty():
		return {}
	var metadata_path := ProjectSettings.globalize_path(export_dir + "/metadata.json")
	if not FileAccess.file_exists(metadata_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _generation_uses_biomes() -> bool:
	return use_biomes_check != null and use_biomes_check.button_pressed


func _generation_mode_suffix() -> String:
	return " con biomas" if _generation_uses_biomes() else " solo superficies"


func _biome_color(biome_id: int, alpha: float) -> Color:
	match biome_id:
		2:
			return Color(0.72, 0.56, 0.26, alpha)
		3:
			return Color(0.08, 0.45, 0.22, alpha)
		4:
			return Color(0.76, 0.90, 0.94, alpha)
		5:
			return Color(0.43, 0.40, 0.34, alpha)
		6:
			return Color(0.22, 0.34, 0.21, alpha)
		7:
			return Color(0.45, 0.24, 0.55, alpha)
		_:
			return Color(0.34, 0.65, 0.36, alpha)


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _queue_map_redraw() -> void:
	if map_view != null:
		map_view.queue_redraw()


func _map_content_rect() -> Rect2:
	var base_rect := _base_map_content_rect()
	var zoomed_size := base_rect.size * map_zoom
	return Rect2(base_rect.get_center() + map_pan - zoomed_size * 0.5, zoomed_size)


func _base_map_content_rect() -> Rect2:
	if map_view == null:
		return Rect2(Vector2.ZERO, MAP_VIEW_SIZE)
	var view_size := map_view.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = MAP_VIEW_SIZE
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


func _zoom_map_from_center(factor: float) -> void:
	if map_view == null:
		return
	_zoom_map_at_position(factor, map_view.size * 0.5)


func _zoom_map_at_position(factor: float, pivot: Vector2) -> void:
	var old_rect := _map_content_rect()
	var normalized := Vector2(
		(pivot.x - old_rect.position.x) / old_rect.size.x,
		(pivot.y - old_rect.position.y) / old_rect.size.y
	)
	map_zoom = clampf(map_zoom * factor, 1.0, 18.0)
	var base_rect := _base_map_content_rect()
	var new_size := base_rect.size * map_zoom
	var new_position := pivot - Vector2(normalized.x * new_size.x, normalized.y * new_size.y)
	map_pan = new_position + new_size * 0.5 - base_rect.get_center()
	_update_labels()
	_queue_map_redraw()


func _reset_map_view() -> void:
	map_zoom = 1.0
	map_pan = Vector2.ZERO
	_update_labels()
	_queue_map_redraw()


func _sector_at_map_position(local_position: Vector2, map_rect: Rect2) -> Vector2i:
	var normalized := Vector2(
		(local_position.x - map_rect.position.x) / map_rect.size.x,
		(local_position.y - map_rect.position.y) / map_rect.size.y
	)
	normalized.x = clampf(normalized.x, 0.0, 0.9999)
	normalized.y = clampf(normalized.y, 0.0, 0.9999)
	return Vector2i(
		int(floor(normalized.x * MAP_WORLD_SIZE.x / SECTOR_SIDE_METERS)),
		int(floor(normalized.y * MAP_WORLD_SIZE.y / SECTOR_SIDE_METERS))
	)


func _sector_rect_on_map(map_rect: Rect2, sector: Vector2i) -> Rect2:
	var start_world := Vector2(float(sector.x) * SECTOR_SIDE_METERS, float(sector.y) * SECTOR_SIDE_METERS)
	var end_world := start_world + Vector2(SECTOR_SIDE_METERS, SECTOR_SIDE_METERS)
	end_world.x = minf(end_world.x, MAP_WORLD_SIZE.x)
	end_world.y = minf(end_world.y, MAP_WORLD_SIZE.y)
	var start := map_rect.position + Vector2(start_world.x / MAP_WORLD_SIZE.x * map_rect.size.x, start_world.y / MAP_WORLD_SIZE.y * map_rect.size.y)
	var end := map_rect.position + Vector2(end_world.x / MAP_WORLD_SIZE.x * map_rect.size.x, end_world.y / MAP_WORLD_SIZE.y * map_rect.size.y)
	return Rect2(start, end - start)


func _sector_columns() -> int:
	return int(ceil(MAP_WORLD_SIZE.x / SECTOR_SIDE_METERS))


func _sector_rows() -> int:
	return int(ceil(MAP_WORLD_SIZE.y / SECTOR_SIDE_METERS))


func _is_sector_inside(sector: Vector2i) -> bool:
	return sector.x >= 0 and sector.y >= 0 and sector.x < _sector_columns() and sector.y < _sector_rows()


func _has_export(sector: Vector2i) -> bool:
	return exported_sectors.has(_sector_key(sector))


func _sector_key(sector: Vector2i) -> String:
	return str(sector.x) + "," + str(sector.y)


func _sector_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _sector_from_export_folder(folder_name: String) -> Vector2i:
	var parts := folder_name.split("_")
	if parts.size() != 3:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[1]), int(parts[2]))


func _sector_label(sector: Vector2i) -> String:
	return "[" + str(sector.x) + ", " + str(sector.y) + "]"
