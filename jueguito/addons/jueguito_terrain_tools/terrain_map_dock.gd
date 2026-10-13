@tool
extends PanelContainer

const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const SECTOR_DATA_PATH := "res://data/map_design_sectors_5km.json"
const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const SECTOR_OVERRIDES_PATH := "res://data/terrain3d_sector_overrides.json"
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
# Los .res respaldados conservan UID. Dentro de res://data Godot los escanea como
# recursos activos y genera colisiones; .godot queda fuera del FileSystem dock.
const TERRAIN3D_EDIT_BACKUP_DIR := "res://.godot/terrain3d_backups"
const SECTOR_CONTENT_DIR := "res://scenes/world/sectors/handmade"
const SECTOR_CONTENT_BACKUP_DIR := "res://data/sector_content_backups"
const SECTOR_CONTENT_ROOT_NAME := &"SectorContent"
const SECTOR_CONTENT_VERSION := 1
const SECTOR_CONTENT_CATEGORIES: Array[StringName] = [
	&"Rocks",
	&"Vegetation",
	&"Buildings",
	&"NPCs",
	&"Props",
]
const WORKSPACE_INFRASTRUCTURE_NODES: Array[StringName] = [
	&"WorkspaceCamera",
	&"WorkspaceLight",
	&"Importer",
	&"SectorGuide",
	&"OceanPreview",
	SECTOR_CONTENT_ROOT_NAME,
]
const TERRAIN3D_ASSETS_PATH := "res://assets/environment/terrain/jueguito_terrain_assets.tres"
const TERRAIN3D_MATERIAL_PATH := "res://assets/environment/terrain/jueguito_terrain_material.tres"
const TERRAIN3D_SECTOR_RESOLUTION := 512
const TERRAIN3D_REGION_SIZE := 256
const NO_SECTOR := Vector2i(-9999, -9999)
const SECTOR_EXPORTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_sector_exporter.gd")
const HEIGHTMAP_NORMALIZER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_heightmap_normalizer.gd")
const AUTO_PAINTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_auto_painter.gd")
const TERRAIN3D_PAINT_PREVIEW_DIR := "res://data/terrain3d_paint_previews"
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
var fresh_load_button: Button
var cleanup_regions_button: Button
var smooth_iterations_spin: SpinBox
var smooth_strength_spin: SpinBox
var repair_threshold_spin: SpinBox
var smooth_preserve_edges_check: CheckBox
var allow_intentional_cuts_check: CheckBox
var smooth_loaded_button: Button
var smooth_selection_button: Button
var repair_loaded_button: Button
var repair_selection_button: Button
var paint_edge_radius_spin: SpinBox
var analyze_paint_button: Button
var paint_loaded_button: Button
var paint_selection_button: Button
var exported_sectors: Dictionary = {}
var multi_selected_sectors: Dictionary = {}
var selected_sector := Vector2i(33, 19)
var loaded_sector := NO_SECTOR
var loaded_content_sector := NO_SECTOR
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
var sector_transition_in_progress := false
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
	call_deferred("_initialize_workspace_state")


func _exit_tree() -> void:
	if loaded_sector != NO_SECTOR and not generation_in_progress and not sector_transition_in_progress:
		_save_loaded_sector_bundle()


# Lo invoca EditorPlugin._save_external_data() cuando el usuario pulsa Ctrl+S.
# No intenta guardar durante una generacion ni cuando el dock no tiene un sector
# activo, para evitar persistir datos parciales o una escena que no corresponde.
func save_external_data() -> void:
	if loaded_sector == NO_SECTOR or generation_in_progress or sector_transition_in_progress:
		return
	ensure_workspace_content_editable()
	if _save_loaded_sector_bundle():
		_set_status("Guardado con Ctrl+S: terreno y contenido de " + _sector_label(loaded_sector) + ".")
	else:
		_set_status("Ctrl+S guardo la escena, pero fallo el guardado seguro del sector activo.")


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
	var terrain_button_grid := _make_button_grid(terrain_section, 2)

	var refresh_button := Button.new()
	refresh_button.text = "Actualizar exports"
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_refresh_exports)
	terrain_button_grid.add_child(refresh_button)

	load_sector_button = Button.new()
	load_sector_button.text = "Cargar sector"
	load_sector_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_sector_button.tooltip_text = "Carga el sector. Si tiene ediciones guardadas, las recupera; si no, importa el terreno generado."
	load_sector_button.pressed.connect(_import_selected_sector_centered.bind(false))
	terrain_button_grid.add_child(load_sector_button)

	fresh_load_button = Button.new()
	fresh_load_button.text = "Base fresca"
	fresh_load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fresh_load_button.tooltip_text = "Importa el export actual y respalda cualquier edicion guardada del sector."
	fresh_load_button.pressed.connect(_import_selected_sector_centered.bind(true))
	terrain_button_grid.add_child(fresh_load_button)

	var save_sector_button := Button.new()
	save_sector_button.text = "Guardar"
	save_sector_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_sector_button.tooltip_text = "Guarda y valida el Terrain3D y todos los objetos de SectorContent del sector activo."
	save_sector_button.pressed.connect(_save_current_sector_pressed)
	terrain_button_grid.add_child(save_sector_button)

	cleanup_regions_button = Button.new()
	cleanup_regions_button.text = "Limpiar fuera de 512"
	cleanup_regions_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleanup_regions_button.disabled = true
	cleanup_regions_button.tooltip_text = "Quita solamente las regiones Terrain3D creadas fuera del sector 512 x 512. Antes guarda un respaldo recuperable."
	cleanup_regions_button.pressed.connect(_request_cleanup_outside_regions)
	terrain_button_grid.add_child(cleanup_regions_button)

	var footprint_hint := Label.new()
	footprint_hint.text = "Limite activo: toda brocha edita solo las 4 regiones del sector 512 x 512."
	footprint_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_section.add_child(footprint_hint)

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

	var override_button_grid := _make_button_grid(generation_section, 2)

	apply_override_button = Button.new()
	apply_override_button.text = "Aplicar correccion"
	apply_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_override_button.tooltip_text = "Guarda la correccion para el sector o seleccion multiple. Luego usa Generar para reexportar."
	apply_override_button.pressed.connect(_apply_generation_overrides)
	override_button_grid.add_child(apply_override_button)

	clear_override_button = Button.new()
	clear_override_button.text = "Limpiar correccion"
	clear_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_override_button.tooltip_text = "Quita la correccion y vuelve a usar el mapa base."
	clear_override_button.pressed.connect(_clear_generation_overrides)
	override_button_grid.add_child(clear_override_button)

	generate_import_button = Button.new()
	generate_import_button.text = "Generar + cargar"
	generate_import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_import_button.tooltip_text = "Genera una base fresca del sector seleccionado. Pide confirmacion si ya existe."
	generate_import_button.pressed.connect(_request_generate_and_import_selected_sector)
	generation_section.add_child(generate_import_button)

	var batch_button_grid := _make_button_grid(generation_section, 2)

	generate_selection_button = Button.new()
	generate_selection_button.text = "Generar faltantes"
	generate_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_selection_button.tooltip_text = "Genera solo los sectores seleccionados que aun no tienen export. Es la opcion segura para selecciones grandes."
	generate_selection_button.pressed.connect(_request_generate_multi_selection.bind(true))
	batch_button_grid.add_child(generate_selection_button)

	clear_selection_button = Button.new()
	clear_selection_button.text = "Limpiar"
	clear_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_selection_button.pressed.connect(_clear_multi_selection)
	batch_button_grid.add_child(clear_selection_button)

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
	generator_button.text = "Abrir generador"
	generator_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_button.tooltip_text = "Abre la escena generadora para exportar sectores Terrain3D."
	generator_button.pressed.connect(_open_sector_generator)
	terrain_section.add_child(generator_button)

	var smooth_section := _make_section("Normalizar terreno", false)
	var smooth_settings_grid := GridContainer.new()
	smooth_settings_grid.columns = 2
	smooth_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_theme_constant_override("h_separation", 8)
	smooth_settings_grid.add_theme_constant_override("v_separation", 6)
	smooth_section.add_child(smooth_settings_grid)

	var smooth_iterations_label := Label.new()
	smooth_iterations_label.text = "Pasadas"
	smooth_iterations_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(smooth_iterations_label)

	smooth_iterations_spin = SpinBox.new()
	smooth_iterations_spin.min_value = 1.0
	smooth_iterations_spin.max_value = 24.0
	smooth_iterations_spin.step = 1.0
	smooth_iterations_spin.value = 4.0
	smooth_iterations_spin.tooltip_text = "Cuantas veces se promedia el heightmap. Evitar cortes usa una pasada estricta extra."
	smooth_iterations_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(smooth_iterations_spin)

	var smooth_strength_label := Label.new()
	smooth_strength_label.text = "Fuerza"
	smooth_strength_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(smooth_strength_label)

	smooth_strength_spin = SpinBox.new()
	smooth_strength_spin.min_value = 0.05
	smooth_strength_spin.max_value = 1.0
	smooth_strength_spin.step = 0.05
	smooth_strength_spin.value = 0.65
	smooth_strength_spin.tooltip_text = "0.05 suaviza poco; 1.0 lleva cada punto al promedio local."
	smooth_strength_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(smooth_strength_spin)

	var repair_threshold_label := Label.new()
	repair_threshold_label.text = "Corte m"
	repair_threshold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(repair_threshold_label)

	repair_threshold_spin = SpinBox.new()
	repair_threshold_spin.min_value = 0.25
	repair_threshold_spin.max_value = 30.0
	repair_threshold_spin.step = 0.25
	repair_threshold_spin.value = 1.5
	repair_threshold_spin.tooltip_text = "Diferencia vertical minima para detectar un corte. Bajalo para ser mas estricto; subilo para conservar relieve duro."
	repair_threshold_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_settings_grid.add_child(repair_threshold_spin)

	smooth_preserve_edges_check = CheckBox.new()
	smooth_preserve_edges_check.text = "Proteger bordes externos"
	smooth_preserve_edges_check.button_pressed = true
	smooth_preserve_edges_check.tooltip_text = "Mantiene intactos los bordes sin region vecina. Las costuras internas igual se normalizan."
	smooth_section.add_child(smooth_preserve_edges_check)

	allow_intentional_cuts_check = CheckBox.new()
	allow_intentional_cuts_check.text = "Permitir cortes intencionales"
	allow_intentional_cuts_check.button_pressed = false
	allow_intentional_cuts_check.tooltip_text = "Activalo solo si quieres conservar acantilados o terrazas duras. Apagado repara cortes por defecto."
	smooth_section.add_child(allow_intentional_cuts_check)

	var smooth_button_grid := _make_button_grid(smooth_section, 2)
	smooth_loaded_button = Button.new()
	smooth_loaded_button.text = "Suavizar cargado"
	smooth_loaded_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_loaded_button.tooltip_text = "Suaviza el Terrain3D cargado y lo guarda como edicion del sector."
	smooth_loaded_button.pressed.connect(_smooth_loaded_sector_pressed)
	smooth_button_grid.add_child(smooth_loaded_button)

	repair_loaded_button = Button.new()
	repair_loaded_button.text = "Evitar cortes"
	repair_loaded_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_loaded_button.tooltip_text = "Detecta lineas duras, expande el area afectada y las normaliza con una pasada estricta."
	repair_loaded_button.pressed.connect(_repair_loaded_sector_pressed)
	smooth_button_grid.add_child(repair_loaded_button)

	smooth_selection_button = Button.new()
	smooth_selection_button.text = "Suavizar seleccion"
	smooth_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_selection_button.tooltip_text = "Carga, suaviza y guarda cada sector seleccionado."
	smooth_selection_button.pressed.connect(_smooth_multi_selection_pressed)
	smooth_button_grid.add_child(smooth_selection_button)

	repair_selection_button = Button.new()
	repair_selection_button.text = "Evitar cortes seleccion"
	repair_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_selection_button.tooltip_text = "Carga cada sector seleccionado y normaliza cortes con una pasada estricta."
	repair_selection_button.pressed.connect(_repair_multi_selection_pressed)
	smooth_button_grid.add_child(repair_selection_button)

	var paint_section := _make_section("Pintura automatica", false)
	var paint_settings_grid := GridContainer.new()
	paint_settings_grid.columns = 2
	paint_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_settings_grid.add_theme_constant_override("h_separation", 8)
	paint_settings_grid.add_theme_constant_override("v_separation", 6)
	paint_section.add_child(paint_settings_grid)

	var paint_radius_label := Label.new()
	paint_radius_label.text = "Borde pincel px"
	paint_radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_settings_grid.add_child(paint_radius_label)

	paint_edge_radius_spin = SpinBox.new()
	paint_edge_radius_spin.min_value = 0.0
	paint_edge_radius_spin.max_value = 12.0
	paint_edge_radius_spin.step = 1.0
	paint_edge_radius_spin.value = 5.0
	paint_edge_radius_spin.tooltip_text = "Radio de mezcla entre superficies. 0 deja cortes duros; 4-7 produce un borde rociado suave."
	paint_edge_radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_settings_grid.add_child(paint_edge_radius_spin)

	var paint_help := Label.new()
	paint_help.text = "Analiza altura, pendiente y pintura previa. No modifica el relieve."
	paint_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paint_section.add_child(paint_help)

	var paint_button_grid := _make_button_grid(paint_section, 2)
	analyze_paint_button = Button.new()
	analyze_paint_button.text = "Analizar pintura"
	analyze_paint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analyze_paint_button.tooltip_text = "Genera una previsualizacion PNG del sector cargado sin modificarlo."
	analyze_paint_button.pressed.connect(_analyze_loaded_sector_paint_pressed)
	paint_button_grid.add_child(analyze_paint_button)

	paint_loaded_button = Button.new()
	paint_loaded_button.text = "Pintar cargado"
	paint_loaded_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_loaded_button.tooltip_text = "Respalda y pinta automaticamente el sector cargado."
	paint_loaded_button.pressed.connect(_paint_loaded_sector_pressed)
	paint_button_grid.add_child(paint_loaded_button)

	paint_selection_button = Button.new()
	paint_selection_button.text = "Pintar seleccion"
	paint_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_selection_button.tooltip_text = "Carga, respalda y pinta todos los sectores seleccionados en el mapa MMO."
	paint_selection_button.pressed.connect(_paint_multi_selection_pressed)
	paint_section.add_child(paint_selection_button)

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


