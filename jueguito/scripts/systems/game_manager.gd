extends Node

# Autoload GameManager
# Gestiona el estado global de la sesión, la UI de personajes, y el cambio de escenas.

# Rutas de escenas
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHAR_SELECT_SCENE := "res://scenes/ui/character_selection_3d.tscn"
const WORLD_SCENE := "res://scenes/terrain3d_walk_preview.tscn"

var current_username := ""
var current_character: Dictionary = {}
var player_inventory: Dictionary = {}

signal inventory_changed(new_inventory: Dictionary)
signal character_list_refreshed(characters: Array)

func _ready() -> void:
	# Nos suscribimos a los eventos autoritativos de la red simulada
	NetworkManager.login_completed.connect(_on_login_completed)
	NetworkManager.character_list_received.connect(_on_character_list_received)
	NetworkManager.character_created.connect(_on_character_created)
	NetworkManager.player_spawned.connect(_on_player_spawned)
	NetworkManager.inventory_updated.connect(_on_inventory_updated)

func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func return_to_main_menu() -> void:
	current_character = {}
	player_inventory = {}
	change_scene(MAIN_MENU_SCENE)

func request_login(username: String) -> void:
	current_username = username
	NetworkManager.request_login(username)

func request_create_character(char_name: String, appearance: Dictionary) -> void:
	NetworkManager.request_create_character(char_name, appearance)

func request_select_character(char_data: Dictionary) -> void:
	current_character = char_data
	NetworkManager.request_spawn(char_data["name"])

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

func _on_inventory_updated(inventory: Dictionary) -> void:
	player_inventory = inventory
	inventory_changed.emit(player_inventory)
	print("GameManager: Inventario actualizado autoritativamente -> ", player_inventory)
