extends Node

signal status_changed(message: String)
signal players_changed
signal resource_changed(resource_id: String, local_respawn_at: float)

const DEFAULT_PORT := 7777
const PROTOCOL := "coast-coop-v1"
const STARTER := {"Hacha de leñador":1,"Espada vikinga":1,"Escudo vikingo":1,"Arco vikingo":1,"Madera":0}
const AVATAR_SCRIPT := preload("res://scripts/network/remote_avatar.gd")
const WORLD_DATA := preload("res://scripts/network/coast_server_world.gd")
var active := false
var connecting := false
var is_dedicated := false
var local_peer_id := 0
var assigned_spawn := Vector3.ZERO
var players: Dictionary = {}
var resources: Dictionary = {}
var avatars: Dictionary = {}
var status := ""
var server_world: RefCounted
var room_key := ""
var nickname := ""
var server_offset := 0.0
var _elapsed := 0.0
var _deadline := 0
var _local_player: Node3D
var _world: Node3D
var _profiles := {}
var _claims := {}
var _pending_peers := {}
var _state_path := ""
var _sequence := 0
var _received_sequence := -1
var _port := DEFAULT_PORT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _failed("No se pudo conectar. Revisa dirección, puerto UDP y firewall."))
	multiplayer.server_disconnected.connect(func(): _failed("Se perdió la conexión con el servidor."))
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.peer_connected.connect(_peer_arrived)
	GameManager.equipment_changed.connect(send_equipment)
	call_deferred("_bootstrap")