func _make_section(title_text: String, expanded: bool = true) -> VBoxContainer:
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

	var header := Button.new()
	header.text = ("[-] " if expanded else "[+] ") + title_text
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.tooltip_text = "Expandir/contraer " + title_text
	box.add_child(header)

	var body := VBoxContainer.new()
	body.visible = expanded
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)

	header.pressed.connect(_toggle_section.bind(header, body, title_text))
	return body


func _toggle_section(header: Button, body: Control, title_text: String) -> void:
	body.visible = not body.visible
	header.text = ("[-] " if body.visible else "[+] ") + title_text


func _make_button_grid(parent: Control, columns: int = 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


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
	if loaded_sector != NO_SECTOR:
		_draw_sector_marker(map_rect, loaded_sector, Color(0.20, 0.86, 1.0, 0.98), 3.5, false)
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
								await _import_selected_sector_centered()
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


func _initialize_workspace_state() -> void:
	var workspace := _find_workspace_root()
	if workspace == null:
		return
	var importer := workspace.find_child("Importer", true, false)
	if _looks_like_importer(importer):
		# El workspace siempre debe usar la biblioteca vigente. Esto también
		# autocorrige escenas antiguas que quedaron apuntando a un respaldo.
		_ensure_importer_shared_resources(importer)
	var content := _find_sector_content_node()
	_repair_misplaced_workspace_infrastructure(content, workspace)
	var inferred_sector := _infer_workspace_sector()
	if inferred_sector == NO_SECTOR:
		_set_status("Workspace listo, pero no pude determinar el sector activo. Carga uno antes de agregar contenido.")
		return

	selected_sector = inferred_sector
	loaded_sector = inferred_sector
	var declared_sector := _declared_content_sector(content)
	var recovered_unassigned := false
	var recovered_backup := false
	if content != null and declared_sector == inferred_sector:
		loaded_content_sector = inferred_sector
		_normalize_sector_content(content, inferred_sector)
		recovered_backup = _recover_richer_content_backup(content, inferred_sector)
		_make_sector_content_editable(content, workspace)
	else:
		if content != null and declared_sector != NO_SECTOR and declared_sector != inferred_sector:
			loaded_sector = NO_SECTOR
			_set_status("SectorContent declara " + _sector_label(declared_sector) + ", pero Terrain3D apunta a " + _sector_label(inferred_sector) + ". Carga el sector correcto antes de editar.")
			_update_sector_guide()
			_update_labels()
			return
		var prepared := _prepare_sector_content(inferred_sector)
		if not bool(prepared.get("ok", false)):
			loaded_sector = NO_SECTOR
			_set_status(str(prepared.get("message", "No pude preparar el contenido del sector.")))
			_update_sector_guide()
			_update_labels()
			return
		var prepared_content := prepared.get("node") as Node3D
		recovered_backup = bool(prepared.get("recovered_backup", false))
		recovered_unassigned = content != null and _sector_content_has_objects(content)
		if recovered_unassigned:
			_merge_sector_content_nodes(content, prepared_content, inferred_sector)
		recovered_backup = _recover_richer_content_backup(prepared_content, inferred_sector) or recovered_backup
		if not _activate_sector_content(prepared_content, inferred_sector):
			loaded_sector = NO_SECTOR
			_set_status("No pude activar el contenido artesanal del sector inferido.")
			_update_sector_guide()
			_update_labels()
			return

	_update_ocean_preview(inferred_sector)
	_set_workspace_loaded_sector_metadata(inferred_sector)
	_update_sector_guide()
	_update_labels()
	var loose_nodes := _workspace_loose_content_names()
	if loose_nodes.is_empty():
		if recovered_backup:
			_set_status("Recupere el contenido completo de respaldo para " + _sector_label(inferred_sector) + " sin reemplazar tus objetos actuales. Pulsa Guardar para confirmarlo.")
		elif recovered_unassigned:
			_set_status("Contenido sin coordenadas recuperado y combinado de forma segura con " + _sector_label(inferred_sector) + ". Pulsa Guardar para confirmarlo.")
		else:
			_set_status("Sector " + _sector_label(inferred_sector) + " restaurado con terreno y contenido aislado.")
	else:
		_set_status(_loose_content_error(loose_nodes))


func _infer_workspace_sector() -> Vector2i:
	var workspace := _find_workspace_root()
	if workspace != null and workspace.has_meta("loaded_sector_x") and workspace.has_meta("loaded_sector_y"):
		return Vector2i(int(workspace.get_meta("loaded_sector_x")), int(workspace.get_meta("loaded_sector_y")))
	var importer := _find_importer_node()
	if importer == null:
		return NO_SECTOR
	var from_edits := _sector_from_storage_path(str(importer.get("data_directory")))
	if from_edits != NO_SECTOR:
		return from_edits
	return _sector_from_storage_path(str(importer.get("height_file_name")))


func _set_workspace_loaded_sector_metadata(sector: Vector2i) -> void:
	var workspace := _find_workspace_root()
	if workspace == null:
		return
	workspace.set_meta("loaded_sector_x", sector.x)
	workspace.set_meta("loaded_sector_y", sector.y)
	if editor_interface != null:
		editor_interface.mark_scene_as_unsaved()


func _sector_from_storage_path(path: String) -> Vector2i:
	if path.is_empty():
		return NO_SECTOR
	var normalized := path.replace("\\", "/")
	var marker_index := normalized.rfind("sector_")
	if marker_index < 0:
		return NO_SECTOR
	var suffix := normalized.substr(marker_index + 7)
	var end_index := suffix.find("/")
	if end_index >= 0:
		suffix = suffix.left(end_index)
	suffix = suffix.trim_suffix(".tscn")
	var parts := suffix.split("_")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return NO_SECTOR
	return Vector2i(int(parts[0]), int(parts[1]))


func _find_workspace_root() -> Node:
	if editor_interface == null:
		return null
	var root: Node = editor_interface.get_edited_scene_root()
	if root == null or root.name != &"Terrain3DSectorWorkspace":
		return null
	return root


func _find_sector_content_node() -> Node3D:
	var root := _find_workspace_root()
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(SECTOR_CONTENT_ROOT_NAME))) as Node3D


