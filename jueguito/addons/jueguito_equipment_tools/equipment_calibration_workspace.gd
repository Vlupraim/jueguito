@tool
extends Node3D
class_name EquipmentCalibrationWorkspace

@export_file("*.glb", "*.tscn") var character_scene_path := ""
@export_file("*.glb", "*.tscn") var item_model_path := ""
@export_file("*.tscn") var output_held_scene_path := ""
@export var attachment_bone := "RightHand"


func get_item_pivot() -> Node3D:
	return find_child("HeldItemPivot", true, false) as Node3D