func option(name: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"+name+"="): return argument.substr(name.length()+3)
	return fallback

func _bootstrap() -> void:
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args():
		is_dedicated = true
		get_tree().change_scene_to_file("res://scenes/server/coast_server.tscn")
		start_server()
	elif not option("connect").is_empty():
		if not option("network-test").is_empty(): get_tree().change_scene_to_file("res://scenes/server/coop_probe.tscn")
		join(option("connect"),int(option("port",str(DEFAULT_PORT))),option("name","Invitado"),option("key"))

func start_server() -> void:
	var config := ConfigFile.new()
	var config_path := option("config",OS.get_executable_path().get_base_dir()+"/server.cfg")
	config.load(config_path)
	_port = int(option("port",str(config.get_value("server","port",DEFAULT_PORT))))
	room_key = option("key",str(config.get_value("server","room_key","")))
	if room_key.is_empty():
		push_error("Falta room_key en server.cfg o --key. No se inició el servidor.")
		get_tree().quit(2)
		return
	server_world = WORLD_DATA.new()
	if not server_world.load_world():
		push_error("No se pudo cargar la costa del servidor")
		get_tree().quit(3)
		return
	_state_path = option("state",str(config.get_value("server","state_file","user://coop_server_state.json")))
	if not _state_path.is_absolute_path() and not _state_path.begins_with("user://"):
		_state_path = config_path.get_base_dir().path_join(_state_path)
	_load_state()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(option("bind",str(config.get_value("server","bind","*"))))
	var error := peer.create_server(_port,16,3)
	if error != OK:
		push_error("No se pudo abrir UDP %d: %s" % [_port,error_string(error)])
		get_tree().quit(4)
		return
	multiplayer.multiplayer_peer = peer
	print("COOP_SERVER_READY port=",_port," protocol=UDP max_players=16 build=",server_world.build_id)
	_set_status("Servidor listo · UDP %d" % _port)

func join(address: String, port: int, display_name: String, key: String) -> void:
	leave()
	nickname = display_name.strip_edges().replace("\n","").replace("\r","").substr(0,24)
	if nickname.length() < 2 or address.strip_edges().is_empty() or port < 1 or port > 65535:
		_set_status("Escribe una dirección, un puerto válido y un nombre de al menos dos letras.")
		return
	room_key = key
	_port = port
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(),port,3)
	if error != OK:
		_set_status("No se pudo crear la conexión: "+error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	connecting = true
	_deadline = Time.get_ticks_msec()+12000
	_received_sequence = -1
	_set_status("Conectando a %s:%d…" % [address,port])

func _connected() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/network/coast_session_catalog.json"))
	_hello.rpc_id(1,PROTOCOL,str(catalog.get("build_id","")),nickname,room_key)
	_set_status("Conectado · verificando partida…")

@rpc("any_peer","call_remote","reliable",0)
func _hello(protocol: String, build: String, display_name: String, key: String) -> void:
	if not is_dedicated: return
	var id := multiplayer.get_remote_sender_id()
	if not _pending_peers.has(id) or players.has(id): return
	var clean := display_name.strip_edges().replace("\n","").replace("\r","").substr(0,24)
	var error := ""
	if protocol != PROTOCOL or build != server_world.build_id: error = "Usa la misma versión del juego que el servidor."
	elif key != room_key: error = "La clave de partida no coincide."
	elif clean.length() < 2: error = "El nombre es demasiado corto."
	for player: Dictionary in players.values():
		if str(player["name"]).to_lower() == clean.to_lower(): error = "Ese nombre ya está conectado. Usa otro."
	if not error.is_empty():
		_welcome.rpc_id(id,false,error,{}, {},Time.get_unix_time_from_system())
		return
	_pending_peers.erase(id)
	var profile: Dictionary = _profiles.get(clean.to_lower(),STARTER.duplicate(true))
	var slot := 0
	var used_slots := []
	for state: Dictionary in players.values(): used_slots.append(state["slot"])
	while slot in used_slots: slot += 1
	var spawn: Vector3 = server_world.spawn(slot)
	players[id] = {"id":id,"slot":slot,"name":clean,"position":spawn,"yaw":0.0,"animation":"idle","primary":"","secondary":"","inventory":profile.duplicate(true),"budget":2.0,"last_tick":Time.get_ticks_msec()}
	_welcome.rpc_id(id,true,"",_public_player(players[id]),resources,Time.get_unix_time_from_system())
	_send_snapshot()
	print("COOP_JOIN peer=",id," name=",clean," players=",players.size())

@rpc("authority","call_remote","reliable",0)
func _welcome(ok: bool, message: String, own: Dictionary, resource_state: Dictionary, server_time: float) -> void:
	if is_dedicated: return
	if not ok:
		_failed(message)
		return
	connecting = false
	active = true
	local_peer_id = int(own["id"])
	assigned_spawn = own["position"]
	server_offset = server_time-Time.get_unix_time_from_system()
	resources = resource_state.duplicate(true)
	GameManager.current_character = {"name":own["name"],"body_id":"strongman","current_sector":Vector2i(27,30),"position":assigned_spawn,"model_path":CharacterAnimationRetargeter.DEFAULT_SOURCE_PATH,"animation_source_path":CharacterAnimationRetargeter.DEFAULT_SOURCE_PATH,"visual_scale":1.0,"tutorial_intro_completed":true}
	GameManager.current_username = own["name"]
	GameManager.should_play_tutorial_intro = false
	GameManager.clear_equipment()
	NetworkManager.current_character_name = own["name"]
	NetworkManager.inventory_updated.emit(own["inventory"])
	_set_status("En línea · %s" % own["name"])
	if option("network-test").is_empty(): GameManager.change_scene(GameManager.WORLD_SCENE)

func bind_world(world: Node3D, local_player: Node3D) -> void:
	if not active: return
	_world = world
	_local_player = local_player
	_sync_avatars()
	for tree: Node in get_tree().get_nodes_in_group("harvestable_trees"):
		var id := str(tree.get("resource_id"))
		tree.call("apply_shared_resource_state",get_respawn_at(id))

func _process(delta: float) -> void:
	if connecting and Time.get_ticks_msec() > _deadline: _failed("Tiempo de conexión agotado. Revisa UDP %d y la IP del servidor." % _port)
	_elapsed += delta
	if is_dedicated:
		for id in _pending_peers.keys():
			if Time.get_ticks_msec()-int(_pending_peers[id]) > 12000:
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
				_pending_peers.erase(id)
		if _elapsed >= 0.05:
			_elapsed = 0
			_send_snapshot()
	elif active and is_instance_valid(_local_player) and _elapsed >= 0.05:
		_elapsed = 0
		var animation := "idle"
		var animator: AnimationPlayer = _local_player.get("character_animation_player")
		if animator != null: animation = String(animator.current_animation).trim_prefix("shared/")
		_pose.rpc_id(1,_local_player.global_position,float((_local_player.get("visual") as Node3D).rotation.y),animation)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _pose(position: Vector3, yaw: float, animation: String) -> void:
	if not is_dedicated: return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id): return
	var state: Dictionary = players[id]
	var now := Time.get_ticks_msec()
	var elapsed := maxf((now-int(state["last_tick"]))/1000.0,0)
	state["budget"] = minf(float(state["budget"])+elapsed*12.0,2.0)
	state["last_tick"] = now
	var previous: Vector3 = state["position"]
	var distance := Vector2(position.x-previous.x,position.z-previous.z).length()
	if not is_finite(yaw) or not server_world.valid_position(position) or distance > float(state["budget"]):
		_correct.rpc_id(id,previous)
		return
	state["budget"] -= distance
	state["position"] = position
	state["yaw"] = wrapf(yaw,-PI,PI)
	state["animation"] = animation if animation in ["idle","walk","run","jump","chop","swim_idle","swim_forward"] else "idle"

