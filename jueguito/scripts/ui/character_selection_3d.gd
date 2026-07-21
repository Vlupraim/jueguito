extends Node3D

# Selector y creador 3D. La lista y la personalizacion son estados separados que
# reutilizan el mismo pedestal, camara y preview animado.

enum ViewState { ROSTER, CREATOR }

const MAX_CHARACTERS := 4
const AnimationRetargeter = preload(
	"res://scripts/characters/player/character_animation_retargeter.gd"
)
const SHARED_ANIMATION_SOURCE := AnimationRetargeter.DEFAULT_SOURCE_PATH

const MODELS := [
	{
		"body_id": "strongman",
		"name": "Hombre Musculoso",
		"model_path": "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
		"animation_source_path": SHARED_ANIMATION_SOURCE,
		"visual_scale": 1.0,
	},
]

const HAIRS := [
	{
		"name": "Sin cabello",
		"hair_path": "",
	},
]

@onready var screen_title: Label = $CanvasLayer/UI/ScreenTitle
@onready var list_panel: PanelContainer = %ListPanel
@onready var selection_panel: PanelContainer = %SelectionPanel
@onready var creation_panel: PanelContainer = %CreationPanel
@onready var character_list_container: VBoxContainer = %CharacterListContainer
@onready var slot_counter_label: Label = %SlotCounterLabel
@onready var selected_name_label: Label = %SelectedNameLabel
@onready var selected_details_label: Label = %SelectedDetailsLabel
@onready var primary_action_button: Button = %PrimaryActionButton
@onready var char_name_input: LineEdit = %CharNameInput
@onready var create_button: Button = %CreateButton
@onready var back_button: Button = %BackButton
@onready var create_error_label: Label = %CreateErrorLabel
@onready var model_option_button: OptionButton = %ModelOptionButton
@onready var hair_option_button: OptionButton = %HairOptionButton
@onready var hair_color_picker_button: ColorPickerButton = %HairColorPickerButton
@onready var rotate_area: Control = %RotateArea
@onready var spawn_point: Node3D = $CharacterSpawn

var view_state := ViewState.ROSTER
var characters: Array[Dictionary] = []
var slot_buttons: Array[Button] = []
var selected_slot_index := 0
var selected_character: Dictionary = {}
var current_spawned_character: Node3D
var current_animation_player: AnimationPlayer
var dragging := false


func _ready() -> void:
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_show_roster)
	char_name_input.text_submitted.connect(func(_text: String): _on_create_pressed())

	model_option_button.clear()
	for index in range(MODELS.size()):
		model_option_button.add_item(MODELS[index]["name"], index)
	model_option_button.item_selected.connect(_on_model_item_selected)

	hair_option_button.clear()
	for index in range(HAIRS.size()):
		hair_option_button.add_item(HAIRS[index]["name"], index)
	hair_option_button.item_selected.connect(_on_hair_item_selected)
	hair_color_picker_button.color_changed.connect(_on_hair_color_changed)
	rotate_area.gui_input.connect(_on_rotate_area_gui_input)

	GameManager.character_list_refreshed.connect(_on_character_list_refreshed)
	NetworkManager.character_created.connect(_on_character_created)

	view_state = ViewState.ROSTER
	_on_character_list_refreshed(_current_account_characters())


func _current_account_characters() -> Array:
	var account_name: String = NetworkManager.server.active_sessions.get(
		NetworkManager.session_token,
		""
	)
	if account_name.is_empty() or not NetworkManager.server.accounts.has(account_name):
		return []
	return NetworkManager.server.accounts[account_name].get("characters", [])


func _on_character_list_refreshed(next_characters: Array) -> void:
	var previous_name := String(selected_character.get("name", ""))
	characters.clear()
	for character_data in next_characters:
		if character_data is Dictionary and characters.size() < MAX_CHARACTERS:
			characters.append((character_data as Dictionary).duplicate(true))
	_render_slots()

	if view_state != ViewState.ROSTER:
		return
	var next_slot := _find_character_slot(previous_name)
	if next_slot < 0:
		next_slot = mini(characters.size(), MAX_CHARACTERS - 1) if characters.is_empty() else 0
	_select_slot(next_slot)