func _create_empty_sector_content(sector: Vector2i) -> Node3D:
	var content := Node3D.new()
	content.name = SECTOR_CONTENT_ROOT_NAME
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := Node3D.new()
		category.name = category_name
		content.add_child(category)
		category.owner = content
	_set_content_sector_metadata(content, sector)
	return content


func _prepare_sector_content(sector: Vector2i) -> Dictionary:
	var content_path := _sector_content_path(sector)
	if not ResourceLoader.exists(content_path):
		return {"ok": true, "node": _create_empty_sector_content(sector), "created": true}

	var packed := ResourceLoader.load(content_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {"ok": false, "message": "La escena de contenido " + content_path + " no se puede abrir; cambio cancelado."}
	var content := packed.instantiate() as Node3D
	if content == null:
		return {"ok": false, "message": "La raiz de " + content_path + " no es Node3D; cambio cancelado."}
	var declared_sector := _declared_content_sector(content)
	if declared_sector != NO_SECTOR and declared_sector != sector:
		content.free()
		return {"ok": false, "message": "La escena " + content_path + " declara otro sector; cambio cancelado para evitar mezcla."}
	content.scene_file_path = ""
	_normalize_sector_content(content, sector)
	var validation_error := _validate_sector_content(content, sector, true)
	if not validation_error.is_empty():
		content.free()
		return {"ok": false, "message": validation_error + " Cambio cancelado."}
	var recovered_backup := _recover_richer_content_backup(content, sector)
	return {"ok": true, "node": content, "created": false, "recovered_backup": recovered_backup}


func _activate_sector_content(content: Node3D, sector: Vector2i) -> bool:
	var workspace := _find_workspace_root()
	if workspace == null or content == null:
		return false
	var old_content := _find_sector_content_node()
	if old_content != null:
		var selection = editor_interface.get_selection()
		for selected_node in selection.get_selected_nodes():
			if selected_node == old_content or old_content.is_ancestor_of(selected_node):
				selection.clear()
				break
		workspace.remove_child(old_content)
		old_content.free()
	content.name = SECTOR_CONTENT_ROOT_NAME
	workspace.add_child(content)
	content.owner = workspace
	_make_sector_content_editable(content, workspace)
	_set_content_sector_metadata(content, sector)
	loaded_content_sector = sector
	editor_interface.mark_scene_as_unsaved()
	return true


func ensure_workspace_content_editable() -> void:
	var workspace := _find_workspace_root()
	var content := _find_sector_content_node()
	if workspace == null or content == null:
		return
	_repair_misplaced_workspace_infrastructure(content, workspace)
	if loaded_content_sector != NO_SECTOR:
		_recover_richer_content_backup(content, loaded_content_sector)
	_make_sector_content_editable(content, workspace)


# Las escenas de sector se empaquetan con SectorContent como owner, pero al
# insertarlas en el workspace Godot ocultaria esos nodos como internos de un
# bloque unico. Promover solo los nodos pertenecientes a esa escena permite
# editarlos desde el arbol sin expandir los hijos internos de GLB u otras escenas.
func _make_sector_content_editable(content: Node3D, workspace: Node) -> void:
	if content == null or workspace == null:
		return
	content.owner = workspace
	content.set_meta("_edit_lock_", true)
	_promote_sector_content_owners(content, content, workspace)
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := content.get_node_or_null(NodePath(String(category_name)))
		if category != null:
			category.set_meta("_edit_lock_", true)


func _promote_sector_content_owners(node: Node, content_owner: Node, workspace: Node) -> void:
	for child in node.get_children():
		if child.owner == content_owner:
			child.owner = workspace
		_promote_sector_content_owners(child, content_owner, workspace)


func _repair_misplaced_workspace_infrastructure(content: Node3D, workspace: Node) -> Array[String]:
	var repaired: Array[String] = []
	if content == null or workspace == null:
		return repaired
	for infrastructure_name in WORKSPACE_INFRASTRUCTURE_NODES:
		if infrastructure_name == SECTOR_CONTENT_ROOT_NAME:
			continue
		var misplaced := content.find_child(String(infrastructure_name), true, false)
		if misplaced == null:
			continue
		var existing := workspace.get_node_or_null(NodePath(String(infrastructure_name)))
		if existing != null and existing != misplaced:
			continue
		var preserve_global_transform := misplaced.is_inside_tree() and workspace.is_inside_tree()
		misplaced.owner = null
		misplaced.reparent(workspace, preserve_global_transform)
		misplaced.owner = workspace
		repaired.append(String(infrastructure_name))
	if not repaired.is_empty() and editor_interface != null:
		editor_interface.mark_scene_as_unsaved()
	return repaired


func _recover_richer_content_backup(content: Node3D, sector: Vector2i) -> bool:
	if content == null:
		return false
	var canonical_path := _sector_content_path(sector)
	var backup_path := _sector_content_backup_path(sector)
	if not ResourceLoader.exists(canonical_path) and ResourceLoader.exists(backup_path):
		var backup_result := _load_content_scene_for_recovery(backup_path, sector)
		if bool(backup_result.get("ok", false)):
			var backup := backup_result.get("node") as Node3D
			_merge_sector_content_nodes(backup, content, sector, true)
			backup.free()
			if editor_interface != null:
				editor_interface.mark_scene_as_unsaved()
			return true
	return false


func _load_content_scene_for_recovery(path: String, sector: Vector2i) -> Dictionary:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {"ok": false}
	var content := packed.instantiate() as Node3D
	if content == null:
		return {"ok": false}
	content.scene_file_path = ""
	var declared_sector := _declared_content_sector(content)
	if declared_sector != NO_SECTOR and declared_sector != sector:
		content.free()
		return {"ok": false}
	_normalize_sector_content(content, sector)
	var validation_error := _validate_sector_content(content, sector, true)
	if not validation_error.is_empty():
		content.free()
		return {"ok": false}
	return {"ok": true, "node": content}


func _free_recovery_result(result: Dictionary) -> void:
	var node := result.get("node") as Node
	if node != null:
		node.free()


func _sector_content_object_count(content: Node3D) -> int:
	if content == null:
		return 0
	var count := 0
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := content.get_node_or_null(NodePath(String(category_name)))
		if category != null:
			count += category.get_child_count()
	return count


func _normalize_sector_content(content: Node3D, sector: Vector2i) -> void:
	content.name = SECTOR_CONTENT_ROOT_NAME
	var categories: Dictionary = {}
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := content.get_node_or_null(NodePath(String(category_name))) as Node3D
		if category == null:
			category = Node3D.new()
			category.name = category_name
			content.add_child(category)
			category.owner = content
		categories[category_name] = category

	for child in content.get_children().duplicate():
		if child.name in SECTOR_CONTENT_CATEGORIES:
			continue
		var destination := categories.get(_category_for_content_node(child)) as Node3D
		if destination == null:
			destination = categories.get(&"Props") as Node3D
		child.owner = null
		content.remove_child(child)
		destination.add_child(child)
		child.owner = content
	_set_content_sector_metadata(content, sector)


func _merge_sector_content_nodes(source: Node3D, destination: Node3D, sector: Vector2i, prefer_destination_on_name_conflict: bool = false) -> void:
	if source == null or destination == null or source == destination:
		return
	_normalize_sector_content(source, sector)
	_normalize_sector_content(destination, sector)
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var source_category := source.get_node_or_null(NodePath(String(category_name))) as Node3D
		var destination_category := destination.get_node_or_null(NodePath(String(category_name))) as Node3D
		if source_category == null or destination_category == null:
			continue
		for child in source_category.get_children().duplicate():
			if prefer_destination_on_name_conflict and destination_category.get_node_or_null(NodePath(String(child.name))) != null:
				child.free()
				continue
			child.owner = null
			source_category.remove_child(child)
			destination_category.add_child(child, true)
			child.owner = destination
	_set_content_sector_metadata(destination, sector)


func _category_for_content_node(node: Node) -> StringName:
	var lower_name := String(node.name).to_lower()
	if lower_name.contains("rock") or lower_name.contains("stone") or lower_name.contains("piedra"):
		return &"Rocks"
	if lower_name.contains("tree") or lower_name.contains("bush") or lower_name.contains("grass") or lower_name.contains("plant") or lower_name.contains("veget"):
		return &"Vegetation"
	if lower_name.contains("house") or lower_name.contains("building") or lower_name.contains("wall") or lower_name.contains("bridge") or lower_name.contains("casa"):
		return &"Buildings"
	if lower_name.contains("npc") or lower_name.contains("enemy") or lower_name.contains("character") or lower_name.contains("villager"):
		return &"NPCs"
	return &"Props"


func _set_content_sector_metadata(content: Node, sector: Vector2i) -> void:
	content.set_meta("content_version", SECTOR_CONTENT_VERSION)
	content.set_meta("sector_x", sector.x)
	content.set_meta("sector_y", sector.y)


func _declared_content_sector(content: Node) -> Vector2i:
	if content == null or not content.has_meta("sector_x") or not content.has_meta("sector_y"):
		return NO_SECTOR
	return Vector2i(int(content.get_meta("sector_x")), int(content.get_meta("sector_y")))


func _validate_sector_content(content: Node3D, sector: Vector2i, require_metadata: bool) -> String:
	if content == null or content.name != SECTOR_CONTENT_ROOT_NAME:
		return "Contenido invalido: la raiz debe llamarse SectorContent."
	var declared_sector := _declared_content_sector(content)
	if require_metadata and declared_sector == NO_SECTOR:
		return "Contenido invalido: faltan las coordenadas del sector."
	if declared_sector != NO_SECTOR and declared_sector != sector:
		return "Contenido invalido: pertenece a " + _sector_label(declared_sector) + " y no a " + _sector_label(sector) + "."
	for category_name in SECTOR_CONTENT_CATEGORIES:
		if not (content.get_node_or_null(NodePath(String(category_name))) is Node3D):
			return "Contenido invalido: falta SectorContent/" + String(category_name) + "."
	for forbidden_name in WORKSPACE_INFRASTRUCTURE_NODES:
		if forbidden_name == SECTOR_CONTENT_ROOT_NAME:
			continue
		if content.find_child(String(forbidden_name), true, false) != null:
			return "Contenido invalido: " + String(forbidden_name) + " es infraestructura del workspace y no puede guardarse dentro del sector."
	return ""


func _sector_content_has_objects(content: Node3D) -> bool:
	if content == null:
		return false
	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := content.get_node_or_null(NodePath(String(category_name)))
		if category != null and category.get_child_count() > 0:
			return true
	for child in content.get_children():
		if not (child.name in SECTOR_CONTENT_CATEGORIES):
			return true
	return false


func _workspace_loose_content_names() -> Array[String]:
	var names: Array[String] = []
	var workspace := _find_workspace_root()
	if workspace == null:
		return names
	for child in workspace.get_children():
		if child.name in WORKSPACE_INFRASTRUCTURE_NODES:
			continue
		if child is Node3D:
			names.append(String(child.name))
	return names


func _loose_content_error(names: Array[String]) -> String:
	var preview := names.slice(0, mini(names.size(), 5))
	var suffix := "..." if names.size() > preview.size() else ""
	return "Cambio bloqueado: hay objetos fuera de SectorContent (" + ", ".join(preview) + suffix + "). Muevelos a Rocks, Vegetation, Buildings, NPCs o Props para que no se mezclen entre sectores."


func _import_selected_sector_centered(force_fresh: bool = false) -> bool:
	if sector_transition_in_progress:
		_set_status("Ya hay un cambio de sector Terrain3D en curso.")
		return false
	sector_transition_in_progress = true
	var target_sector := selected_sector
	_set_generation_buttons_enabled(false)
	_set_ocean_preview_transition(true)
	var imported := await _import_selected_sector_centered_staged(target_sector, force_fresh)
	_set_ocean_preview_transition(false)
	sector_transition_in_progress = false
	if not generation_in_progress:
		_set_generation_buttons_enabled(true)
	return imported


func _import_selected_sector_centered_staged(target_sector: Vector2i, force_fresh: bool = false) -> bool:
	var export_dir := str(exported_sectors.get(_sector_key(target_sector), ""))
	var edit_dir := _sector_edit_dir(target_sector)
	var has_saved_edits := _edit_dir_has_data(edit_dir)
	if export_dir.is_empty() and (force_fresh or not has_saved_edits):
		_set_status("Ese sector no tiene export Terrain3D. Usa Generar + cargar.")
		return false

	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer. Abre terrain3d_sector_workspace.tscn o selecciona el Importer.")
		return false
	_ensure_importer_shared_resources(importer)

	# Los scripts @tool pueden recargarse mientras el dock ya esta abierto; en ese
	# caso _ready() no vuelve a ejecutarse y el workspace puede mostrar terreno
	# aunque loaded_sector siga en NO_SECTOR. Recuperar el estado aqui vuelve el
	# primer clic autocorrectivo, sin exigir reiniciar Godot.
	if loaded_sector == NO_SECTOR or loaded_content_sector == NO_SECTOR:
		var requested_sector := target_sector
		_initialize_workspace_state()
		selected_sector = requested_sector
		_update_labels()
		if loaded_sector == NO_SECTOR or loaded_content_sector == NO_SECTOR:
			return false

	var loose_nodes := _workspace_loose_content_names()
	if not loose_nodes.is_empty():
		_set_status(_loose_content_error(loose_nodes))
		return false
	var current_content := _find_sector_content_node()
	if loaded_content_sector == NO_SECTOR and _sector_content_has_objects(current_content):
		_set_status("Cambio bloqueado: SectorContent tiene objetos, pero no esta asignado a ningun sector. Guarda o recupera su sector antes de continuar.")
		return false

	var needs_content_switch := loaded_content_sector != target_sector
	var prepared_content: Node3D = null
	var created_content := false
	if needs_content_switch:
		var prepared := _prepare_sector_content(target_sector)
		if not bool(prepared.get("ok", false)):
			_set_status(str(prepared.get("message", "No pude validar el contenido del sector destino.")))
			return false
		prepared_content = prepared.get("node") as Node3D
		created_content = bool(prepared.get("created", false))

	# Guardar y validar terreno + objetos antes de modificar el workspace.
	if loaded_sector != NO_SECTOR and loaded_sector != target_sector:
		_set_status("Guardando y validando " + _sector_label(loaded_sector) + " antes de cambiar...")
		if not _save_loaded_sector_bundle():
			if prepared_content != null:
				prepared_content.free()
			_set_status("No pude guardar terreno y contenido de " + _sector_label(loaded_sector) + "; cambio cancelado sin limpiar la escena.")
			return false
		await get_tree().process_frame

	# Si el sector ya tiene ediciones guardadas y no estamos regenerando, cargarlas.
	if not force_fresh and has_saved_edits:
		if importer.has_method("reset_terrain"):
			importer.call("reset_terrain", true)
		await get_tree().process_frame
		if not export_dir.is_empty():
			var saved_height_path := ProjectSettings.globalize_path(export_dir + "/height.exr")
			var saved_control_path := ProjectSettings.globalize_path(export_dir + "/control.exr")
			importer.set("height_file_name", saved_height_path if FileAccess.file_exists(saved_height_path) else "")
			importer.set("control_file_name", saved_control_path if FileAccess.file_exists(saved_control_path) else "")
		importer.set("data_directory", edit_dir)
		await get_tree().process_frame
		await get_tree().process_frame
		if not _terrain_data_matches_directory(importer, edit_dir):
			if prepared_content != null:
				prepared_content.free()
			loaded_sector = NO_SECTOR
			_update_sector_guide()
			_set_status("Terrain3D no confirmo la carga de " + _sector_label(target_sector) + "; cambio cancelado para evitar mostrar el sector anterior.")
			_update_labels()
			return false
		if needs_content_switch and not _activate_sector_content(prepared_content, target_sector):
			prepared_content.free()
			loaded_sector = NO_SECTOR
			_set_status("El terreno cargo, pero no pude activar su contenido. No continues editando hasta recargar el sector.")
			return false
		loaded_sector = target_sector
		_set_workspace_loaded_sector_metadata(target_sector)
		_update_sector_guide()
		_update_ocean_preview(loaded_sector)
		var saved_extra_count := _refresh_cleanup_regions_button(importer)
		var content_note := " Contenido nuevo y limpio." if created_content else " Contenido artesanal cargado."
		_set_status("Cargado " + _sector_label(target_sector) + " con tus ediciones guardadas." + content_note + _outside_regions_warning(saved_extra_count))
		call_deferred("_refresh_loaded_region_limit_state", importer)
		_update_labels()
		return true

	# Importacion fresca desde el height.exr generado por los scripts.
	var height_path := ProjectSettings.globalize_path(export_dir + "/height.exr")
	if not FileAccess.file_exists(height_path):
		if prepared_content != null:
			prepared_content.free()
		_set_status("Falta height.exr para " + _sector_label(target_sector) + ".")
		return false
	var control_path := ProjectSettings.globalize_path(export_dir + "/control.exr")
	var has_control := FileAccess.file_exists(control_path)

	if importer.has_method("reset_terrain"):
		importer.call("reset_terrain", true)
		await get_tree().process_frame
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
	await get_tree().process_frame

	# Al regenerar descartamos ediciones viejas: la base cambio.
	if force_fresh:
		_clear_edit_dir(edit_dir)

	# Persistir la carga sin volver a asignar data_directory. reset_terrain() lo deja
	# vacio y los datos importados ya estan activos en memoria. Reasignar aqui el
	# directorio recien escrito fuerza una segunda carga nativa mientras el editor
	# detecta los .res nuevos, una carrera que puede terminar en un access violation.
	if not _save_loaded_sector_to(importer, edit_dir):
		if prepared_content != null:
			prepared_content.free()
		loaded_sector = NO_SECTOR
		_set_status("Terrain3D importo " + _sector_label(target_sector) + ", pero no pude guardar sus regiones.")
		return false
	await get_tree().process_frame

	if needs_content_switch and not _activate_sector_content(prepared_content, target_sector):
		prepared_content.free()
		loaded_sector = NO_SECTOR
		_set_status("El terreno cargo, pero no pude activar su contenido. No continues editando hasta recargar el sector.")
		return false
	loaded_sector = target_sector
	_set_workspace_loaded_sector_metadata(target_sector)
	_update_sector_guide()
	_update_ocean_preview(loaded_sector)
	var imported_extra_count := _refresh_cleanup_regions_button(importer)
	var fresh_content_note := " Contenido nuevo y limpio." if created_content else " Contenido artesanal cargado."
	if force_fresh:
		_set_status("Base fresca importada " + _sector_label(target_sector) + (" con materiales base." if has_control else " sin materiales base.") + " Ediciones anteriores respaldadas." + fresh_content_note + _outside_regions_warning(imported_extra_count))
	else:
		_set_status("Cargado " + _sector_label(target_sector) + (" con materiales base." if has_control else " sin materiales base. Regeneralo para crear control.exr.") + fresh_content_note + _outside_regions_warning(imported_extra_count))
	call_deferred("_refresh_loaded_region_limit_state", importer)
	_update_labels()
	return true


func _save_current_sector_pressed() -> void:
	if loaded_sector == NO_SECTOR:
		_set_status("No hay sector cargado para guardar.")
		return
	ensure_workspace_content_editable()
	if _save_loaded_sector_bundle():
		_set_status("Guardado y validado terreno + contenido de " + _sector_label(loaded_sector) + ".")
	else:
		_set_status("No pude completar el guardado seguro. El cambio de sector quedara bloqueado.")


func _request_cleanup_outside_regions() -> void:
	if generation_in_progress:
		return
	if loaded_sector == NO_SECTOR:
		_set_status("Carga un sector antes de limpiar regiones auxiliares.")
		return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre el nodo Importer del sector cargado.")
		return
	var outside_regions := _outside_sector_regions(importer)
	if outside_regions.is_empty():
		_refresh_cleanup_regions_button(importer)
		_set_status("El sector cargado ya ocupa solo sus 4 regiones de 512 x 512.")
		return
	_ask_generation_confirmation(
		"cleanup_regions",
		true,
		"El sector %s tiene %d region(es) fuera del cuadro 512 x 512.\n\nSe respaldara completa la edicion actual y luego se quitaran solo esas regiones auxiliares. Las cuatro regiones internas no se modifican.\n\nQuieres continuar?" % [
			_sector_label(loaded_sector),
			outside_regions.size(),
		]
	)


func _cleanup_outside_regions() -> void:
	if loaded_sector == NO_SECTOR:
		return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre el nodo Importer para limpiar las regiones.")
		return
	var terrain_data: Variant = importer.get("data")
	if terrain_data == null:
		_set_status("El Terrain3D cargado no tiene datos para limpiar.")
		return
	var outside_regions := _outside_sector_regions(importer)
	if outside_regions.is_empty():
		_refresh_cleanup_regions_button(importer)
		_set_status("No hay regiones fuera del sector 512 x 512.")
		return

	var edit_dir := _sector_edit_dir(loaded_sector)
	# Guardamos primero para que el respaldo incluya el ultimo estado visible.
	if not _save_loaded_sector_to(importer, edit_dir):
		_set_status("No pude guardar el sector antes de limpiarlo; no se modifico nada.")
		return
	var backup_dir := _backup_edit_dir(edit_dir)
	if backup_dir.is_empty():
		_set_status("No pude crear el respaldo; no se modifico ninguna region.")
		return

	var paths_to_remove := _region_paths_for_regions(outside_regions)
	for region in outside_regions:
		terrain_data.call("remove_region", region, false)

	var remove_failures := 0
	var edit_abs := ProjectSettings.globalize_path(edit_dir).simplify_path().replace("\\", "/")
	for resource_path in paths_to_remove:
		var resource_abs := ProjectSettings.globalize_path(str(resource_path)).simplify_path().replace("\\", "/")
		if resource_abs.get_base_dir() != edit_abs or DirAccess.remove_absolute(resource_abs) != OK:
			remove_failures += 1

	_save_loaded_sector_to(importer, edit_dir)
	_update_ocean_preview(loaded_sector)
	var remaining_count := _refresh_cleanup_regions_button(importer)
	var message := "Limpieza lista: %d region(es) auxiliares quitadas. Respaldo: %s." % [
		outside_regions.size(),
		backup_dir,
	]
	if remove_failures > 0:
		message += " %d archivo(s) no pudieron borrarse; revisa el respaldo y vuelve a cargar." % remove_failures
	if remaining_count > 0:
		message += _outside_regions_warning(remaining_count)
	_set_status(message)


func _outside_sector_regions(importer: Node) -> Array:
	var outside: Array = []
	if importer == null:
		return outside
	var terrain_data: Variant = importer.get("data")
	if terrain_data == null or not terrain_data.has_method("get_regions_active"):
		return outside
	var regions_per_side := maxi(1, ceili(float(TERRAIN3D_SECTOR_RESOLUTION) / float(TERRAIN3D_REGION_SIZE)))
	for region in terrain_data.call("get_regions_active"):
		var location: Vector2i = region.location
		if location.x < 0 or location.y < 0 or location.x >= regions_per_side or location.y >= regions_per_side:
			outside.append(region)
	return outside


func _region_paths_for_regions(regions: Array) -> Array[String]:
	var paths: Array[String] = []
	for region in regions:
		var resource_path := String(region.resource_path)
		if not resource_path.is_empty():
			paths.append(resource_path)
	return paths


func _refresh_cleanup_regions_button(importer: Node = null) -> int:
	var current_importer := importer
	if current_importer == null:
		current_importer = _find_importer_node()
	var count := _outside_sector_regions(current_importer).size() if loaded_sector != NO_SECTOR else 0
	if cleanup_regions_button != null:
		cleanup_regions_button.disabled = count == 0
		cleanup_regions_button.text = "Limpiar fuera de 512" + (" (%d)" % count if count > 0 else "")
	return count


func _refresh_loaded_region_limit_state(importer: Node) -> void:
	if not is_instance_valid(importer):
		return
	var count := _refresh_cleanup_regions_button(importer)
	if count > 0 and status_label != null and not status_label.text.contains("regiones fuera"):
		_set_status(status_label.text + _outside_regions_warning(count))


func _outside_regions_warning(count: int) -> String:
	if count <= 0:
		return ""
	return " Aviso: hay %d region(es) fuera de 512 x 512; usa Limpiar fuera de 512 para respaldarlas y quitarlas." % count


func _save_loaded_sector() -> bool:
	if loaded_sector == NO_SECTOR:
		return false
	var importer := _find_importer_node()
	if importer == null:
		return false
	return _save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))


