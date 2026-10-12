extends RefCounted
class_name ItemCatalog

const DEFINITION_DIRECTORY := "res://resources/items/definitions"

const LUMBERJACK_AXE := "Hacha de leñador"
const VIKING_SWORD := "Espada vikinga"
const VIKING_SHIELD := "Escudo vikingo"
const VIKING_BOW := "Arco vikingo"
const WOOD := "Madera"
const IRON := "Hierro"

const DEFINITIONS := {
	LUMBERJACK_AXE: {
		"display_name": LUMBERJACK_AXE,
		"category": "tool",
		"stackable": false,
		"tool_type": "axe",
		"hand_usage": "two_hand",
		"allowed_slots": ["primary"],
		"visual_slot": "primary",
		"default_action": "chop",
		"icon_path": "res://assets/items/icons/lumberjack_axe_inventory.png",
		"model_path": "res://assets/items/equipment/tools/axes/lumberjack_axe/lumberjack_axe_held.tscn",
		"source_model_path": "res://assets/items/equipment/tools/axes/lumberjack_axe/lumberjack_axe.glb",
		"attachment_bone": "RightHand",
		"held_scale": 1.0,
		"held_position": Vector3.ZERO,
		"held_rotation_degrees": Vector3.ZERO,
	},
	VIKING_SWORD: {
		"display_name": VIKING_SWORD,
		"category": "weapon",
		"stackable": false,
		"weapon_type": "sword",
		"hand_usage": "two_hand",
		"allowed_slots": ["primary"],
		"visual_slot": "primary",
		"default_action": "attack",
		"icon_path": "res://assets/items/icons/viking_sword_inventory.png",
		"model_path": "res://assets/items/weapons/melee/viking_sword/viking_sword.glb",
		"held_scale": 0.5,
		"held_position": Vector3(0.0, 0.72, 0.0),
		"held_rotation_degrees": Vector3.ZERO,
	},
	VIKING_SHIELD: {
		"display_name": VIKING_SHIELD,
		"category": "offhand",
		"stackable": false,
		"hand_usage": "one_hand",
		"allowed_slots": ["secondary"],
		"visual_slot": "secondary",
		"icon_path": "res://assets/items/icons/viking_shield_inventory.png",
		"model_path": "res://assets/items/equipment/shields/viking_shield/viking_shield.glb",
		"held_scale": 0.46,
		"held_position": Vector3.ZERO,
		"held_rotation_degrees": Vector3(0.0, 90.0, 0.0),
	},
	VIKING_BOW: {
		"display_name": VIKING_BOW,
		"category": "weapon",
		"stackable": false,
		"weapon_type": "bow",
		"hand_usage": "two_hand",
		"allowed_slots": ["primary"],
		"visual_slot": "primary",
		"default_action": "archery_shot",
		"icon_path": "res://assets/items/icons/viking_bow_inventory.png",
		"model_path": "res://assets/items/weapons/ranged/viking_bow/viking_bow.glb",
		"held_scale": 0.58,
		"held_position": Vector3.ZERO,
		"held_rotation_degrees": Vector3.ZERO,
	},
	WOOD: {
		"display_name": WOOD,
		"category": "resource",
		"stackable": true,
		"hand_usage": "",
		"icon_path": "res://assets/items/icons/wood_resource.png",
	},
	IRON: {
		"display_name": IRON,
		"category": "resource",
		"stackable": true,
		"hand_usage": "",
		"icon_path": "res://assets/items/icons/iron_resource.png",
	},
}

static var _resource_definitions: Dictionary = {}
static var _resource_definitions_loaded := false


static func get_definition(item_name: String) -> Dictionary:
	_ensure_resource_definitions_loaded()
	if _resource_definitions.has(item_name):
		return (_resource_definitions[item_name] as Dictionary).duplicate(true)
	return DEFINITIONS.get(item_name, {}) as Dictionary


static func reload_resource_definitions() -> void:
	_resource_definitions.clear()
	_resource_definitions_loaded = false
	_ensure_resource_definitions_loaded()


static func _ensure_resource_definitions_loaded() -> void:
	if _resource_definitions_loaded:
		return
	_resource_definitions_loaded = true
	if not DirAccess.dir_exists_absolute(DEFINITION_DIRECTORY):
		return
	for file_name in ResourceLoader.list_directory(DEFINITION_DIRECTORY):
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var resource := load(DEFINITION_DIRECTORY.path_join(file_name))
		if resource is EquipmentItemDefinition:
			var item_definition := resource as EquipmentItemDefinition
			if not item_definition.item_name.is_empty():
				_resource_definitions[item_definition.item_name] = (
					item_definition.to_dictionary()
				)


static func is_equippable(item_name: String) -> bool:
	return not String(get_definition(item_name).get("hand_usage", "")).is_empty()


static func is_stackable(item_name: String) -> bool:
	var definition := get_definition(item_name)
	if definition.has("stackable"):
		return bool(definition.get("stackable", false))
	return String(definition.get("hand_usage", "")).is_empty()


static func is_equippable_tool(item_name: String) -> bool:
	return is_equippable(item_name) \
		and not String(get_definition(item_name).get("tool_type", "")).is_empty()


static func get_hand_usage(item_name: String) -> String:
	return String(get_definition(item_name).get("hand_usage", ""))


static func can_equip_in_slot(item_name: String, slot_name: String) -> bool:
	var slots: Array = get_definition(item_name).get("allowed_slots", []) as Array
	return slot_name in slots


static func get_visual_slot(item_name: String) -> String:
	var definition := get_definition(item_name)
	var fallback := "secondary" if can_equip_in_slot(item_name, "secondary") \
		and not can_equip_in_slot(item_name, "primary") else "primary"
	return String(definition.get("visual_slot", fallback))


static func get_tool_type(item_name: String) -> String:
	return String(get_definition(item_name).get("tool_type", ""))


static func get_default_action(item_name: String) -> StringName:
	return StringName(get_definition(item_name).get("default_action", ""))


static func get_icon(item_name: String) -> Texture2D:
	var path := String(get_definition(item_name).get("icon_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func get_model_scene(item_name: String) -> PackedScene:
	var path := String(get_definition(item_name).get("model_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene
