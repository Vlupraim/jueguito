@tool
extends VBoxContainer

const WORKSPACE_PATH := "res://tools/equipment/equipment_calibration_workspace.tscn"
const DEFAULT_CHARACTER := (
	"res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb"
)
const DEFAULT_ITEM := (
	"res://assets/items/equipment/tools/axes/lumberjack_axe/lumberjack_axe.glb"
)
const DEFAULT_OUTPUT := (
	"res://assets/items/equipment/tools/axes/lumberjack_axe/lumberjack_axe_held.tscn"
)
const ITEM_PRESETS := [
	{
		"name": "Hacha de leñador",
		"model": DEFAULT_ITEM,
		"bone": "RightHand",
		"hand_usage": "two_hand",
		"visual_slot": "primary",
		"output": DEFAULT_OUTPUT,
		"definition": "res://resources/items/definitions/lumberjack_axe.tres",
	},
	{
		"name": "Espada vikinga",
		"model": "res://assets/items/weapons/melee/viking_sword/viking_sword.glb",
		"bone": "RightHand",
		"hand_usage": "one_hand",
		"visual_slot": "primary",
		"output": "res://assets/items/weapons/melee/viking_sword/viking_sword_held.tscn",
		"definition": "res://resources/items/definitions/viking_sword.tres",
	},
	{
		"name": "Escudo vikingo",
		"model": "res://assets/items/equipment/shields/viking_shield/viking_shield.glb",
		"bone": "LeftHand",
		"hand_usage": "one_hand",
		"visual_slot": "secondary",
		"output": "res://assets/items/equipment/shields/viking_shield/viking_shield_held.tscn",
		"definition": "res://resources/items/definitions/viking_shield.tres",
	},
	{
		"name": "Arco vikingo",
		"model": "res://assets/items/weapons/ranged/viking_bow/viking_bow.glb",
		"bone": "RightHand",
		"hand_usage": "two_hand",
		"visual_slot": "primary",
		"output": "res://assets/items/weapons/ranged/viking_bow/viking_bow_held.tscn",
		"definition": "res://resources/items/definitions/viking_bow.tres",
	},
]
const WorkspaceScript := preload(
	"res://addons/jueguito_equipment_tools/equipment_calibration_workspace.gd"
)
const BoneFollowerScript := preload(
	"res://addons/jueguito_equipment_tools/equipment_bone_follower.gd"
)

var editor_interface: EditorInterface
var preset_option: OptionButton
var hand_usage_option: OptionButton
var visual_slot_option: OptionButton
var character_path_edit: LineEdit
var item_path_edit: LineEdit
var bone_edit: LineEdit
var output_path_edit: LineEdit
var definition_path_edit: LineEdit
var status_label: Label
var form: VBoxContainer