func _terrain_data_matches_directory(importer: Node, expected_directory: String) -> bool:
	if importer == null:
		return false
	var current_dir := str(importer.get("data_directory")).replace("\\", "/").trim_suffix("/")
	var normalized_expected := expected_directory.replace("\\", "/").trim_suffix("/")
	if current_dir != normalized_expected and ProjectSettings.globalize_path(current_dir).replace("\\", "/").trim_suffix("/") != ProjectSettings.globalize_path(normalized_expected).replace("\\", "/").trim_suffix("/"):
		return false
	var terrain_data = importer.get("data")
	if terrain_data == null:
		return false
	var regions: Array = terrain_data.call("get_regions_active")
	if regions.is_empty():
		return true
	var expected_prefix := normalized_expected + "/"
	for region in regions:
		if not (region is Resource):
			continue
		var resource_path := (region as Resource).resource_path.replace("\\", "/")
		if not resource_path.is_empty() and not resource_path.begins_with(expected_prefix):
			return false
	return true


func _save_loaded_sector_bundle() -> bool:
	if loaded_sector == NO_SECTOR:
		return false
	# El terreno se persiste aunque luego la validacion de objetos detecte un
	# problema. Asi una piedra mal ubicada nunca impide salvar una pincelada.
	if not _save_loaded_sector():
		return false
	if loaded_content_sector != loaded_sector:
		return false
	return _save_loaded_sector_content()


