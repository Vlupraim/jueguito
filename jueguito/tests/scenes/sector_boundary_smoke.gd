extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	for _frame in range(120):
		await get_tree().process_frame
		if world.get("player") != null and world.get("ocean_water") != null:
			break
	var ocean := world.get("ocean_water") as OceanWater
	if ocean == null:
		_fail("No se cargaron los limites del sector")
		return
	var visual_bounds := ocean.sector_bounds
	var bounds := world.call("_sector_walkable_bounds") as Rect2
	var center := bounds.get_center()
	if not is_equal_approx(bounds.position.x - visual_bounds.position.x, 48.0) \
	or not is_equal_approx(bounds.position.y - visual_bounds.position.y, 48.0) \
	or not is_equal_approx(visual_bounds.end.x - bounds.end.x, 48.0) \
	or not is_equal_approx(visual_bounds.end.y - bounds.end.y, 48.0):
		_fail("La cinta visual no conserva 48 metros alrededor del area jugable")
		return
	if not bool(world.call("_is_position_inside_sector_or_portal", center)):
		_fail("El centro del chunk fue bloqueado")
		return
	for outside_point in [
		Vector2(bounds.position.x - 0.1, center.y),
		Vector2(bounds.end.x + 0.1, center.y),
		Vector2(center.x, bounds.position.y - 0.1),
		Vector2(center.x, bounds.end.y + 0.1),
	]:
		if bool(world.call("_is_position_inside_sector_or_portal", outside_point)):
			_fail("Un borde cerrado permitio salir del chunk")
			return
	# El terreno de la cinta sigue visible, pero no es caminable.
	var belt_point := Vector2(bounds.end.x + 1.0, center.y)
	if not visual_bounds.has_point(belt_point):
		_fail("El punto de prueba no quedo dentro de la cinta visual")
		return
	var blocked_info: Dictionary = world.call(
		"get_player_ground_info",
		Vector3(belt_point.x, 0.0, belt_point.y)
	)
	if bool(blocked_info.get("walkable", true)) or String(blocked_info.get("reason", "")) != "limite_sector":
		_fail("El movimiento no reconoce el limite invisible")
		return
	var player := world.get("player") as CharacterBody3D
	player.global_position = Vector3(bounds.end.x - 0.5, 5.0, center.y)
	player.set("last_safe_position", player.global_position)
	player.set("has_target", true)
	player.call("_move_on_generator_ground", Vector3.RIGHT, 9.1, 1.0)
	if bool(player.get("has_target")) or player.global_position.x >= bounds.end.x:
		_fail("El personaje siguio intentando caminar contra el muro invisible")
		return

	world.call("register_sector_portal_opening", "E", center.y, 18.0, Vector2i(28, 30), "este_tutorial")
	var portal_point := belt_point
	if not bool(world.call("_is_position_inside_sector_or_portal", portal_point)):
		_fail("Una abertura de portal registrada sigue cerrada")
		return
	if bool(world.call("_is_position_inside_sector_or_portal", Vector2(bounds.end.x + 3.1, center.y))):
		_fail("El portal permitio atravesar demasiado terreno de la cinta visual")
		return
	if int((world.get("sector_portal_openings") as Array).size()) != 1:
		_fail("La abertura no quedo registrada para el mapa local")
		return
	world.call("clear_sector_portal_openings")
	if bool(world.call("_is_position_inside_sector_or_portal", portal_point)):
		_fail("El borde no se cerro al retirar el portal")
		return

	print(
		"SECTOR_BOUNDARY_OK playable=", bounds.size,
		" visual=", visual_bounds.size,
		" belt=48 closed=true portal_extension=true"
	)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