@rpc("authority","call_remote","unreliable_ordered",1)
func _correct(position: Vector3) -> void:
	if active and is_instance_valid(_local_player) and _local_player.global_position.distance_to(position) > 0.8:
		_local_player.global_position = position
		_local_player.set("velocity",Vector3.ZERO)

func _send_snapshot() -> void:
	if players.is_empty(): return
	_sequence += 1
	var snapshot := []
	for state: Dictionary in players.values(): snapshot.append(_public_player(state))
	for id in players: _snapshot.rpc_id(id,_sequence,snapshot)

func _public_player(state: Dictionary) -> Dictionary:
	var public := {}
	for key in ["id","name","position","yaw","animation","primary","secondary","inventory"]: public[key] = state[key]
	return public

@rpc("authority","call_remote","unreliable_ordered",2)
func _snapshot(sequence: int, states: Array) -> void:
	if is_dedicated or sequence <= _received_sequence: return
	_received_sequence = sequence
	players.clear()
	for state: Dictionary in states: players[int(state["id"])] = state
	_sync_avatars()
	players_changed.emit()

func _sync_avatars() -> void:
	if not active or not is_instance_valid(_world): return
	for id in avatars.keys():
		if not players.has(id) or not is_instance_valid(avatars[id]):
			if is_instance_valid(avatars[id]): avatars[id].queue_free()
			avatars.erase(id)
	for id in players:
		if id == local_peer_id: continue
		if not avatars.has(id):
			var actor := AVATAR_SCRIPT.new()
			actor.name = "RemotePlayer_%d" % id
			actor.display_name = players[id]["name"]
			_world.add_child(actor)
			avatars[id] = actor
		avatars[id].call("apply_snapshot",players[id])

func send_equipment(primary: String, secondary: String) -> void:
	if active: _equipment.rpc_id(1,primary,secondary)

@rpc("any_peer","call_remote","reliable",0)
func _equipment(primary: String, secondary: String) -> void:
	if not is_dedicated: return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id): return
	var state: Dictionary = players[id]
	for item in [primary,secondary]:
		if not item.is_empty() and int(state["inventory"].get(item,0)) < 1: return
	if not primary.is_empty() and not ItemCatalog.can_equip_in_slot(primary,"primary"): return
	if not secondary.is_empty() and not ItemCatalog.can_equip_in_slot(secondary,"secondary"): return
	if ItemCatalog.get_hand_usage(primary) == "two_hand" and not secondary.is_empty(): return
	state["primary"] = primary
	state["secondary"] = secondary

func begin_harvest(id: String) -> void:
	if active: _begin_harvest.rpc_id(1,id)

func cancel_harvest(id: String) -> void:
	if active: _cancel_harvest.rpc_id(1,id)

@rpc("any_peer","call_remote","reliable",0)
func _begin_harvest(resource_id: String) -> void:
	if not is_dedicated: return
	var peer := multiplayer.get_remote_sender_id()
	if not _can_harvest(peer,resource_id):
		_harvest_reply.rpc_id(peer,resource_id,false,"Acércate con el hacha equipada; el árbol puede estar ocupado.",resources.get(resource_id,0.0),{})
		return
	_claims[resource_id] = {"peer":peer,"began":Time.get_ticks_msec()}

@rpc("any_peer","call_remote","reliable",0)
func _cancel_harvest(resource_id: String) -> void:
	if not is_dedicated: return
	if _claims.has(resource_id) and int(_claims[resource_id]["peer"]) == multiplayer.get_remote_sender_id(): _claims.erase(resource_id)

func request_harvest(id: String) -> Dictionary:
	_finish_harvest.rpc_id(1,id)
	return {"success":true,"pending":true,"respawn_at":Time.get_unix_time_from_system()+540}