func _save_loaded_sector_content() -> bool:
	var content := _find_sector_content_node()
	var workspace := _find_workspace_root()
	if content == null or workspace == null or loaded_content_sector == NO_SECTOR:
		return false
	_repair_misplaced_workspace_infrastructure(content, workspace)
	var loose_nodes := _workspace_loose_content_names()
	if not loose_nodes.is_empty():
		_set_status(_loose_content_error(loose_nodes))
		return false

	_normalize_sector_content(content, loaded_content_sector)
	var validation_error := _validate_sector_content(content, loaded_content_sector, true)
	if not validation_error.is_empty():
		_set_status(validation_error)
		return false

	# Los nodos agregados desde el editor suelen tener como owner la raiz del
	# workspace. Para empaquetar solo SectorContent se los reasigna de forma
	# temporal y se restaura inmediatamente despues, incluso si pack() falla.
	var reassigned_nodes: Array[Node] = []
	_collect_workspace_owned_content_nodes(content, workspace, reassigned_nodes)
	for node in reassigned_nodes:
		node.owner = content
	var packed := PackedScene.new()
	var pack_error := packed.pack(content)
	for node in reassigned_nodes:
		if is_instance_valid(node):
			node.owner = workspace
	if pack_error != OK:
		_set_status("No pude empaquetar SectorContent: error " + str(pack_error) + ".")
		return false

	var expected_manifest := _content_manifest(content)
	var content_path := _sector_content_path(loaded_content_sector)
	var pending_path := _sector_content_pending_path(loaded_content_sector)
	var backup_path := _sector_content_backup_path(loaded_content_sector)
	for directory_path in [SECTOR_CONTENT_DIR, SECTOR_CONTENT_BACKUP_DIR]:
		var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
		if make_error != OK:
			_set_status("No pude crear la carpeta de contenido seguro: error " + str(make_error) + ".")
			return false

	var pending_absolute := ProjectSettings.globalize_path(pending_path)
	if FileAccess.file_exists(pending_absolute):
		DirAccess.remove_absolute(pending_absolute)
	var save_error := ResourceSaver.save(packed, pending_path)
	if save_error != OK:
		_set_status("No pude escribir el archivo temporal de SectorContent: error " + str(save_error) + ".")
		return false
	var pending_validation := _validate_saved_content_scene(pending_path, loaded_content_sector, expected_manifest)
	if not bool(pending_validation.get("ok", false)):
		_set_status(str(pending_validation.get("message", "Fallo la validacion del contenido temporal.")))
		return false

	var content_absolute := ProjectSettings.globalize_path(content_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var had_previous := FileAccess.file_exists(content_absolute)
	if had_previous:
		var preserve_richer_backup := FileAccess.file_exists(backup_absolute) and _saved_content_object_count(backup_path, loaded_content_sector) > _saved_content_object_count(content_path, loaded_content_sector)
		if not preserve_richer_backup:
			if FileAccess.file_exists(backup_absolute):
				DirAccess.remove_absolute(backup_absolute)
			var backup_error := DirAccess.copy_absolute(content_absolute, backup_absolute)
			if backup_error != OK:
				_set_status("No pude crear el respaldo previo de SectorContent: error " + str(backup_error) + ".")
				return false
		var remove_error := DirAccess.remove_absolute(content_absolute)
		if remove_error != OK:
			_set_status("No pude preparar el reemplazo seguro de SectorContent: error " + str(remove_error) + ".")
			return false

	var replace_error := DirAccess.rename_absolute(pending_absolute, content_absolute)
	if replace_error != OK:
		if had_previous and FileAccess.file_exists(backup_absolute):
			DirAccess.copy_absolute(backup_absolute, content_absolute)
		_set_status("No pude activar el nuevo SectorContent: error " + str(replace_error) + ". El respaldo anterior se conservo.")
		return false

	var final_validation := _validate_saved_content_scene(content_path, loaded_content_sector, expected_manifest)
	if not bool(final_validation.get("ok", false)):
		DirAccess.remove_absolute(content_absolute)
		if had_previous and FileAccess.file_exists(backup_absolute):
			DirAccess.copy_absolute(backup_absolute, content_absolute)
		_set_status(str(final_validation.get("message", "Fallo la validacion final.")) + " Se restauro el respaldo anterior.")
		return false

	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null:
			filesystem.update_file(content_path)
	return true


func _collect_workspace_owned_content_nodes(node: Node, workspace: Node, output: Array[Node]) -> void:
	for child in node.get_children():
		if child.owner == workspace:
			output.append(child)
		_collect_workspace_owned_content_nodes(child, workspace, output)


func _validate_saved_content_scene(path: String, sector: Vector2i, expected_manifest: Array[String]) -> Dictionary:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {"ok": false, "message": "Validacion fallida: no pude volver a abrir " + path + "."}
	var loaded := packed.instantiate() as Node3D
	if loaded == null:
		return {"ok": false, "message": "Validacion fallida: " + path + " no contiene una raiz Node3D."}
	var validation_error := _validate_sector_content(loaded, sector, true)
	var actual_manifest := _content_manifest(loaded)
	loaded.free()
	if not validation_error.is_empty():
		return {"ok": false, "message": "Validacion fallida en " + path + ": " + validation_error}
	if actual_manifest != expected_manifest:
		return {"ok": false, "message": "Validacion fallida: el archivo guardado no contiene exactamente los mismos nodos que SectorContent."}
	return {"ok": true}


func _saved_content_object_count(path: String, sector: Vector2i) -> int:
	var result := _load_content_scene_for_recovery(path, sector)
	if not bool(result.get("ok", false)):
		return -1
	var content := result.get("node") as Node3D
	var count := _sector_content_object_count(content)
	content.free()
	return count


func _content_manifest(root: Node) -> Array[String]:
	var manifest: Array[String] = []
	_append_content_manifest(root, root, manifest)
	manifest.sort()
	return manifest


func _append_content_manifest(root: Node, node: Node, manifest: Array[String]) -> void:
	for child in node.get_children():
		manifest.append(str(root.get_path_to(child)) + "|" + child.get_class())
		_append_content_manifest(root, child, manifest)


func _sector_content_path(sector: Vector2i) -> String:
	return SECTOR_CONTENT_DIR + "/sector_%d_%d.tscn" % [sector.x, sector.y]


func _sector_content_pending_path(sector: Vector2i) -> String:
	return SECTOR_CONTENT_DIR + "/sector_%d_%d.pending.tscn" % [sector.x, sector.y]


func _sector_content_backup_path(sector: Vector2i) -> String:
	return SECTOR_CONTENT_BACKUP_DIR + "/sector_%d_%d.previous.tscn" % [sector.x, sector.y]


func _save_loaded_sector_to(importer: Node, edit_dir: String) -> bool:
	_ensure_importer_shared_resources(importer)
	var terrain_data = importer.get("data")
	if terrain_data == null:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(edit_dir))
	terrain_data.call("save_directory", edit_dir)
	# Los assets y el material son recursos externos compartidos. Reescribirlos en
	# cada guardado de sector (la biblioteca puede pesar varios MB) hace que el
	# EditorFileSystem intente recargarlos mientras Terrain3D aun los usa. Godot ya
	# guarda esos .tres cuando realmente se editan; aqui solo persisten las regiones.
	return _edit_dir_has_data(edit_dir)


