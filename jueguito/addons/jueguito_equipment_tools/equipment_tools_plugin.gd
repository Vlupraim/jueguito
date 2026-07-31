@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	var DockScript := preload(
		"res://addons/jueguito_equipment_tools/equipment_calibrator_dock.gd"
	)
	dock = DockScript.new()
	dock.name = "Equipo"
	dock.call("setup", get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)


func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