func _render_slots() -> void:
	for child in character_list_container.get_children():
		child.free()
	slot_buttons.clear()

	for slot_index in range(MAX_CHARACTERS):
		var button := Button.new()
		button.name = "CharacterSlot%d" % (slot_index + 1)
		button.custom_minimum_size = Vector2(0.0, 82.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		if slot_index < characters.size():
			var character_data := characters[slot_index]
			button.text = "%s\nNivel %d · %s" % [
				String(character_data.get("name", "Sin nombre")),
				int(character_data.get("level", 1)),
				_body_display_name(String(character_data.get("body_id", ""))),
			]
			button.tooltip_text = "Seleccionar %s" % character_data.get("name", "personaje")
		else:
			button.text = "Espacio %d\n＋ Crear personaje" % (slot_index + 1)
			button.modulate = Color(0.78, 0.83, 0.92, 0.82)
			button.tooltip_text = "Usar este espacio para un personaje nuevo"
		button.pressed.connect(_select_slot.bind(slot_index))
		character_list_container.add_child(button)
		slot_buttons.append(button)

	slot_counter_label.text = "%d de %d espacios utilizados" % [
		characters.size(),
		MAX_CHARACTERS,
	]


func _select_slot(slot_index: int) -> void:
	selected_slot_index = clampi(slot_index, 0, MAX_CHARACTERS - 1)
	selected_character = {}
	if selected_slot_index < characters.size():
		selected_character = characters[selected_slot_index]
		selected_name_label.text = String(selected_character.get("name", "Personaje"))
		selected_details_label.text = "Nivel %d · %s" % [
			int(selected_character.get("level", 1)),
			_body_display_name(String(selected_character.get("body_id", ""))),
		]
		primary_action_button.text = "Iniciar aventura"
		primary_action_button.disabled = false
		_update_3d_character(selected_character)
	else:
		selected_name_label.text = "Espacio vacío"
		selected_details_label.text = "Crea un personaje para comenzar tu aventura."
		primary_action_button.text = "Crear personaje"
		primary_action_button.disabled = characters.size() >= MAX_CHARACTERS
		_clear_3d_character()
	_update_slot_highlight()


func _update_slot_highlight() -> void:
	for index in range(slot_buttons.size()):
		var occupied := index < characters.size()
		if index == selected_slot_index:
			slot_buttons[index].modulate = Color(0.62, 0.8, 1.0, 1.0)
		elif occupied:
			slot_buttons[index].modulate = Color.WHITE
		else:
			slot_buttons[index].modulate = Color(0.78, 0.83, 0.92, 0.82)


func _on_primary_action_pressed() -> void:
	if selected_character.is_empty():
		_show_creator()
		return
	primary_action_button.disabled = true
	primary_action_button.text = "Cargando aventura..."
	GameManager.request_select_character(selected_character)


func _show_creator() -> void:
	if characters.size() >= MAX_CHARACTERS:
		selected_details_label.text = "La cuenta ya alcanzó el máximo de personajes."
		return
	view_state = ViewState.CREATOR
	screen_title.text = "Crea tu personaje"
	list_panel.hide()
	selection_panel.hide()
	creation_panel.show()
	create_error_label.hide()
	create_button.disabled = false
	char_name_input.clear()
	char_name_input.grab_focus()
	var model_index := maxi(model_option_button.selected, 0)
	model_option_button.select(model_index)
	_on_model_item_selected(model_index)


func _show_roster() -> void:
	view_state = ViewState.ROSTER
	screen_title.text = "Elige tu personaje"
	creation_panel.hide()
	list_panel.show()
	selection_panel.show()
	create_error_label.hide()
	create_button.disabled = false
	_select_slot(selected_slot_index)


func _on_create_pressed() -> void:
	if view_state != ViewState.CREATOR:
		return
	if characters.size() >= MAX_CHARACTERS:
		_show_creation_error("Puedes tener como máximo cuatro personajes.")
		return
	var new_name := char_name_input.text.strip_edges()
	if new_name.length() < 3:
		_show_creation_error("El nombre debe tener al menos 3 caracteres.")
		return

	var selected_model := model_option_button.selected
	if selected_model < 0 or selected_model >= MODELS.size():
		_show_creation_error("Selecciona un tipo de cuerpo.")
		return
	var appearance: Dictionary = MODELS[selected_model].duplicate(true)
	var selected_hair := hair_option_button.selected
	if selected_hair >= 0 and selected_hair < HAIRS.size():
		appearance["hair_path"] = HAIRS[selected_hair]["hair_path"]
	appearance["hair_color"] = hair_color_picker_button.color.to_html(false)

	create_error_label.hide()
	create_button.disabled = true
	create_button.text = "Creando..."
	GameManager.request_create_character(new_name, appearance)


func _on_character_created(success: bool, char_data: Dictionary, error_msg: String) -> void:
	create_button.disabled = false
	create_button.text = "Crear"
	if not success:
		_show_creation_error(error_msg)
		return

	var created_slot := _find_character_slot(String(char_data.get("name", "")))
	if created_slot < 0 and characters.size() < MAX_CHARACTERS:
		characters.append(char_data.duplicate(true))
		created_slot = characters.size() - 1
	_render_slots()
	selected_slot_index = maxi(created_slot, 0)
	char_name_input.clear()
	_show_roster()


func _show_creation_error(message: String) -> void:
	create_error_label.text = message
	create_error_label.show()


func _find_character_slot(character_name: String) -> int:
	if character_name.is_empty():
		return -1
	for index in range(characters.size()):
		if String(characters[index].get("name", "")) == character_name:
			return index
	return -1


func _body_display_name(body_id: String) -> String:
	for model in MODELS:
		if String(model.get("body_id", "")) == body_id:
			return String(model.get("name", "Cuerpo desconocido"))
	return "Cuerpo desconocido"


func _on_model_item_selected(index: int) -> void:
	if index >= 0 and index < MODELS.size():
		_update_3d_character(MODELS[index])


func _update_3d_character(appearance: Dictionary) -> void:
	_clear_3d_character()
	var model_path: String = appearance.get("model_path", "")
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		model_path = AnimationRetargeter.DEFAULT_SOURCE_PATH
	if not ResourceLoader.exists(model_path):
		return

	var scene := load(model_path) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = "PedestalCharacter"
	instance.scale = Vector3.ONE * float(appearance.get("visual_scale", 1.0))
	instance.rotation_degrees.y = 180.0
	spawn_point.add_child(instance)
	current_spawned_character = instance

	current_animation_player = _find_animation_player(instance)
	if current_animation_player != null:
		var report := AnimationRetargeter.install_shared_library(
			instance,
			current_animation_player,
			String(appearance.get("animation_source_path", SHARED_ANIMATION_SOURCE)),
			true
		)
		if not String(report.get("error", "")).is_empty():
			push_warning("Selector 3D: " + String(report["error"]))
		var idle_name := AnimationRetargeter.shared_animation_name(&"idle")
		if current_animation_player.has_animation(idle_name):
			current_animation_player.play(idle_name)

	var hair_path := String(appearance.get("hair_path", ""))
	if hair_path.is_empty() and view_state == ViewState.CREATOR:
		var hair_index := hair_option_button.selected
		if hair_index >= 0 and hair_index < HAIRS.size():
			hair_path = String(HAIRS[hair_index]["hair_path"])
	_attach_hair(instance, hair_path)

	var hair_color := hair_color_picker_button.color
	var saved_color := String(appearance.get("hair_color", ""))
	if not saved_color.is_empty():
		hair_color = Color.from_string(saved_color, hair_color)
		hair_color_picker_button.color = hair_color
	var attachment := instance.find_child("HairAttachment", true, false)
	if attachment != null:
		_apply_hair_color(attachment, hair_color)


func _clear_3d_character() -> void:
	if current_spawned_character != null:
		current_spawned_character.queue_free()
	current_spawned_character = null
	current_animation_player = null


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var players := root.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


func _on_hair_item_selected(index: int) -> void:
	if current_spawned_character != null and index >= 0 and index < HAIRS.size():
		_attach_hair(current_spawned_character, String(HAIRS[index]["hair_path"]))


func _attach_hair(character_node: Node3D, hair_path: String) -> void:
	var skeletons := character_node.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var attachment: BoneAttachment3D
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.name == "HairAttachment":
			attachment = child as BoneAttachment3D
			break
	if attachment != null:
		for child in attachment.get_children():
			child.queue_free()
	if hair_path.is_empty() or not ResourceLoader.exists(hair_path):
		if attachment != null:
			attachment.queue_free()
		return
	if attachment == null:
		var head_bone := skeleton.find_bone("Head")
		if head_bone < 0:
			return
		attachment = BoneAttachment3D.new()
		attachment.name = "HairAttachment"
		attachment.bone_name = skeleton.get_bone_name(head_bone)
		skeleton.add_child(attachment)
	var hair_scene := load(hair_path) as PackedScene
	if hair_scene == null:
		return
	var hair_instance := hair_scene.instantiate() as Node3D
	if hair_instance == null:
		return
	var armature := skeleton.get_parent() as Node3D
	if armature != null and absf(armature.scale.x) > 0.00001:
		hair_instance.scale = Vector3.ONE / armature.scale
	attachment.add_child(hair_instance)


func _on_hair_color_changed(color: Color) -> void:
	if current_spawned_character == null:
		return
	var attachment := current_spawned_character.find_child("HairAttachment", true, false)
	if attachment != null:
		_apply_hair_color(attachment, color)


func _apply_hair_color(root: Node, color: Color) -> void:
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		var material := mesh_instance.get_active_material(0)
		if material is BaseMaterial3D:
			var material_copy := material.duplicate() as BaseMaterial3D
			material_copy.albedo_color = color
			mesh_instance.material_override = material_copy
		else:
			var new_material := StandardMaterial3D.new()
			new_material.albedo_color = color
			mesh_instance.material_override = new_material


func _on_rotate_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse_button.pressed
	elif event is InputEventMouseMotion and dragging:
		var mouse_motion := event as InputEventMouseMotion
		spawn_point.rotate_y(mouse_motion.relative.x * 0.0075)
