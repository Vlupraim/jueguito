@tool
extends EditorPlugin

const TERRAIN3D_AUTO_REGIONS_SETTING := "terrain3d/tool_settings/auto_regions"
const WORKSPACE_ROOT_NAME := &"Terrain3DSectorWorkspace"
const SECTOR_CONTENT_NAME := &"SectorContent"
const SECTOR_CONTENT_CATEGORIES: Array[StringName] = [
	&"Rocks",
	&"Vegetation",
	&"Buildings",
	&"NPCs",
	&"Props",
]

var dock: Control


func _enter_tree() -> void:
	# Este plugin se carga antes que Terrain3D en project.godot. Dejar la opcion
	# apagada aqui garantiza que el editor C++ reciba auto_regions=false desde la
	# primera pincelada, aunque el usuario la hubiese activado en otro proyecto.
	var editor_settings := EditorInterface.get_editor_settings()
	editor_settings.set_setting(TERRAIN3D_AUTO_REGIONS_SETTING, false)
	var DockScript := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")
	dock = DockScript.new()
	dock.name = "Mapa Sectores MMO"
	if dock.has_method("setup"):
		dock.call("setup", get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	var filesystem := get_editor_interface().get_resource_filesystem()
	if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.connect(_on_resources_reimported)
	call_deferred("_ensure_current_workspace_structure")
	call_deferred("_refresh_terrain_texture_arrays")


func _exit_tree() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.disconnect(_on_resources_reimported)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


func _on_scene_changed(scene_root: Node) -> void:
	_ensure_workspace_structure(scene_root)
	call_deferred("_refresh_terrain_texture_arrays")


func _on_resources_reimported(paths: PackedStringArray) -> void:
	for path in paths:
		if path.begins_with("res://assets/environment/terrain/"):
			call_deferred("_refresh_terrain_texture_arrays")
			return


func _refresh_terrain_texture_arrays() -> void:
	var scene := get_editor_interface().get_edited_scene_root()
	if scene == null or scene.name != WORKSPACE_ROOT_NAME: return
	var terrain := scene.get_node_or_null("Importer") as Terrain3D
	if terrain == null: return
	preload("res://scripts/tools/editor/terrain_texture_binding.gd").refresh(terrain)


func _ensure_current_workspace_structure() -> void:
	_ensure_workspace_structure(get_editor_interface().get_edited_scene_root())


# El workspace es una escena reutilizable. Su contenido artesanal vive bajo un
# unico nodo para que, en el siguiente paso, el plugin pueda guardarlo/cargarlo
# como scenes/world/sectors/handmade/sector_X_Y.tscn sin incluir camara, luz ni
# herramientas de Terrain3D.
func _ensure_workspace_structure(scene_root: Node) -> void:
	if scene_root == null or scene_root.name != WORKSPACE_ROOT_NAME:
		return

	var changed := false
	var sector_content := scene_root.get_node_or_null(NodePath(String(SECTOR_CONTENT_NAME))) as Node3D
	if sector_content == null:
		sector_content = Node3D.new()
		sector_content.name = SECTOR_CONTENT_NAME
		scene_root.add_child(sector_content)
		sector_content.owner = scene_root
		changed = true

	for category_name in SECTOR_CONTENT_CATEGORIES:
		var category := sector_content.get_node_or_null(NodePath(String(category_name))) as Node3D
		if category != null:
			continue
		category = Node3D.new()
		category.name = category_name
		sector_content.add_child(category)
		category.owner = scene_root
		changed = true

	if changed:
		get_editor_interface().mark_scene_as_unsaved()


# Godot llama este hook al guardar la escena/proyecto desde el editor (Ctrl+S).
# Terrain3D y SectorContent mantienen datos por sector fuera del workspace, por
# lo que el guardado normal persiste y valida ambos antes de continuar.
func _save_external_data() -> void:
	if dock != null and dock.has_method("save_external_data"):
		dock.call("save_external_data")
