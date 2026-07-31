extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	for _frame in range(6):
		await get_tree().physics_frame

	var sector_content := world.get_node_or_null("SectorContent")
	var deck_surface := sector_content.find_child("ShipDeckSurface", true, false) as Node3D if sector_content != null else null
	var ramp_surface := sector_content.find_child("BoardingRampSurface", true, false) as Node3D if sector_content != null else null
	var player := world.get("player") as CharacterBody3D
	if deck_surface == null or ramp_surface == null or player == null:
		_fail("No se cargaron las superficies caminables del barco")
		return

	var deck_sample := deck_surface.to_global(Vector3(0.0, 0.34, 0.0))
	var ramp_sample := ramp_surface.to_global(Vector3(0.0, 0.0, -2.4))
	var ground_sample := Vector3(273.0, 7.0, 218.0)
	var deck_info: Dictionary = world.call("get_player_ground_info", deck_sample)
	var ramp_info: Dictionary = world.call("get_player_ground_info", ramp_sample)
	var ground_info: Dictionary = world.call("get_player_ground_info", ground_sample)

	if String(deck_info.get("surface_role", "")) != "deck":
		_fail("La cubierta no se reconoce como superficie caminable")
		return
	if String(ramp_info.get("surface_role", "")) != "ramp":
		_fail("El acceso no se reconoce como rampa caminable")
		return
	if not String(ground_info.get("platform_id", "")).is_empty():
		_fail("El spawn terrestre quedo clasificado como parte del barco")
		return

	if bool(player.call("_is_platform_transition_allowed", ground_info, deck_info)):
		_fail("Se puede saltar directamente desde tierra a la cubierta")
		return
	if not bool(player.call("_is_platform_transition_allowed", ground_info, ramp_info)):
		_fail("La rampa no permite abordar desde tierra")
		return
	if not bool(player.call("_is_platform_transition_allowed", ramp_info, deck_info)):
		_fail("La rampa no conecta con la cubierta")
		return
	if bool(player.call("_is_platform_transition_allowed", deck_info, ground_info)):
		_fail("La cubierta permite caer por un borde sin usar la rampa")
		return

	print(
		"TUTORIAL_SHIP_WALKABILITY_OK deck_y=", float(deck_info["position"].y),
		" ramp_y=", float(ramp_info["position"].y),
		" spawn_dry=", String(ground_info.get("water", {}).get("state", ""))
	)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
