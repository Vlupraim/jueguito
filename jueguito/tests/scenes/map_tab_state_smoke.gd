extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var regional := world.get("expanded_map_backdrop") as ColorRect
	var atlas := world.get("world_map_backdrop") as ColorRect
	if regional == null or atlas == null:
		_fail("No se crearon las dos vistas cartograficas")
		return
	var regional_surface := world.get("regional_map_surface") as Control
	if regional_surface == null or not regional_surface.visible:
		_fail("Tab no preparo la carta regional ilustrada del sector actual")
		return
	if world.get("world_map_surface") == null:
		_fail("M no preparo la superficie ilustrada con falsa perspectiva")
		return
	if CursorManager.current_mode != CursorManager.POINTING_HAND:
		_fail("El terreno no activo la mano como puntero de juego")
		return

	world.call("_open_regional_map")
	if not regional.visible or atlas.visible:
		_fail("Sector no se abrio como vista exclusiva")
		return
	world.call("_toggle_world_map")
	if regional.visible or not atlas.visible:
		_fail("Mundo quedo superpuesto sobre Sector")
		return
	world.call("_toggle_world_map")
	var player := world.get("player") as CharacterBody3D
	if regional.visible or atlas.visible or bool(world.get("local_map_expanded")):
		_fail("Cerrar Mundo dejo otra pestaña cartografica abierta")
		return
	if player != null and not bool(player.get("gameplay_input_enabled")):
		_fail("Cerrar Mundo no devolvio el control al personaje")
		return

	print("MAP_TAB_STATE_SMOKE_OK")
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
