extends Node3D

const OCEAN_SCENE := preload("res://scenes/world/water/ocean_water.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var ocean := OCEAN_SCENE.instantiate() as OceanWater
	add_child(ocean)
	await get_tree().process_frame

	if not ocean.configure_for_sector(Vector2i(27, 30)):
		_fail("El sector inicial no genero agua")
		return
	if ocean.water_cell_count <= 0 or ocean.shoreline_cell_count <= 0:
		_fail("La malla no contiene agua y costa diferenciadas")
		return
	if ocean.water_collision_shape_count <= 0:
		_fail("El oceano no creo su Area3D detectable")
		return
	var water_surface := ocean.find_child("WaterSurface", true, false) as MeshInstance3D
	if water_surface == null or water_surface.mesh == null:
		_fail("La superficie visual del oceano esta vacia")
		return
	var water_info := ocean.get_water_info(Vector3(256.0, 0.0, 12.0), -4.0)
	var dry_above_sea := ocean.get_water_info(Vector3(256.0, 0.0, 12.0), 2.2)
	var wading_limit := ocean.get_water_info(Vector3(256.0, 0.0, 12.0), 0.8)
	var land_info := ocean.get_water_info(Vector3(256.0, 0.0, 300.0), 5.0)
	if not bool(water_info.get("in_water", false)):
		_fail("La zona azul del mapa no se reconoce como agua")
		return
	if bool(land_info.get("in_water", false)):
		_fail("La zona terrestre del mapa se clasifico como agua")
		return
	if bool(dry_above_sea.get("in_water", false)):
		_fail("El terreno por encima del mar activo la logica de agua")
		return
	if String(wading_limit.get("state", "")) != "wading":
		_fail("Los primeros 1.20 metros no permanecen caminables")
		return

	print(
		"OCEAN_WATER_SMOKE_OK cells=", ocean.water_cell_count,
		" shoreline=", ocean.shoreline_cell_count,
		" colliders=", ocean.water_collision_shape_count
	)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
