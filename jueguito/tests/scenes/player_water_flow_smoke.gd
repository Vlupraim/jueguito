extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")

var water_mode := "wading"


func _ready() -> void:
	call_deferred("_run")


func get_player_ground_info(requested_position: Vector3) -> Dictionary:
	var terrain_height := 1.5
	if water_mode == "swimming" or water_mode == "open_water":
		terrain_height = -3.0
	return {
		"walkable": true,
		"position": Vector3(requested_position.x, terrain_height, requested_position.z),
		"water": {
			"in_water": water_mode != "dry",
			"state": water_mode,
			"water_level": 2.0,
			"depth": maxf(2.0 - terrain_height, 0.0),
		},
	}


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame

	player.call("_move_on_generator_ground", Vector3.RIGHT, 4.0, 1.0)
	if String(player.get("water_state")) != "wading":
		_fail("El jugador no entro al estado de vadeo")
		return
	if not is_equal_approx(player.global_position.x, 4.0 * float(player.get("wade_speed_multiplier"))):
		_fail("Vadear no redujo la velocidad")
		return

	water_mode = "swimming"
	player.call("_move_on_generator_ground", Vector3.RIGHT, 9.0, 1.0)
	if String(player.get("water_state")) != "swimming":
		_fail("El jugador no entro al estado de natacion")
		return
	if float(player.get("swimming_body_offset")) < 0.60:
		_fail("La linea de flotacion deja demasiado torso fuera del agua")
		return
	if not is_equal_approx(player.global_position.y, 2.0 - float(player.get("swimming_body_offset"))):
		_fail("El nadador no se mantuvo sobre el nivel del agua")
		return
	var safe_swim_position := player.global_position

	water_mode = "open_water"
	player.call("_move_on_generator_ground", Vector3.RIGHT, 9.0, 1.0)
	if String(player.get("water_state")) != "open_water":
		_fail("El jugador no detecto el limite de mar abierto")
		return
	if not player.global_position.is_equal_approx(safe_swim_position):
		_fail("El personaje avanzo por mar abierto sin embarcacion")
		return

	print("PLAYER_WATER_FLOW_SMOKE_OK wading=true swimming=true open_water_blocked=true")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
