extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	var player: CharacterBody3D
	for _frame in range(120):
		await get_tree().process_frame
		player = world.get("player")
		if player != null and player.position.x > 250.0:
			break
	if player == null or player.position.x < 250.0:
		_fail("El mundo no termino de colocar al personaje")
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start := player.position
	Input.action_press("player_forward")
	for _tick in range(35):
		await get_tree().physics_frame
	Input.action_release("player_forward")
	if Vector2(player.position.x - start.x, player.position.z - start.z).length() < 0.8:
		_fail("WASD no desplaza al personaje en el Terrain3D real")
		return
	await get_tree().physics_frame
	var ground_y := player.position.y
	Input.action_press("player_jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("player_jump")
	var peak := player.position.y
	for _tick in range(65):
		await get_tree().physics_frame
		peak = maxf(peak, player.position.y)
	if peak < ground_y + 0.8 or absf(player.position.y - ground_y) > 0.1:
		_fail("El salto no aterriza en el Terrain3D real")
		return
	var hud: CanvasLayer = world.get("gameplay_hud")
	var camera_button := world.get("camera_lock_button") as Button
	if camera_button == null:
		_fail("El minimapa no tiene su control de cámara")
		return
	player.call("set_camera_locked", true)
	if not camera_button.button_pressed:
		_fail("El botón no refleja la cámara bloqueada")
		return
	var unlock := InputEventMouseButton.new()
	unlock.button_index = MOUSE_BUTTON_RIGHT
	unlock.pressed = true
	camera_button.gui_input.emit(unlock)
	if bool(player.get("camera_locked")) or camera_button.button_pressed:
		_fail("El clic derecho en el botón no libera la cámara")
		return
	camera_button.toggled.emit(true)
	if not bool(player.get("camera_locked")):
		_fail("El control del minimapa no vuelve a bloquear la cámara")
		return
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	var before_orbit := player.position
	var pivot := player.get_node("CameraPivot") as Node3D
	var yaw_before := pivot.rotation.y
	player.call("_unhandled_input", right_click)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(80, -20)
	player.call("_unhandled_input", drag)
	if is_equal_approx(pivot.rotation.y, yaw_before) or not player.position.is_equal_approx(before_orbit):
		_fail("Arrastrar con clic derecho no orbita o mueve al personaje")
		return
	hud.call("open_inventory")
	if bool(player.get("gameplay_input_enabled")) or bool(player.get("_orbiting")):
		_fail("El inventario no bloquea los controles nuevos")
		return
	hud.call("close_inventory")
	hud.call("open_pause_menu")
	if bool(player.get("gameplay_input_enabled")):
		_fail("La pausa no bloquea los controles nuevos")
		return
	hud.call("close_pause_menu")
	if not bool(player.get("gameplay_input_enabled")):
		_fail("Continuar no devuelve el control al jugador")
		return
	player.call("recenter_camera")
	hud.call("reset_hud_layout")
	world.call("_reset_minimap_hud_layout")
	var minimap: Control = world.get("minimap_hud_module")
	var stamina := hud.find_child("StaminaModule", true, false) as Control
	if minimap.get_parent() != stamina.get_parent() or not is_equal_approx(minimap.scale.x, 1.2):
		_fail("El minimapa no comparte escala base y orden con los modulos del HUD")
		return
	hud.call("set_hud_edit_mode", true)
	if not bool(minimap.get("edit_mode")):
		_fail("El minimapa no participa en la edicion comun")
		return
	minimap.call("bring_to_front")
	stamina.call("bring_to_front")
	if stamina.z_index <= minimap.z_index or stamina.get_index() <= minimap.get_index():
		_fail("La estamina no puede superponerse al minimapa")
		return
	hud.call("set_hud_edit_mode", false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/player_camera_preview.png")
	print("PLAYER_CONTROLS_WORLD_SMOKE_OK distance=", player.position.distance_to(start), " jump_height=", peak - ground_y)
	get_tree().quit(0)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error(message)
	get_tree().quit(1)
