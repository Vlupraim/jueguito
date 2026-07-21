@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	var DockScript := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")
	dock = DockScript.new()
	dock.name = "Mapa Sectores MMO"
	if dock.has_method("setup"):
		dock.call("setup", get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)


func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


# Godot llama este hook al guardar la escena/proyecto desde el editor (Ctrl+S).
# Terrain3D mantiene datos externos a la escena, por lo que se los delegamos al
# dock para que el guardado normal incluya el sector activo y sus recursos.
func _save_external_data() -> void:
	if dock != null and dock.has_method("save_external_data"):
		dock.call("save_external_data")