@rpc("any_peer","call_remote","reliable",0)
func _finish_harvest(resource_id: String) -> void:
	if not is_dedicated: return
	var peer := multiplayer.get_remote_sender_id()
	var valid := _can_harvest(peer,resource_id) and _claims.has(resource_id)
	if valid: valid = int(_claims[resource_id]["peer"]) == peer and Time.get_ticks_msec()-int(_claims[resource_id]["began"]) >= 6650
	if not valid:
		_harvest_reply.rpc_id(peer,resource_id,false,"El servidor no confirmó la tala.",resources.get(resource_id,0.0),{})
		return
	_claims.erase(resource_id)
	var tree: Dictionary = server_world.trees[resource_id]
	var inventory: Dictionary = players[peer]["inventory"]
	inventory["Madera"] = int(inventory.get("Madera",0))+int(tree["amount"])
	resources[resource_id] = Time.get_unix_time_from_system()+float(tree["respawn_seconds"])
	_save_profile(players[peer])
	_save_state()
	_harvest_reply.rpc_id(peer,resource_id,true,"",resources[resource_id],inventory)
	for id in players: _resource_state.rpc_id(id,resource_id,resources[resource_id])
	print("COOP_HARVEST peer=",peer," resource=",resource_id," wood=",inventory["Madera"])

func _can_harvest(peer: int, id: String) -> bool:
	if not players.has(peer) or not server_world.trees.has(id): return false
	if float(resources.get(id,0)) > Time.get_unix_time_from_system(): return false
	if _claims.has(id) and int(_claims[id]["peer"]) != peer and Time.get_ticks_msec()-int(_claims[id]["began"]) < 15000: return false
	var state: Dictionary = players[peer]
	return state["primary"] == "Hacha de leñador" and (state["position"] as Vector3).distance_to(server_world.tree_position(id)+Vector3.UP*0.78) <= 4.0

@rpc("authority","call_remote","reliable",0)
func _harvest_reply(id: String, ok: bool, message: String, deadline: float, inventory: Dictionary) -> void:
	if is_dedicated: return
	resources[id] = deadline
	resource_changed.emit(id,get_respawn_at(id))
	if ok: NetworkManager.inventory_updated.emit(inventory)
	else:
		_set_status(message)
		if is_instance_valid(_local_player): _local_player.call("_cancel_timed_interaction")

@rpc("authority","call_remote","reliable",0)
func _resource_state(id: String, deadline: float) -> void:
	resources[id] = deadline
	resource_changed.emit(id,get_respawn_at(id))

func get_respawn_at(id: String) -> float:
	var deadline := float(resources.get(id,0))
	return deadline-server_offset if deadline > 0 else 0.0

func _peer_arrived(id: int) -> void:
	if is_dedicated:
		_pending_peers[id] = Time.get_ticks_msec()
		print("COOP_PEER_CONNECTED ",id)

func _peer_left(id: int) -> void:
	if not is_dedicated: return
	_pending_peers.erase(id)
	if players.has(id): _save_profile(players[id])
	players.erase(id)
	for resource in _claims.keys():
		if int(_claims[resource]["peer"]) == id: _claims.erase(resource)
	_save_state()
	_send_snapshot()
	print("COOP_LEAVE peer=",id," players=",players.size())

func leave() -> void:
	active = false
	connecting = false
	for actor in avatars.values():
		if is_instance_valid(actor): actor.queue_free()
	avatars.clear()
	players.clear()
	resources.clear()
	_local_player = null
	_world = null
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer: (multiplayer.multiplayer_peer as ENetMultiplayerPeer).close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _failed(message: String) -> void:
	var was_playing := active
	leave()
	_set_status(message)
	if was_playing:
		GameManager.current_character.clear()
		GameManager.player_inventory.clear()
		GameManager.clear_equipment()
		NetworkManager.current_character_name = ""
		get_tree().paused = false
		GameManager.call_deferred("change_scene",GameManager.MAIN_MENU_SCENE)

func _set_status(message: String) -> void:
	status = message
	print("COOP_STATUS ",message)
	status_changed.emit(message)

func _save_profile(state: Dictionary) -> void:
	_profiles[str(state["name"]).to_lower()] = state["inventory"].duplicate(true)

func _load_state() -> void:
	if not FileAccess.file_exists(_state_path): return
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(_state_path))
	if state is Dictionary:
		_profiles = state.get("profiles",{})
		resources = state.get("resources",{})

func _save_state() -> void:
	if _state_path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_state_path).get_base_dir())
	var file := FileAccess.open(_state_path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"profiles":_profiles,"resources":resources}))
	else: push_error("No se pudo guardar el estado del servidor: "+error_string(FileAccess.get_open_error()))