func _ensure_importer_shared_resources(importer: Node) -> void:
	if ResourceLoader.exists(TERRAIN3D_ASSETS_PATH):
		var current_assets: Variant = importer.get("assets")
		if not (current_assets is Resource) or (current_assets as Resource).resource_path != TERRAIN3D_ASSETS_PATH:
			importer.set("assets", load(TERRAIN3D_ASSETS_PATH))
	if ResourceLoader.exists(TERRAIN3D_MATERIAL_PATH):
		var current_material: Variant = importer.get("material")
		if not (current_material is Resource) or (current_material as Resource).resource_path != TERRAIN3D_MATERIAL_PATH:
			importer.set("material", load(TERRAIN3D_MATERIAL_PATH))


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
	var backup_dir := _make_edit_backup_dir(edit_dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			var can_remove := true
			if not backup_dir.is_empty():
				var source_abs := ProjectSettings.globalize_path(edit_dir).path_join(file_name)
				var backup_abs := backup_dir.path_join(file_name)
				can_remove = _copy_file(source_abs, backup_abs) == OK
			if can_remove:
				dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _make_edit_backup_dir(edit_dir: String) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true)
	stamp = stamp.replace(":", "").replace("-", "").replace("T", "_")
	var backup_abs := ProjectSettings.globalize_path(TERRAIN3D_EDIT_BACKUP_DIR).path_join(stamp).path_join(edit_dir.get_file())
	if DirAccess.make_dir_recursive_absolute(backup_abs) != OK:
		return ""
	return backup_abs


func _backup_edit_dir(edit_dir: String) -> String:
	var dir := DirAccess.open(ProjectSettings.globalize_path(edit_dir))
	if dir == null:
		return ""
	var backup_dir := _make_edit_backup_dir(edit_dir)
	if backup_dir.is_empty():
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			var source_abs := ProjectSettings.globalize_path(edit_dir).path_join(file_name)
			if _copy_file(source_abs, backup_dir.path_join(file_name)) != OK:
				dir.list_dir_end()
				return ""
		file_name = dir.get_next()
	dir.list_dir_end()
	return backup_dir