func setup(next_editor_interface: EditorInterface) -> void:
	editor_interface = next_editor_interface
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(330.0, 0.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.name = "EquipmentCalibratorScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	form = VBoxContainer.new()
	form.name = "EquipmentCalibratorForm"
	form.custom_minimum_size = Vector2(310.0, 0.0)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	var title := Label.new()
	title.text = "Calibrador de equipamiento"
	title.add_theme_font_size_override("font_size", 18)
	form.add_child(title)

	var help := Label.new()
	help.text = (
		"Crea un espacio 3D, selecciona HeldItemPivot y usa los gizmos. "
		+ "Guardar genera una escena lista para equipar."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)

	var preset_label := Label.new()
	preset_label.text = "Preset"
	form.add_child(preset_label)
	preset_option = OptionButton.new()
	for preset in ITEM_PRESETS:
		preset_option.add_item(String(preset["name"]))
	preset_option.add_item("Personalizado")
	preset_option.item_selected.connect(_apply_preset)
	form.add_child(preset_option)

	var usage_label := Label.new()
	usage_label.text = "Uso de manos"
	form.add_child(usage_label)
	hand_usage_option = OptionButton.new()
	hand_usage_option.add_item("Una mano")
	hand_usage_option.add_item("Dos manos (reserva ambas)")
	hand_usage_option.item_selected.connect(_on_equipment_rule_changed)
	form.add_child(hand_usage_option)

	var visual_slot_label := Label.new()
	visual_slot_label.text = "Mano visual del modelo"
	form.add_child(visual_slot_label)
	visual_slot_option = OptionButton.new()
	visual_slot_option.add_item("Derecha / principal")
	visual_slot_option.add_item("Izquierda / secundaria")
	visual_slot_option.item_selected.connect(_on_visual_slot_changed)
	form.add_child(visual_slot_option)

	character_path_edit = _add_path_field("Personaje", DEFAULT_CHARACTER)
	item_path_edit = _add_path_field("Modelo del item", DEFAULT_ITEM)
	bone_edit = _add_path_field("Hueso", "RightHand")
	output_path_edit = _add_path_field("Escena equipada", DEFAULT_OUTPUT)
	definition_path_edit = _add_path_field(
		"Definicion del item",
		"res://resources/items/definitions/lumberjack_axe.tres"
	)

	var create_button := Button.new()
	create_button.text = "Crear / reconstruir espacio"
	create_button.tooltip_text = "Genera y abre la escena de calibracion."
	create_button.pressed.connect(_create_workspace)
	form.add_child(create_button)

	var save_button := Button.new()
	save_button.text = "Guardar item calibrado"
	save_button.tooltip_text = (
		"Guarda la transformacion de HeldItemPivot en la escena equipada."
	)
	save_button.pressed.connect(_save_calibrated_item)
	form.add_child(save_button)

	status_label = Label.new()
	status_label.text = "Listo para crear el espacio."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(status_label)
	_apply_preset(0)


func _add_path_field(caption: String, initial_value: String) -> LineEdit:
	var label := Label.new()
	label.text = caption
	form.add_child(label)
	var edit := LineEdit.new()
	edit.text = initial_value
	edit.clear_button_enabled = true
	form.add_child(edit)
	return edit


func _apply_preset(index: int) -> void:
	if index < 0 or index >= ITEM_PRESETS.size():
		return
	var preset: Dictionary = ITEM_PRESETS[index]
	item_path_edit.text = String(preset["model"])
	bone_edit.text = String(preset["bone"])
	output_path_edit.text = String(preset["output"])
	definition_path_edit.text = String(preset["definition"])
	hand_usage_option.select(1 if String(preset["hand_usage"]) == "two_hand" else 0)
	visual_slot_option.select(1 if String(preset["visual_slot"]) == "secondary" else 0)
	_update_rule_help()


func _on_equipment_rule_changed(_index: int) -> void:
	_update_rule_help()


func _on_visual_slot_changed(index: int) -> void:
	bone_edit.text = "LeftHand" if index == 1 else "RightHand"
	_update_rule_help()


func _update_rule_help() -> void:
	if status_label == null:
		return
	if hand_usage_option.selected == 1:
		status_label.text = (
			"Dos manos: ocupa ambas ranuras y muestra un solo modelo en la mano elegida."
		)
	else:
		status_label.text = (
			"Una mano: solo podra equiparse en la mano visual elegida."
		)


func _create_workspace() -> void:
	var character_scene := load(character_path_edit.text) as PackedScene
	var item_scene := load(item_path_edit.text) as PackedScene
	if character_scene == null:
		_set_status("No se pudo cargar el personaje.", true)
		return
	if item_scene == null:
		_set_status("No se pudo cargar el modelo del item.", true)
		return
	if not output_path_edit.text.begins_with("res://"):
		_set_status("La salida debe comenzar con res://.", true)
		return

	var workspace := WorkspaceScript.new() as Node3D
	workspace.name = "EquipmentCalibrationWorkspace"
	workspace.character_scene_path = character_path_edit.text
	workspace.item_model_path = item_path_edit.text
	workspace.output_held_scene_path = output_path_edit.text
	workspace.attachment_bone = bone_edit.text.strip_edges()

	var character := character_scene.instantiate() as Node3D
	if character == null:
		_set_status("La escena del personaje no tiene raiz Node3D.", true)
		workspace.free()
		return
	character.name = "CharacterPreview"
	workspace.add_child(character)
	character.owner = workspace
	workspace.set_editable_instance(character, true)

	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		_set_status("El personaje no contiene Skeleton3D.", true)
		workspace.free()
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone_name := _resolve_bone_name(skeleton, workspace.attachment_bone)
	if bone_name.is_empty():
		_set_status("No se encontro el hueso solicitado.", true)
		workspace.free()
		return
	workspace.attachment_bone = bone_name

	var attachment := BoneFollowerScript.new() as Node3D
	attachment.name = "EquipmentPreviewAttachment"
	attachment.set("character_path", NodePath("../CharacterPreview"))
	attachment.set("bone_name", bone_name)
	workspace.add_child(attachment)
	attachment.owner = workspace

	var scale_compensator := Node3D.new()
	scale_compensator.name = "ScaleCompensator"
	var armature := skeleton.get_parent() as Node3D
	if armature != null:
		scale_compensator.scale = Vector3(
			1.0 / maxf(absf(armature.scale.x), 0.0001),
			1.0 / maxf(absf(armature.scale.y), 0.0001),
			1.0 / maxf(absf(armature.scale.z), 0.0001)
		)
	attachment.add_child(scale_compensator)
	scale_compensator.owner = workspace

	var pivot := Node3D.new()
	pivot.name = "HeldItemPivot"
	pivot.transform = _load_existing_held_transform(output_path_edit.text)
	scale_compensator.add_child(pivot)
	pivot.owner = workspace

	var item := item_scene.instantiate() as Node3D
	if item == null:
		_set_status("El modelo del item no tiene raiz Node3D.", true)
		workspace.free()
		return
	item.name = "ItemModel"
	pivot.add_child(item)
	item.owner = workspace
	attachment.call("sync_to_bone")

	_add_preview_environment(workspace)
	var workspace_absolute := ProjectSettings.globalize_path(WORKSPACE_PATH)
	DirAccess.make_dir_recursive_absolute(workspace_absolute.get_base_dir())
	var packed := PackedScene.new()
	var pack_error := packed.pack(workspace)
	if pack_error != OK:
		_set_status("No se pudo empaquetar el espacio de calibracion.", true)
		workspace.free()
		return
	var save_error := ResourceSaver.save(packed, WORKSPACE_PATH)
	workspace.free()
	if save_error != OK:
		_set_status("No se pudo guardar el espacio de calibracion.", true)
		return

	editor_interface.get_resource_filesystem().scan()
	editor_interface.open_scene_from_path(WORKSPACE_PATH)
	call_deferred("_select_item_pivot_when_ready")
	_set_status(
		"Espacio abierto. Selecciona HeldItemPivot y usa mover/rotar/escalar.",
		false
	)


func _save_calibrated_item() -> void:
	var workspace := editor_interface.get_edited_scene_root()
	if workspace == null or not workspace is EquipmentCalibrationWorkspace:
		_set_status("Abre primero el espacio de calibracion.", true)
		return
	var pivot := workspace.call("get_item_pivot") as Node3D
	if pivot == null:
		_set_status("No se encontro HeldItemPivot.", true)
		return
	var model_path := String(workspace.item_model_path)
	var output_path := String(workspace.output_held_scene_path)
	var item_scene := load(model_path) as PackedScene
	if item_scene == null or not output_path.begins_with("res://"):
		_set_status("Modelo o ruta de salida invalidos.", true)
		return

	var held_root := Node3D.new()
	held_root.name = "HeldItem"
	var visual := item_scene.instantiate() as Node3D
	if visual == null:
		_set_status("El modelo no tiene raiz Node3D.", true)
		held_root.free()
		return
	visual.name = "Visual"
	var item_model := pivot.find_child("ItemModel", true, false) as Node3D
	var calibrated_transform := pivot.transform
	if item_model != null:
		# Permite corregir el item aunque se haya movido ItemModel por accidente.
		calibrated_transform *= item_model.transform
	visual.transform = calibrated_transform
	held_root.add_child(visual)
	visual.owner = held_root

	var output_absolute := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var packed := PackedScene.new()
	var pack_error := packed.pack(held_root)
	if pack_error != OK:
		_set_status("No se pudo empaquetar el item calibrado.", true)
		held_root.free()
		return
	var save_error := ResourceSaver.save(packed, output_path)
	held_root.free()
	if save_error != OK:
		_set_status("No se pudo guardar la escena equipada.", true)
		return
	# Normaliza el workspace para que el siguiente ajuste vuelva a ocurrir sobre
	# HeldItemPivot y fuerza al editor a sustituir el recurso cacheado.
	pivot.transform = calibrated_transform
	if item_model != null:
		item_model.transform = Transform3D.IDENTITY
	ResourceLoader.load(output_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	_update_item_definition(model_path, output_path)
	editor_interface.get_resource_filesystem().scan()
	_set_status(
		"Guardado. Pos %s · Rot %s · Esc %s. Deten y vuelve a ejecutar el juego."
		% [
			str(calibrated_transform.origin),
			str(pivot.rotation_degrees),
			str(pivot.scale),
		],
		false
	)


func _update_item_definition(model_path: String, held_path: String) -> void:
	var definition_path := definition_path_edit.text.strip_edges()
	if not ResourceLoader.exists(definition_path):
		return
	var definition := load(definition_path) as EquipmentItemDefinition
	if definition == null:
		return
	definition.source_model_path = model_path
	definition.held_scene_path = held_path
	definition.hand_usage = "two_hand" if hand_usage_option.selected == 1 else "one_hand"
	definition.visual_slot = "secondary" if visual_slot_option.selected == 1 else "primary"
	if definition.hand_usage == "two_hand":
		definition.allowed_slots = ["primary"]
	else:
		definition.allowed_slots = [definition.visual_slot]
	if definition.visual_slot == "secondary":
		definition.attachment_secondary_bone = bone_edit.text.strip_edges()
	else:
		definition.attachment_primary_bone = bone_edit.text.strip_edges()
	ResourceSaver.save(definition, definition_path)
	ItemCatalog.reload_resource_definitions()


func _resolve_bone_name(skeleton: Skeleton3D, requested: String) -> String:
	if skeleton.find_bone(requested) >= 0:
		return requested
	var normalized_requested := requested.to_lower().replace("_", "")
	for index in range(skeleton.get_bone_count()):
		var candidate := skeleton.get_bone_name(index)
		if candidate.to_lower().replace("_", "") == normalized_requested:
			return candidate
	return ""


func _load_existing_held_transform(output_path: String) -> Transform3D:
	if not ResourceLoader.exists(output_path):
		return Transform3D.IDENTITY
	var held_scene := load(output_path) as PackedScene
	if held_scene == null:
		return Transform3D.IDENTITY
	var held_instance := held_scene.instantiate() as Node3D
	if held_instance == null:
		return Transform3D.IDENTITY
	var visual := held_instance.find_child("Visual", true, false) as Node3D
	var result := visual.transform if visual != null else Transform3D.IDENTITY
	held_instance.free()
	return result


func _select_item_pivot_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var workspace := editor_interface.get_edited_scene_root()
	if workspace == null:
		return
	var pivot := workspace.find_child("HeldItemPivot", true, false) as Node3D
	if pivot == null:
		return
	var selection := editor_interface.get_selection()
	selection.clear()
	selection.add_node(pivot)
	status_label.text = (
		"HeldItemPivot seleccionado. Usa W para mover, E para rotar y R para escalar."
	)


func _add_preview_environment(workspace: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	workspace.add_child(light)
	light.owner = workspace

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(3.2, 1.7, 4.4)
	workspace.add_child(camera)
	camera.owner = workspace
	camera.look_at(Vector3(0.0, 1.0, 0.0))


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.48, 0.4) if is_error else Color(0.72, 0.9, 0.68)
