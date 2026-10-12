extends Node

const ItemCatalog = preload("res://scripts/systems/items/item_catalog.gd")

# Autoload GameManager
# Gestiona el estado global de la sesión, la UI de personajes, y el cambio de escenas.

# Rutas de escenas
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHAR_SELECT_SCENE := "res://scenes/ui/character_selection_3d.tscn"
const WORLD_SCENE := "res://scenes/terrain3d_walk_preview.tscn"

var current_username := ""
var current_character: Dictionary = {}
var should_play_tutorial_intro := false
var player_inventory: Dictionary = {}
# El item de dos manos se guarda en primary y obliga a secondary a estar vacio.
var equipped_primary_item := ""
var equipped_secondary_item := ""
# Alias temporal para los sistemas de recoleccion escritos antes de las ranuras.
var equipped_tool_name := ""
var _quit_requested := false

signal inventory_changed(new_inventory: Dictionary)
signal equipment_changed(primary_item: String, secondary_item: String)
signal equipped_tool_changed(item_name: String)
signal character_list_refreshed(characters: Array)
signal world_exit_completed(success: bool, error_msg: String)

func _ready() -> void:
	# Nos suscribimos a los eventos autoritativos de la red simulada
	NetworkManager.login_completed.connect(_on_login_completed)
	NetworkManager.character_list_received.connect(_on_character_list_received)
	NetworkManager.character_created.connect(_on_character_created)
	NetworkManager.player_spawned.connect(_on_player_spawned)
	NetworkManager.player_despawned.connect(_on_player_despawned)
	NetworkManager.inventory_updated.connect(_on_inventory_updated)

func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func return_to_main_menu() -> void:
	current_character = {}
	should_play_tutorial_intro = false
	player_inventory = {}
	clear_equipment()
	current_username = ""
	NetworkManager.logout()
	change_scene(MAIN_MENU_SCENE)

func request_login(username: String, password: String = "") -> void:
	current_username = username
	NetworkManager.request_login(username, password)

func request_leave_world_to_roster() -> void:
	if _quit_requested:
		return
	NetworkManager.request_despawn()

func request_quit_game() -> void:
	if _quit_requested:
		return
	_quit_requested = true
	get_tree().paused = false
	if NetworkManager.current_character_name.is_empty():
		get_tree().quit()
	else:
		NetworkManager.request_despawn()

func request_create_character(char_name: String, appearance: Dictionary) -> void:
	NetworkManager.request_create_character(char_name, appearance)

func request_select_character(char_data: Dictionary) -> void:
	current_character = char_data
	should_play_tutorial_intro = not bool(char_data.get("tutorial_intro_completed", false))
	NetworkManager.request_spawn(char_data["name"])


func complete_tutorial_intro() -> void:
	should_play_tutorial_intro = false
	current_character["tutorial_intro_completed"] = true
	NetworkManager.mark_tutorial_intro_completed()


func toggle_item_equipped(item_name: String) -> bool:
	if int(player_inventory.get(item_name, 0)) <= 0:
		return false
	if not ItemCatalog.is_equippable(item_name):
		return false
	var usage := ItemCatalog.get_hand_usage(item_name)
	if usage == "two_hand":
		if equipped_primary_item == item_name and equipped_secondary_item.is_empty():
			clear_equipment()
		else:
			equipped_primary_item = item_name
			equipped_secondary_item = ""
			_emit_equipment_changed()
		return true

	var allows_primary := ItemCatalog.can_equip_in_slot(item_name, "primary")
	var allows_secondary := ItemCatalog.can_equip_in_slot(item_name, "secondary")
	if not allows_primary and not allows_secondary:
		return false
	# Los items con una sola ranura permitida nunca hacen fallback a la otra
	# mano. Una espada reemplaza la principal y un escudo reemplaza la secundaria.
	if allows_primary and not allows_secondary:
		equipped_primary_item = "" if equipped_primary_item == item_name else item_name
		_emit_equipment_changed()
		return true
	if allows_secondary and not allows_primary:
		if equipped_secondary_item == item_name:
			equipped_secondary_item = ""
		else:
			if ItemCatalog.get_hand_usage(equipped_primary_item) == "two_hand":
				equipped_primary_item = ""
			equipped_secondary_item = item_name
		_emit_equipment_changed()
		return true

	# Soporte deliberado para futuros items que permitan ambas manos.
	if equipped_primary_item == item_name:
		if equipped_secondary_item == item_name:
			equipped_secondary_item = ""
		elif int(player_inventory.get(item_name, 0)) >= 2 \
		and ItemCatalog.can_equip_in_slot(item_name, "secondary"):
			equipped_secondary_item = item_name
		else:
			equipped_primary_item = ""
	elif equipped_secondary_item == item_name:
		equipped_secondary_item = ""
	elif equipped_primary_item.is_empty() \
	or ItemCatalog.get_hand_usage(equipped_primary_item) == "two_hand":
		equipped_primary_item = item_name
		equipped_secondary_item = ""
	elif equipped_secondary_item.is_empty() \
	and ItemCatalog.can_equip_in_slot(item_name, "secondary"):
		equipped_secondary_item = item_name
	else:
		equipped_primary_item = item_name
	_emit_equipment_changed()
	return true


