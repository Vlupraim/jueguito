@tool
extends Resource
class_name EquipmentItemDefinition

@export var item_name := ""
@export var display_name := ""
@export var category := "tool"
@export var tool_type := ""
@export var weapon_type := ""
@export_enum("one_hand", "two_hand") var hand_usage := "one_hand"
@export var allowed_slots: Array[String] = ["primary"]
@export_enum("primary", "secondary") var visual_slot := "primary"
@export var default_action: StringName
@export_file("*.png", "*.jpg", "*.webp", "*.svg") var icon_path := ""
@export_file("*.glb", "*.tscn") var source_model_path := ""
@export_file("*.tscn") var held_scene_path := ""
@export var attachment_primary_bone := "RightHand"
@export var attachment_secondary_bone := "LeftHand"


func to_dictionary() -> Dictionary:
	return {
		"display_name": display_name if not display_name.is_empty() else item_name,
		"category": category,
		"tool_type": tool_type,
		"weapon_type": weapon_type,
		"hand_usage": hand_usage,
		"allowed_slots": allowed_slots.duplicate(),
		"visual_slot": visual_slot,
		"default_action": String(default_action),
		"icon_path": icon_path,
		"source_model_path": source_model_path,
		"model_path": held_scene_path,
		"attachment_primary_bone": attachment_primary_bone,
		"attachment_secondary_bone": attachment_secondary_bone,
		"held_position": Vector3.ZERO,
		"held_rotation_degrees": Vector3.ZERO,
		"held_scale": 1.0,
	}