func _copy_file(source_abs: String, target_abs: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(source_abs)
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return FileAccess.get_open_error()
	var file := FileAccess.open(target_abs, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	return OK


func _smooth_loaded_sector_pressed() -> void:
	if generation_in_progress:
		return
	if loaded_sector == NO_SECTOR:
		if not await _import_selected_sector_centered(false):
			_set_status("Carga un sector Terrain3D antes de suavizar.")
			return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer para suavizar.")
		return
	generation_in_progress = true
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Suavizando terreno cargado...")
	await get_tree().process_frame
	var result := _smooth_importer_terrain(importer)
	if bool(result.get("ok", false)):
		_save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))
		var pixels := int(result.get("pixels", 0))
		var regions := int(result.get("regions", 0))
		_set_status("Suavizado " + _sector_label(loaded_sector) + " | regiones " + str(regions) + " | pixeles tocados " + str(pixels) + ".")
	else:
		_set_status(str(result.get("message", "No pude suavizar el terreno cargado.")))
	_show_generation_progress(100.0, "Listo.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _repair_loaded_sector_pressed() -> void:
	if generation_in_progress:
		return
	if loaded_sector == NO_SECTOR:
		if not await _import_selected_sector_centered(false):
			_set_status("Carga un sector Terrain3D antes de reparar cortes.")
			return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer para reparar cortes.")
		return
	generation_in_progress = true
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Reparando cortes del terreno cargado...")
	await get_tree().process_frame
	var result := _repair_importer_terrain(importer)
	if bool(result.get("ok", false)):
		_save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))
		var pixels := int(result.get("pixels", 0))
		var regions := int(result.get("regions", 0))
		_set_status("Cortes reparados en " + _sector_label(loaded_sector) + " | regiones " + str(regions) + " | pixeles tocados " + str(pixels) + ".")
	else:
		_set_status(str(result.get("message", "No pude reparar cortes del terreno cargado.")))
	_show_generation_progress(100.0, "Listo.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _smooth_multi_selection_pressed() -> void:
	if generation_in_progress:
		return
	var selected_queue := _multi_selected_sector_list()
	if selected_queue.is_empty():
		_set_status("No hay seleccion multiple. Arrastra sobre el mapa o usa Ctrl+click para elegir sectores.")
		return

	generation_in_progress = true
	batch_current_index = 0
	batch_total_count = selected_queue.size()
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Preparando suavizado de " + str(batch_total_count) + " sectores...")
	await get_tree().process_frame

	var smoothed_count := 0
	var skipped_count := 0
	var touched_pixels := 0
	for sector in selected_queue:
		batch_current_index += 1
		selected_sector = sector
		_update_labels()
		_update_sector_guide()
		_queue_map_redraw()
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Cargando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		if not await _import_selected_sector_centered(false):
			skipped_count += 1
			continue
		var importer := _find_importer_node()
		if importer == null:
			skipped_count += 1
			continue
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Suavizando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		var result := _smooth_importer_terrain(importer)
		if bool(result.get("ok", false)):
			_save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))
			smoothed_count += 1
			touched_pixels += int(result.get("pixels", 0))
		else:
			skipped_count += 1
		_show_generation_progress(float(batch_current_index) / float(batch_total_count) * 100.0, "Procesados " + str(batch_current_index) + "/" + str(batch_total_count) + ".")
		await get_tree().process_frame

	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)
	_set_status("Suavizado aplicado a " + str(smoothed_count) + " sector(es). Omitidos: " + str(skipped_count) + ". Pixeles tocados: " + str(touched_pixels) + ".")
	_update_labels()
	_queue_map_redraw()


func _repair_multi_selection_pressed() -> void:
	if generation_in_progress:
		return
	var selected_queue := _multi_selected_sector_list()
	if selected_queue.is_empty():
		_set_status("No hay seleccion multiple. Arrastra sobre el mapa o usa Ctrl+click para elegir sectores.")
		return

	generation_in_progress = true
	batch_current_index = 0
	batch_total_count = selected_queue.size()
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Preparando reparacion de " + str(batch_total_count) + " sectores...")
	await get_tree().process_frame

	var repaired_count := 0
	var skipped_count := 0
	var touched_pixels := 0
	for sector in selected_queue:
		batch_current_index += 1
		selected_sector = sector
		_update_labels()
		_update_sector_guide()
		_queue_map_redraw()
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Cargando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		if not await _import_selected_sector_centered(false):
			skipped_count += 1
			continue
		var importer := _find_importer_node()
		if importer == null:
			skipped_count += 1
			continue
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Reparando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		var result := _repair_importer_terrain(importer)
		if bool(result.get("ok", false)):
			_save_loaded_sector_to(importer, _sector_edit_dir(loaded_sector))
			repaired_count += 1
			touched_pixels += int(result.get("pixels", 0))
		else:
			skipped_count += 1
		_show_generation_progress(float(batch_current_index) / float(batch_total_count) * 100.0, "Procesados " + str(batch_current_index) + "/" + str(batch_total_count) + ".")
		await get_tree().process_frame

	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)
	_set_status("Reparacion aplicada a " + str(repaired_count) + " sector(es). Omitidos: " + str(skipped_count) + ". Pixeles tocados: " + str(touched_pixels) + ".")
	_update_labels()
	_queue_map_redraw()


func _analyze_loaded_sector_paint_pressed() -> void:
	if generation_in_progress:
		return
	if loaded_sector == NO_SECTOR:
		if not await _import_selected_sector_centered(false):
			_set_status("Carga un sector Terrain3D antes de analizar su pintura.")
			return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer para analizar pintura.")
		return
	generation_in_progress = true
	_set_generation_buttons_enabled(false)
	_show_generation_progress(10.0, "Analizando altura, pendientes y superficies...")
	await get_tree().process_frame
	var result := _process_importer_auto_paint(importer, false)
	if bool(result.get("ok", false)):
		var preview_path := _save_auto_paint_preview(result.get("preview") as Image, loaded_sector)
		var fallback_note := str(result.get("fallback_note", ""))
		var fallback_suffix := " | " + fallback_note if not fallback_note.is_empty() else ""
		_set_status("Analisis listo para " + _sector_label(loaded_sector) + " | perfil " + str(result.get("biome_name", "Templado")) + " | borde " + str(int(result.get("edge_radius", 0))) + " px" + fallback_suffix + " | preview: " + preview_path)
	else:
		_set_status(str(result.get("message", "No pude analizar la pintura.")))
	_show_generation_progress(100.0, "Listo.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _paint_loaded_sector_pressed() -> void:
	if generation_in_progress:
		return
	if loaded_sector == NO_SECTOR:
		if not await _import_selected_sector_centered(false):
			_set_status("Carga un sector Terrain3D antes de pintarlo.")
			return
	var importer := _find_importer_node()
	if importer == null:
		_set_status("No encontre nodo Importer para pintar.")
		return
	generation_in_progress = true
	_set_generation_buttons_enabled(false)
	_show_generation_progress(5.0, "Guardando base y creando respaldo...")
	await get_tree().process_frame
	var edit_dir := _sector_edit_dir(loaded_sector)
	_save_loaded_sector_to(importer, edit_dir)
	var backup_dir := _backup_edit_dir(edit_dir)
	if backup_dir.is_empty():
		_set_status("No pude crear el respaldo; pintura cancelada.")
		_hide_generation_progress()
		generation_in_progress = false
		_set_generation_buttons_enabled(true)
		return
	_show_generation_progress(30.0, "Pintando con transiciones suaves...")
	await get_tree().process_frame
	var result := _process_importer_auto_paint(importer, true)
	if bool(result.get("ok", false)):
		_save_loaded_sector_to(importer, edit_dir)
		var preview_path := _save_auto_paint_preview(result.get("preview") as Image, loaded_sector)
		var fallback_note := str(result.get("fallback_note", ""))
		var fallback_suffix := " | " + fallback_note if not fallback_note.is_empty() else ""
		_set_status("Pintura aplicada a " + _sector_label(loaded_sector) + " | perfil " + str(result.get("biome_name", "Templado")) + " | " + str(int(result.get("pixels", 0))) + " pixeles" + fallback_suffix + " | respaldo: " + backup_dir + " | preview: " + preview_path)
	else:
		_set_status(str(result.get("message", "No pude pintar el sector.")))
	_show_generation_progress(100.0, "Listo.")
	await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)


func _paint_multi_selection_pressed() -> void:
	if generation_in_progress:
		return
	var selected_queue := _multi_selected_sector_list()
	if selected_queue.is_empty():
		_set_status("No hay seleccion multiple para pintar.")
		return
	generation_in_progress = true
	batch_current_index = 0
	batch_total_count = selected_queue.size()
	_set_generation_buttons_enabled(false)
	_show_generation_progress(0.0, "Preparando pintura de " + str(batch_total_count) + " sectores...")
	await get_tree().process_frame
	var painted_count := 0
	var skipped_count := 0
	for sector in selected_queue:
		batch_current_index += 1
		selected_sector = sector
		_update_labels()
		_update_sector_guide()
		_queue_map_redraw()
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Cargando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		if not await _import_selected_sector_centered(false):
			skipped_count += 1
			continue
		var importer := _find_importer_node()
		if importer == null:
			skipped_count += 1
			continue
		var edit_dir := _sector_edit_dir(loaded_sector)
		_save_loaded_sector_to(importer, edit_dir)
		if _backup_edit_dir(edit_dir).is_empty():
			skipped_count += 1
			continue
		_show_generation_progress(float(batch_current_index - 1) / float(batch_total_count) * 100.0, "Pintando " + _sector_label(sector) + "...")
		await get_tree().process_frame
		var result := _process_importer_auto_paint(importer, true)
		if bool(result.get("ok", false)):
			_save_loaded_sector_to(importer, edit_dir)
			_save_auto_paint_preview(result.get("preview") as Image, loaded_sector)
			painted_count += 1
		else:
			skipped_count += 1
		_show_generation_progress(float(batch_current_index) / float(batch_total_count) * 100.0, "Procesados " + str(batch_current_index) + "/" + str(batch_total_count) + ".")
		await get_tree().process_frame
	_hide_generation_progress()
	generation_in_progress = false
	_set_generation_buttons_enabled(true)
	_set_status("Pintura automatica aplicada a " + str(painted_count) + " sector(es). Omitidos: " + str(skipped_count) + ".")
	_update_labels()
	_queue_map_redraw()