func unequip_slot(slot_name: String) -> void:
	if slot_name == "primary":
		equipped_primary_item = ""
	elif slot_name == "secondary":
		if ItemCatalog.get_hand_usage(equipped_primary_item) == "two_hand":
			equipped_primary_item = ""
		else:
			equipped_secondary_item = ""
	else:
		return
	_emit_equipment_changed()


func clear_equipment() -> void:
	if equipped_primary_item.is_empty() and equipped_secondary_item.is_empty():
		return
	equipped_primary_item = ""
	equipped_secondary_item = ""
	_emit_equipment_changed()


func toggle_tool(item_name: String) -> bool:
	return toggle_item_equipped(item_name)


func equip_tool(item_name: String) -> bool:
	if int(player_inventory.get(item_name, 0)) <= 0:
		return false
	if not ItemCatalog.is_equippable_tool(item_name):
		return false
	if ItemCatalog.get_hand_usage(item_name) == "two_hand" \
	or ItemCatalog.can_equip_in_slot(item_name, "primary"):
		equipped_primary_item = item_name
	else:
		equipped_secondary_item = item_name
	if ItemCatalog.get_hand_usage(item_name) == "two_hand":
		equipped_secondary_item = ""
	_emit_equipment_changed()
	return true


func has_equipped_tool_type(tool_type: String) -> bool:
	for item_name in [equipped_primary_item, equipped_secondary_item]:
		if not item_name.is_empty() and ItemCatalog.get_tool_type(item_name) == tool_type:
			return true
	return false


func _emit_equipment_changed() -> void:
	var previous_tool := equipped_tool_name
	equipped_tool_name = ""
	for item_name in [equipped_primary_item, equipped_secondary_item]:
		if not ItemCatalog.get_tool_type(item_name).is_empty():
			equipped_tool_name = item_name
			break
	equipment_changed.emit(equipped_primary_item, equipped_secondary_item)
	if previous_tool != equipped_tool_name:
		equipped_tool_changed.emit(equipped_tool_name)


func _validate_equipment_against_inventory() -> void:
	var used: Dictionary = {}
	for slot_name in ["primary", "secondary"]:
		var item_name := equipped_primary_item if slot_name == "primary" \
			else equipped_secondary_item
		if item_name.is_empty():
			continue
		if not ItemCatalog.can_equip_in_slot(item_name, slot_name):
			if slot_name == "primary":
				equipped_primary_item = ""
			else:
				equipped_secondary_item = ""
			continue
		used[item_name] = int(used.get(item_name, 0)) + 1
		if int(used[item_name]) > int(player_inventory.get(item_name, 0)):
			if slot_name == "primary":
				equipped_primary_item = ""
			else:
				equipped_secondary_item = ""
	if ItemCatalog.get_hand_usage(equipped_primary_item) == "two_hand":
		equipped_secondary_item = ""
	_emit_equipment_changed()

# --- Gestores de eventos de red ---

func _on_login_completed(success: bool, error_msg: String) -> void:
	if success:
		change_scene(CHAR_SELECT_SCENE)
	else:
		printerr("Error de login: ", error_msg)

func _on_character_list_received(characters: Array) -> void:
	character_list_refreshed.emit(characters)

func _on_character_created(success: bool, char_data: Dictionary, error_msg: String) -> void:
	if success:
		# Refrescar el roster sin repetir el login ni recargar la escena.
		NetworkManager.request_character_list()
	else:
		printerr("Error creando personaje: ", error_msg)

func _on_player_spawned(sector_coord: Vector2i, spawn_position: Vector3, spawn_rotation: float) -> void:
	current_character["current_sector"] = sector_coord
	current_character["position"] = spawn_position
	current_character["rotation"] = spawn_rotation
	change_scene(WORLD_SCENE)

func _on_player_despawned(success: bool, error_msg: String) -> void:
	if success:
		current_character = {}
		should_play_tutorial_intro = false
		player_inventory = {}
		clear_equipment()
		# El autoload sigue dentro del arbol durante la desconexion. Al cerrar
		# el juego no debemos cambiar de escena ni dejar la salida a cargo del HUD.
		if _quit_requested:
			get_tree().quit()
		else:
			change_scene(CHAR_SELECT_SCENE)
	else:
		_quit_requested = false
	world_exit_completed.emit(success, error_msg)

func _on_inventory_updated(inventory: Dictionary) -> void:
	player_inventory = inventory
	_validate_equipment_against_inventory()
	inventory_changed.emit(player_inventory)
	print("GameManager: Inventario actualizado autoritativamente -> ", player_inventory)
