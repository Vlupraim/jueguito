extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	var ready_for_test := false
	for _frame in range(120):
		await get_tree().process_frame
		var candidate := world.get("player") as CharacterBody3D
		if candidate != null \
		and candidate.global_position.x > 250.0 \
		and world.get("local_minimap_texture") != null:
			ready_for_test = true
			break
	if not ready_for_test:
		_fail("La escena no termino de colocar al jugador y cargar el mapa local")
		return

	if world.get("debug_label") != null:
		_fail("El texto tecnico sigue visible por defecto")
		return
	if world.get("local_minimap") == null or world.get("expanded_local_minimap") == null:
		_fail("No se crearon las vistas pequena y ampliada del mapa local")
		return
	if world.get_node_or_null("GameplayHUD/Screen/Minimap") != null:
		_fail("El HUD sigue creando el segundo minimapa duplicado")
		return
	var world_map := world.get_node_or_null("MinimapaUI/MapaMundial") as ColorRect
	if world_map == null or world_map.visible:
		_fail("El mapa mundial debe existir y comenzar cerrado")
		return
	if world.get("local_minimap_texture") == null:
		_fail("El minimapa local no genero la carta medieval")
		return
	if world.get("expanded_map_texture") == null:
		_fail("Tab no recibio la carta ilustrada")
		return
	if world.has_method("_toggle_expanded_map_view"):
		_fail("La antigua vista de terreno 3D sigue expuesta")
		return
	var minimap_module := world.get("minimap_hud_module") as Control
	var hud_tools := world.find_child("ControlesMapaLocal", true, false) as VBoxContainer
	if hud_tools == null:
		_fail("Faltan las herramientas junto al minimapa")
		return
	if minimap_module != null:
		minimap_module.call("_place_from_normalized", Vector2(1.0, 0.0), true)
	var viewport_rect := world.get_viewport().get_visible_rect()
	if minimap_module == null or not viewport_rect.encloses(minimap_module.get_global_rect()):
		_fail("El minimapa editable quedo fuera de la pantalla")
		return
	var action_bar := world.find_child("ActionBar", true, false) as Control
	if action_bar != null:
		action_bar.call("_place_from_normalized", Vector2(0.5, 1.0), true)
	if action_bar == null or action_bar.get_global_rect().intersects(minimap_module.get_global_rect()):
		_fail("La barra de acciones invade el modulo del minimapa")
		return
	if (hud_tools.get_child(0) as Control).size.y > 48.0:
		_fail("Los controles compactos del minimapa heredaron un boton sobredimensionado")
		return
	for tool_name in [
		"AcercarMapaLocal",
		"AlejarMapaLocal",
		"ExpandirMapaLocal",
	]:
		if hud_tools.get_node_or_null(tool_name) == null:
			_fail("Falta la herramienta HUD %s" % tool_name)
			return
	if world.find_child("NavegacionMapa", true, false) != null:
		_fail("El minimapa compacto conserva los botones redundantes Sector y Mundo")
		return
	var regional_tools := world.find_child("HerramientasMapaRegional", true, false) as HBoxContainer
	if regional_tools == null:
		_fail("Falta la barra completa de herramientas del mapa regional")
		return
	for tool_name in ["Centrar", "Ping", "Ataque", "Defensa"]:
		if regional_tools.get_node_or_null(tool_name) == null:
			_fail("Falta la herramienta regional %s" % tool_name)
			return
	var world_tools := world.find_child("HerramientasMapaMundial", true, false) as HBoxContainer
	if world_tools == null \
	or world_tools.get_node_or_null("Regionactual") == null \
	or world_tools.get_node_or_null("Completo") == null:
		_fail("El atlas no contiene sus controles de navegacion funcionales")
		return
	if world_tools.get_node_or_null("Buscar") != null or world_tools.get_node_or_null("Filtros") != null:
		_fail("El atlas conserva controles de relleno sin funcionalidad")
		return
	var backdrop := world.get("expanded_map_backdrop") as ColorRect
	if backdrop == null or backdrop.visible:
		_fail("El mapa local ampliado debe comenzar cerrado")
		return
	var regional_panel := world.find_child("PanelMapaLocal", true, false) as PanelContainer
	var atlas_panel := world.find_child("PanelAtlasMundial", true, false) as PanelContainer
	if regional_panel == null or atlas_panel == null:
		_fail("Las vistas regional y mundial no son menus completos")
		return
	if world.find_child("CarcasaMapaRegional", true, false) == null \
	or world.find_child("CarcasaAtlasMundial", true, false) == null:
		_fail("El mapa regional y el atlas no recibieron sus carcasas cartograficas diferenciadas")
		return
	if world.find_child("MarcoCartograficoPantalla", true, false) != null:
		_fail("La carcasa unificada conserva uno de los marcos fragmentados anteriores")
		return
	var atlas_card := world.find_child("FichaTerritorioAtlas", true, false) as PanelContainer
	if atlas_card == null or atlas_card.visible:
		_fail("La ficha superpuesta del atlas debe existir y comenzar oculta hasta seleccionar un territorio")
		return
	world.call("_toggle_local_map")
	if not backdrop.visible or not bool(world.get("local_map_expanded")):
		_fail("Tab no abrio el mapa local ampliado")
		return

	var player := world.get("player") as CharacterBody3D
	if bool(player.get("gameplay_input_enabled")):
		_fail("El jugador conserva movimiento mientras consulta el mapa local")
		return
	world.call("_change_expanded_map_zoom", 0.5)
	if float(world.get("expanded_map_zoom")) <= 1.0:
		_fail("El mapa ampliado no responde al zoom")
		return
	world.call("_change_expanded_map_zoom", -10.0)
	if not is_equal_approx(float(world.get("expanded_map_zoom")), 1.0):
		_fail("Tab permite alejarse mas que el encuadre completo")
		return
	world.call("_change_local_minimap_zoom", -10.0)
	if not is_equal_approx(float(world.get("local_minimap_zoom")), 1.0):
		_fail("El minimapa permite alejarse mas que su vista por defecto")
		return
	world.call("_change_local_minimap_zoom", 0.15)
	if float(world.get("local_minimap_zoom")) <= 1.0:
		_fail("Los controles del minimapa no permiten acercarse")
		return
	world.call("_set_map_ping_mode", 2)
	if int(world.get("map_ping_mode")) != 2:
		_fail("Los modos de ping no cambian entre normal, ataque y defensa")
		return
	world.call("_change_local_minimap_zoom", -10.0)
	world.call("_toggle_world_map")
	if not world_map.visible or world.get("world_map_canvas") == null:
		_fail("El boton Mundo no abre el atlas general")
		return
	if int(world.get("world_map_columns")) != 67 \
	or int(world.get("world_map_rows")) != 38 \
	or not is_equal_approx(float(world.get("world_map_sector_pixels")), 25.0):
		_fail("El juego no cargo la misma cuadricula 5 km del creador MMO")
		return
	world.call("_center_world_map_on_current_sector")
	var world_view_size: Vector2 = world.call("_world_map_view_size")
	var world_texture_rect: Rect2 = world.call("_world_map_texture_rect", world_view_size)
	var current_sector: Vector2i = world.get("current_sector")
	var tutorial_art_sector: Vector2i = world.call("_world_map_art_sector_coord", current_sector)
	if current_sector == Vector2i(27, 30) and tutorial_art_sector != Vector2i(26, 30):
		_fail("El atlas no corrigio el anclaje visual del tutorial sobre la costa")
		return
	var current_sector_rect: Rect2 = world.call(
		"_world_map_sector_rect",
		world_texture_rect,
		current_sector
	)
	var current_sector_center: Vector2 = world.call(
		"_world_map_sector_center",
		world_texture_rect,
		current_sector
	)
	world.call("_update_world_map_hover", current_sector_center)
	if world.get("world_map_hovered_sector") != current_sector:
		_fail("La correccion cartografica no conserva la coordenada logica del tutorial")
		return
	var hover_label := world.get("world_map_hover_label") as Label
	if hover_label == null or not hover_label.text.contains("Grado"):
		_fail("El atlas no recupero los datos reales del territorio bajo el puntero")
		return
	world.call("_select_world_map_sector_at", current_sector_center)
	var info_card := world.get("world_map_info_card") as PanelContainer
	var info_label := world.get("world_map_info_label") as Label
	if info_card == null or not info_card.visible \
	or info_label == null or not info_label.text.contains("Recursos"):
		_fail("Seleccionar un territorio no abrio su ficha cartografica superpuesta")
		return
	var visible_sector_columns := world_view_size.x / current_sector_rect.size.x
	if visible_sector_columns < 10.5 or visible_sector_columns > 11.5:
		_fail("Region actual no reproduce la ventana de 11 cuadrantes del MMO")
		return
	world.call("_reset_world_map_view")
	if not is_equal_approx(float(world.get("world_map_zoom")), 1.0):
		_fail("Completo no restablece el atlas mundial")
		return
	if info_card.visible:
		_fail("Completo no retiro la ficha del territorio seleccionado")
		return
	world.call("_toggle_world_map")
	if world_map.visible or backdrop.visible or not bool(player.get("gameplay_input_enabled")):
		_fail("Cerrar el atlas general no devolvio directamente el control al juego")
		return
	var minimap_size := Vector2(250.0, 190.0)
	var marker_position: Vector2 = world.call(
		"_world_position_to_local_map",
		player.global_position,
		minimap_size,
		false
	)
	var ocean := world.get("ocean_water") as OceanWater
	print(
		"MINIMAP_DEBUG player=", player.global_position,
		" bounds=", ocean.sector_bounds,
		" marker=", marker_position
	)
	if marker_position.x < 0.0 or marker_position.x > minimap_size.x:
		_fail("El marcador X del jugador quedo fuera del minimapa")
		return
	if marker_position.y < 0.0 or marker_position.y > minimap_size.y:
		_fail("El marcador Z del jugador quedo fuera del minimapa")
		return
	var tilt := float(world.get("local_minimap_tilt"))
	var expected_marker := Vector2(137.0312, 95.0 - 3.6094 * tilt)
	if marker_position.distance_to(expected_marker) > 4.0:
		_fail("El marcador no coincide con el spawn local esperado")
		return
	var diamond_offset := marker_position - minimap_size * 0.5
	var diamond_distance := absf(diamond_offset.x) / 112.0 + absf(diamond_offset.y) / (88.0 * tilt)
	if diamond_distance > 1.05:
		_fail("El marcador quedo fuera de la carta inclinada")
		return
	var flat_basis: Dictionary = world.call(
		"_world_marker_basis",
		player.global_position,
		Vector2(0.0, -1.0),
		Vector2(760.0, 430.0),
		true
	)
	if absf((flat_basis.forward as Vector2).length() - 1.0) > 0.01 \
	or absf((flat_basis.side as Vector2).length() - 1.0) > 0.01:
		_fail("El puntero de Tab sigue deformado por la perspectiva del HUD")
		return

	var player_controller_source := FileAccess.get_file_as_string(
		"res://scripts/characters/player/player_controller.gd"
	)
	var removed_movement_key_pattern := RegEx.new()
	removed_movement_key_pattern.compile(
		"\\b(KEY_W|KEY_A|KEY_S|KEY_D|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT)\\b"
	)
	var removed_key_match := removed_movement_key_pattern.search(player_controller_source)
	if removed_key_match != null:
		_fail("El movimiento del personaje todavia responde a %s" % removed_key_match.get_string())
		return

	var camera_pivot := player.get_node_or_null("CameraPivot") as Node3D
	if camera_pivot == null:
		_fail("El jugador no expuso el pivote de la camara tactica")
		return
	world.call("_pan_camera", Vector2(10000.0, 10000.0))
	var pan_distance := Vector2(camera_pivot.position.x, camera_pivot.position.z).length()
	if pan_distance < 29.9 or pan_distance > 30.01:
		_fail("El desplazamiento de camara no respeto el limite de 30 metros")
		return
	world.call("_request_camera_recenter")
	for _step in range(120):
		world.call("_update_camera_recenter", 1.0 / 60.0)
	var recentered_distance := Vector2(camera_pivot.position.x, camera_pivot.position.z).length()
	if recentered_distance > 0.02:
		_fail("F/doble clic no recentro suavemente la camara")
		return
	camera_pivot.position = Vector3(10.0, 0.0, 0.0)
	player.velocity = Vector3.RIGHT
	world.call("_update_camera_recenter", 1.0 / 60.0)
	if camera_pivot.position.x >= 10.0 or not bool(world.get("camera_recenter_requested")):
		_fail("La camara no comenzo a volver cuando el personaje se movio")
		return
	player.velocity = Vector3.ZERO

	var expected_yaws := [135.0, 225.0, 315.0, 45.0]
	for expected_yaw: float in expected_yaws:
		world.call("_cycle_camera_quadrant")
		var rotation_tween := world.get("camera_rotation_tween") as Tween
		if rotation_tween != null and rotation_tween.is_valid():
			await rotation_tween.finished
		var normalized_yaw := fposmod(float(world.get("cam_yaw")), 360.0)
		if not is_equal_approx(normalized_yaw, expected_yaw):
			_fail("La camara quedo en %.2f y no completo el cuadrante %.0f" % [
				normalized_yaw,
				expected_yaw,
			])
			return

	print(
		"TERRAIN3D_MINIMAP_CAMERA_OK marker=", marker_position.round(),
		" quadrants=4 pan_limit=30 recenter=true wasd=false regional_tab=true world_grid=67x38 region_window=11 hud_tools=2 map_tabs=2 duplicate_minimap=false terrain_view=false debug_hidden=true"
	)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