func _process_importer_auto_paint(importer: Node, apply: bool) -> Dictionary:
	var terrain_data: Variant = importer.get("data")
	if terrain_data == null:
		return {"ok": false, "message": "El Importer no tiene Terrain3DData cargado."}
	var painter: RefCounted = AUTO_PAINTER_SCRIPT.new()
	var sector_info := _get_sector_dict(loaded_sector)
	var biome_id := _effective_biome_id_for_sector(loaded_sector, sector_info)
	var surface_id := _effective_surface_id_for_sector(loaded_sector, sector_info)
	return painter.call("process_terrain_data", terrain_data, {
		"apply": apply,
		"edge_radius": int(paint_edge_radius_spin.value) if paint_edge_radius_spin != null else 5,
		"water_level": 2.0,
		"beach_height": 4.6,
		"cliff_slope": 27.0,
		"biome_id": biome_id,
		"surface_id": surface_id,
	})


func _save_auto_paint_preview(image: Image, sector: Vector2i) -> String:
	if image == null:
		return ""
	var absolute_dir := ProjectSettings.globalize_path(TERRAIN3D_PAINT_PREVIEW_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := TERRAIN3D_PAINT_PREVIEW_DIR + "/sector_%d_%d.png" % [sector.x, sector.y]
	return path if image.save_png(ProjectSettings.globalize_path(path)) == OK else ""


func _smooth_importer_terrain(importer: Node) -> Dictionary:
	return _process_importer_height_maps(importer, false)


func _repair_importer_terrain(importer: Node) -> Dictionary:
	return _process_importer_height_maps(importer, true)


func _process_importer_height_maps(importer: Node, repair_cuts: bool) -> Dictionary:
	var terrain_data: Variant = importer.get("data")
	if terrain_data == null:
		return {"ok": false, "message": "El Importer no tiene Terrain3DData cargado."}
	var normalizer: RefCounted = HEIGHTMAP_NORMALIZER_SCRIPT.new()
	var result: Dictionary = normalizer.call("process_terrain_data", terrain_data, _normalizer_options(repair_cuts))
	if not bool(result.get("ok", false)):
		return result
	if importer.has_method("update_heights"):
		importer.call("update_heights", true)
	return result


func _normalizer_options(repair_cuts: bool) -> Dictionary:
	var iterations := _smooth_iterations()
	var strength := _smooth_strength()
	var repair_radius := 0
	var smooth_radius := 1
	var limit_radius := 0
	var strict_passes := iterations
	var target_step_factor := 1.0
	if repair_cuts:
		iterations = maxi(iterations, 8)
		strength = maxf(strength, 0.95)
		repair_radius = 22
		smooth_radius = 4
		limit_radius = 4
		strict_passes = maxi(iterations + 4, 12)
		target_step_factor = 0.45
	return {
		"mode": HEIGHTMAP_NORMALIZER_SCRIPT.MODE_REPAIR_CUTS if repair_cuts else HEIGHTMAP_NORMALIZER_SCRIPT.MODE_SMOOTH,
		"iterations": iterations,
		"strength": strength,
		"max_step": _repair_threshold(),
		"preserve_outer_edges": smooth_preserve_edges_check == null or smooth_preserve_edges_check.button_pressed,
		"allow_intentional_cuts": allow_intentional_cuts_check != null and allow_intentional_cuts_check.button_pressed,
		"repair_seams": repair_cuts,
		"seam_band": 6,
		"repair_radius": repair_radius,
		"smooth_radius": smooth_radius,
		"limit_radius": limit_radius,
		"strict_passes": strict_passes,
		"target_step_factor": target_step_factor,
	}


func _smooth_iterations() -> int:
	if smooth_iterations_spin == null:
		return 4
	return clampi(int(round(smooth_iterations_spin.value)), 1, 24)


func _smooth_strength() -> float:
	if smooth_strength_spin == null:
		return 0.65
	return clampf(float(smooth_strength_spin.value), 0.05, 1.0)


func _repair_threshold() -> float:
	if repair_threshold_spin == null:
		return 1.5
	return clampf(float(repair_threshold_spin.value), 0.25, 30.0)


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
	confirm_dialog.title = "Confirmar limpieza" if action == "cleanup_regions" else "Confirmar generacion"
	confirm_dialog.ok_button_text = "Limpiar" if action == "cleanup_regions" else "Continuar"
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
	elif action == "cleanup_regions":
		_cleanup_outside_regions()


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
	if await _import_selected_sector_centered(true):
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
	if fresh_load_button != null:
		fresh_load_button.disabled = not enabled
	if cleanup_regions_button != null:
		if enabled:
			_refresh_cleanup_regions_button()
		else:
			cleanup_regions_button.disabled = true
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
	if smooth_iterations_spin != null:
		smooth_iterations_spin.editable = enabled
	if smooth_strength_spin != null:
		smooth_strength_spin.editable = enabled
	if repair_threshold_spin != null:
		repair_threshold_spin.editable = enabled
	if smooth_preserve_edges_check != null:
		smooth_preserve_edges_check.disabled = not enabled
	if allow_intentional_cuts_check != null:
		allow_intentional_cuts_check.disabled = not enabled
	if smooth_loaded_button != null:
		smooth_loaded_button.disabled = not enabled
	if smooth_selection_button != null:
		smooth_selection_button.disabled = not enabled
	if repair_loaded_button != null:
		repair_loaded_button.disabled = not enabled
	if repair_selection_button != null:
		repair_selection_button.disabled = not enabled
	if paint_edge_radius_spin != null:
		paint_edge_radius_spin.editable = enabled
	if analyze_paint_button != null:
		analyze_paint_button.disabled = not enabled
	if paint_loaded_button != null:
		paint_loaded_button.disabled = not enabled
	if paint_selection_button != null:
		paint_selection_button.disabled = not enabled


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
		guide.visible = loaded_sector != NO_SECTOR
		if loaded_sector != NO_SECTOR:
			guide.set("origin_sector", loaded_sector)


func _update_ocean_preview(next_sector: Vector2i) -> void:
	if editor_interface == null:
		return
	var root: Node = editor_interface.get_edited_scene_root()
	if root == null:
		return
	var preview := root.find_child("OceanPreview", true, false)
	if preview != null and preview.has_method("refresh_for_sector"):
		preview.call("refresh_for_sector", next_sector)


func _set_ocean_preview_transition(active: bool) -> void:
	if editor_interface == null:
		return
	var root: Node = editor_interface.get_edited_scene_root()
	if root == null:
		return
	var preview := root.find_child("OceanPreview", true, false)
	if preview != null and preview.has_method("set_terrain_transition_active"):
		preview.call("set_terrain_transition_active", active)


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
		if loaded_sector == NO_SECTOR:
			selected_text += "\nATENCION: la vista 3D no tiene un sector cargado."
		elif loaded_sector != selected_sector:
			selected_text += "\nATENCION: la vista 3D sigue en " + _sector_label(loaded_sector) + "."
		else:
			selected_text += "\nVista 3D cargada: " + _sector_label(loaded_sector)
		selected_text += " | contenido: " + (_sector_label(loaded_content_sector) if loaded_content_sector != NO_SECTOR else "ninguno")
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
	lines.append("Superficie dominante: " + _surface_name_for_sector(sector, info))
	lines.append("Bioma: " + _biome_name_for_sector(sector, info))
	var surface_counts_value: Variant = info.get("surface_counts", {})
	if surface_counts_value is Dictionary:
		var surface_counts := surface_counts_value as Dictionary
		var water_count := int(surface_counts.get("water", 0)) + int(surface_counts.get("deep_water", 0))
		lines.append("Mezcla mapa: tierra %d | costa %d | agua %d" % [
			int(surface_counts.get("land", 0)),
			int(surface_counts.get("coast", 0)),
			water_count,
		])
	var override := _get_sector_override(sector)
	if not override.is_empty():
		lines.append("Correccion: " + _override_summary(override))
	lines.append("Generacion: " + ("superficies + biomas" if _generation_uses_biomes() else "solo superficies"))
	var has_edits := _edit_dir_has_data(_sector_edit_dir(sector))
	lines.append("Edicion guardada: " + ("si (se carga antes que el export)" if has_edits else "no"))
	var content_path := _sector_content_path(sector)
	lines.append("Contenido artesanal: " + ("guardado" if ResourceLoader.exists(content_path) else "nuevo / vacio"))
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
