extends Node

const SELECTOR_SCENE := preload("res://scenes/ui/character_selection_3d.tscn")
const TEST_USERNAME := "roster_flow_smoke"

var selector: Node3D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	NetworkManager.server.accounts[TEST_USERNAME] = {"characters": []}
	var login_result: Dictionary = NetworkManager.server.login(TEST_USERNAME)
	NetworkManager.session_token = String(login_result["token"])
	GameManager.current_username = TEST_USERNAME
	GameManager.current_character = {}

	selector = SELECTOR_SCENE.instantiate()
	add_child(selector)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _validate_empty_roster():
		return
	selector.call("_show_creator")
	await get_tree().process_frame
	if not _validate_creator_state():
		return

	var name_input := selector.find_child("CharNameInput", true, false) as LineEdit
	var model_option := selector.find_child("ModelOptionButton", true, false) as OptionButton
	name_input.text = "RosterHero"
	model_option.select(0)
	selector.call("_on_model_item_selected", 0)
	selector.call("_on_create_pressed")
	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame

	var characters: Array = selector.get("characters")
	var selected_character: Dictionary = selector.get("selected_character")
	if characters.size() != 1 or selected_character.get("name", "") != "RosterHero":
		_fail("El personaje creado no regreso seleccionado al roster")
		return
	if not _is_roster_visible():
		_fail("La interfaz no regreso al roster despues de crear")
		return
	if selector.get("current_spawned_character") == null:
		_fail("El personaje creado no tiene preview central")
		return

	selector.call("_select_slot", 1)
	await get_tree().process_frame
	var action_button := selector.find_child("PrimaryActionButton", true, false) as Button
	if action_button.text != "Crear personaje":
		_fail("Un slot vacio no ofrece la accion Crear personaje")
		return
	if selector.get("current_spawned_character") != null:
		_fail("Un slot vacio conserva un preview que no corresponde")
		return

	var account_characters: Array = NetworkManager.server.accounts[TEST_USERNAME]["characters"]
	for index in range(2, 5):
		var result := NetworkManager.server.create_character(
			NetworkManager.session_token,
			"RosterHero%d" % index,
			{}
		)
		if not bool(result.get("success", false)):
			_fail("El servidor rechazo el personaje valido %d" % index)
			return
	NetworkManager.request_character_list()
	await get_tree().process_frame

	characters = selector.get("characters")
	var slot_container := selector.find_child("CharacterListContainer", true, false)
	if characters.size() != 4 or slot_container.get_child_count() != 4:
		_fail("El roster no conserva exactamente cuatro slots ocupados")
		return

	var rejected := NetworkManager.server.create_character(
		NetworkManager.session_token,
		"RosterHero5",
		{}
	)
	if bool(rejected.get("success", false)):
		_fail("El servidor permitio crear un quinto personaje")
		return
	if "cuatro" not in String(rejected.get("error", "")).to_lower():
		_fail("El limite de personajes no entrega un error comprensible")
		return

	print("CHARACTER_ROSTER_FLOW_SMOKE_OK slots=4 created=4 fifth_rejected=true")
	get_tree().quit(0)


func _validate_empty_roster() -> bool:
	var slot_container := selector.find_child("CharacterListContainer", true, false)
	var action_button := selector.find_child("PrimaryActionButton", true, false) as Button
	if slot_container == null or slot_container.get_child_count() != 4:
		_fail("Una cuenta vacia no muestra los cuatro slots")
		return false
	if not (selector.get("characters") as Array).is_empty():
		_fail("La cuenta de prueba no comienza vacia")
		return false
	if action_button == null or action_button.text != "Crear personaje":
		_fail("El primer slot vacio no queda listo para crear")
		return false
	return true


func _validate_creator_state() -> bool:
	var list_panel := selector.find_child("ListPanel", true, false) as Control
	var selection_panel := selector.find_child("SelectionPanel", true, false) as Control
	var creation_panel := selector.find_child("CreationPanel", true, false) as Control
	if list_panel.visible or selection_panel.visible or not creation_panel.visible:
		_fail("Roster y creador no estan separados visualmente")
		return false
	if selector.get("current_spawned_character") == null:
		_fail("El creador no muestra el cuerpo inicial en la plataforma")
		return false
	return true


func _is_roster_visible() -> bool:
	var list_panel := selector.find_child("ListPanel", true, false) as Control
	var selection_panel := selector.find_child("SelectionPanel", true, false) as Control
	var creation_panel := selector.find_child("CreationPanel", true, false) as Control
	return list_panel.visible and selection_panel.visible and not creation_panel.visible


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
