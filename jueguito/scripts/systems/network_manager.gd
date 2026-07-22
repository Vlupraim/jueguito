extends Node

# Este script emula el límite de red y el servidor autoritativo.
# El cliente llama a los métodos aquí para enviar peticiones. El servidor las procesa,
# las valida y emite señales (callbacks) de vuelta al cliente con la verdad aprobada.

signal login_completed(success: bool, error_msg: String)
signal character_list_received(characters: Array)
signal character_created(success: bool, char_data: Dictionary, error_msg: String)
signal inventory_updated(inventory: Dictionary)
signal player_spawned(sector_coord: Vector2i, spawn_position: Vector3, spawn_rotation: float)
signal player_despawned(success: bool, error_msg: String)
signal movement_approved(position: Vector3)

const MAX_CHARACTERS_PER_ACCOUNT := 4

# --- EMULACIÓN DEL SERVIDOR AUTORITATIVO ("DATABASE" EN MEMORIA) ---
class ServerMock:
	# Cuentas y personajes prefabricados (base de datos simulada)
	var accounts: Dictionary = {
		"admin": {
			"characters": [
				{
					"name": "Vlupraim",
					"body_id": "strongman",
					"level": 1,
					"inventory": {"Hierro": 5, "Madera": 10},
					"current_sector": Vector2i(27, 30),
					"position": Vector3(0.0, 1.45, 0.0),
					"model_path": "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
					"animation_source_path": "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
					"visual_scale": 1.0,
					"hair_path": "",
					"hair_color": ""
				}
			]
		}
	}
	
	var active_sessions: Dictionary = {} # token -> username
	
	func login(username: String, _password: String = "") -> Dictionary:
		# Registro automático si la cuenta no existe
		if not accounts.has(username):
			accounts[username] = {
				"characters": []
			}
		var token = "token_" + username + "_" + str(Time.get_ticks_msec())
		active_sessions[token] = username
		return {"success": true, "token": token, "characters": accounts[username]["characters"]}
		
	func create_character(token: String, char_name: String, appearance: Dictionary) -> Dictionary:
		if not active_sessions.has(token):
			return {"success": false, "error": "Sesión inválida"}
		var username = active_sessions[token]
		if accounts[username]["characters"].size() >= MAX_CHARACTERS_PER_ACCOUNT:
			return {
				"success": false,
				"error": "Puedes tener como máximo cuatro personajes"
			}
		
		# Validaciones autoritativas
		var clean_name = char_name.strip_edges()
		if clean_name == "":
			return {"success": false, "error": "El nombre no puede estar vacío"}
		if clean_name.length() < 3:
			return {"success": false, "error": "El nombre debe tener al menos 3 caracteres"}
			
		# Comprobar unicidad en todo el servidor
		for acc in accounts.values():
			for c in acc["characters"]:
				if c["name"].to_lower() == clean_name.to_lower():
					return {"success": false, "error": "El nombre del personaje ya existe"}
					
		var new_char = {
			"name": clean_name,
			"body_id": appearance.get("body_id", "strongman"),
			"level": 1,
			"inventory": {},
			# Sector inicial oficial dentro del mundo Terrain3D.
			"current_sector": Vector2i(27, 30),
			"position": Vector3(0.0, 1.45, 0.0),
			"model_path": appearance.get("model_path", ""),
			"animation_source_path": appearance.get(
				"animation_source_path",
				"res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb"
			),
			"visual_scale": appearance.get("visual_scale", 1.0),
			"hair_path": appearance.get("hair_path", ""),
			"hair_color": appearance.get("hair_color", "")
		}
		accounts[username]["characters"].append(new_char)
		return {"success": true, "character": new_char}

	func validate_movement(char_name: String, target_position: Vector3) -> Vector3:
		# En un servidor real aquí se validaría la colisión física contra un mapa de colisiones (NavMesh/Grid)
		# y la velocidad del personaje para evitar hacks de teleport.
		# Por ahora, aprobamos la posición solicitada tal cual (mock).
		return target_position

	func validate_interaction(char_name: String, item_name: String, amount: int) -> Dictionary:
		var found = false
		var target_char: Dictionary
		
		for u in accounts:
			for c in accounts[u]["characters"]:
				if c["name"] == char_name:
					target_char = c
					found = true
					break
			if found: break
			
		if not found:
			return {"success": false, "error": "Personaje no encontrado"}
			
		# Añadir ítem al inventario validado por el servidor
		if not target_char["inventory"].has(item_name):
			target_char["inventory"][item_name] = 0
		target_char["inventory"][item_name] += amount
		
		return {"success": true, "inventory": target_char["inventory"]}

# Instanciamos el servidor dentro del NetworkManager
var server := ServerMock.new()
var session_token := ""
var current_character_name := ""

# --- ENDPOINTS CLIENTE (CON SIMULACIÓN DE LATENCIA) ---

func request_login(username: String, password: String = "") -> void:
	await get_tree().create_timer(0.15).timeout # Simular ping
	var res = server.login(username, password)
	if res["success"]:
		session_token = res["token"]
		login_completed.emit(true, "")
		character_list_received.emit(res["characters"])
	else:
		login_completed.emit(false, res["error"])

func request_create_character(char_name: String, appearance: Dictionary) -> void:
	await get_tree().create_timer(0.15).timeout
	var res = server.create_character(session_token, char_name, appearance)
	if res["success"]:
		character_created.emit(true, res["character"], "")
	else:
		character_created.emit(false, {}, res["error"])


func request_character_list() -> void:
	if not server.active_sessions.has(session_token):
		character_list_received.emit([])
		return
	var username: String = server.active_sessions[session_token]
	character_list_received.emit(server.accounts[username]["characters"])

func request_spawn(char_name: String) -> void:
	current_character_name = char_name
	# Buscar los datos del personaje
	var char_data: Dictionary
	var found = false
	for u in server.accounts:
		for c in server.accounts[u]["characters"]:
			if c["name"] == char_name:
				char_data = c
				found = true
				break
		if found: break
		
	if found:
		player_spawned.emit(char_data["current_sector"], char_data["position"], 0.0)
		inventory_updated.emit(char_data["inventory"])


func request_despawn() -> void:
	# En producción, el servidor guardará el estado y liberará la entidad antes
	# de permitir que el cliente vuelva al roster.
	await get_tree().create_timer(0.1).timeout
	current_character_name = ""
	player_despawned.emit(true, "")


func logout() -> void:
	if server.active_sessions.has(session_token):
		server.active_sessions.erase(session_token)
	session_token = ""
	current_character_name = ""

func request_move(target_position: Vector3) -> void:
	# El cliente le pide al servidor moverse a X posición.
	# El servidor la valida y le devuelve la posición oficial aprobada.
	var approved_pos = server.validate_movement(current_character_name, target_position)
	movement_approved.emit(approved_pos)

func request_interaction(item_name: String, amount: int) -> void:
	# El cliente pide recolectar algo, el servidor lo procesa autoritativamente
	var res = server.validate_interaction(current_character_name, item_name, amount)
	if res["success"]:
		inventory_updated.emit(res["inventory"])
