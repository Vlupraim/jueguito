extends Node

const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")

var mode := "confirmed"
var world: Node
var hud: CanvasLayer
var despawn_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		mode = arguments[0]
	if mode not in ["confirmed", "direct", "empty", "detached", "roster", "retry"]:
		_fail("Modo de prueba desconocido: " + mode)
		return
	get_tree().create_timer(5.0).timeout.connect(_on_timeout)
	var login := NetworkManager.server.login("admin")
	NetworkManager.session_token = String(login["token"])
	NetworkManager.current_character_name = "Vlupraim" if mode != "empty" else ""
	GameManager.current_character = {"name": "Vlupraim"} if mode != "empty" else {}
	GameManager.player_inventory = {"Madera": 10, "Hacha de leñador": 1}
	GameManager.equip_tool("Hacha de leñador")
	# El observador queda fuera de current_scene para comprobar el cambio al roster.
	var use_world_scene := arguments.size() > 1 and arguments[1] == "world"
	if use_world_scene:
		world = load(GameManager.WORLD_SCENE).instantiate()
		GameManager.current_character = NetworkManager.server.accounts["admin"]["characters"][0].duplicate(true)
	else:
		world = Node.new()
	world.name = "ExitTestWorld"
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if use_world_scene:
		hud = world.get("gameplay_hud")
	else:
		hud = HUD_SCENE.instantiate()
		world.add_child(hud)
	await get_tree().process_frame
	NetworkManager.player_despawned.connect(_on_despawned)
	SettingsManager._settings["general"]["confirm_exit"] = mode == "confirmed"
	hud.call("open_pause_menu")
	if not get_tree().paused:
		_fail("El menu de Escape no pauso el mundo")
		return
	if mode == "roster":
		hud.find_child("MainMenuButton", true, false).pressed.emit()
		return
	if mode == "retry":
		# Una respuesta fallida debe permitir reintentar sin cambiar de escena.
		GameManager._quit_requested = true
		NetworkManager.player_despawned.emit(false, "Desconexion rechazada")
		if GameManager._quit_requested or get_tree().current_scene != world:
			_fail("La desconexion fallida no permite reintentar")
			return
	var quit_button := hud.find_child("QuitGameButton", true, false) as Button
	var confirmation := hud.find_child("QuitGameConfirmation", true, false) as ConfirmationDialog
	if mode == "empty":
		print("GAMEPLAY_EXIT_SMOKE_OK mode=empty no_character=true")
	quit_button.pressed.emit()
	if mode == "confirmed":
		if not confirmation.visible or GameManager._quit_requested:
			_fail("Salir no espera la confirmacion del usuario")
			return
		confirmation.hide()
		confirmation.canceled.emit()
		if GameManager._quit_requested or NetworkManager.current_character_name.is_empty():
			_fail("Cancelar la salida desconecto al personaje")
			return
		quit_button.pressed.emit()
		confirmation.confirmed.emit()
	if get_tree().paused:
		_fail("La salida dejo el arbol pausado")
		return
	if mode == "detached":
		world.remove_child(hud)
		hud.free()
	elif mode != "empty":
		# Un segundo clic no debe iniciar otra desconexion.
		hud.call("_quit_game")


func _on_despawned(success: bool, _error_msg: String) -> void:
	if not success:
		return
	despawn_count += 1
	if despawn_count != 1 or not NetworkManager.current_character_name.is_empty() \
	or not GameManager.current_character.is_empty() or not GameManager.player_inventory.is_empty() \
	or not GameManager.equipped_primary_item.is_empty():
		_fail("La desconexion no limpio la sesion exactamente una vez")
		return
	if mode == "roster":
		await get_tree().process_frame
		await get_tree().process_frame
		if get_tree().current_scene == null \
		or get_tree().current_scene.scene_file_path != GameManager.CHAR_SELECT_SCENE:
			_fail("Volver a personajes no abrio el roster")
			return
		print("GAMEPLAY_EXIT_SMOKE_OK mode=roster selector=true")
		get_tree().quit(0)
	else:
		if get_tree().current_scene != world:
			_fail("Salir del juego intento abrir el selector")
			return
		if mode == "detached" and is_instance_valid(hud):
			_fail("La prueba no retiro el HUD antes de desconectar")
			return
		print("GAMEPLAY_EXIT_SMOKE_OK mode=%s despawn=true selector=false" % mode)


func _on_timeout() -> void:
	_fail("La salida no termino dentro del plazo: " + mode)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error(message)
	get_tree().quit(1)
