extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")

class TestInteractable extends Node3D:
	var canceled := false
	func can_interact(_player: Node) -> bool:
		return true
	func begin_interaction(_player: Node) -> bool:
		return true
	func cancel_interaction(_player: Node) -> void:
		canceled = true
	func get_interaction_duration() -> float:
		return 5.0


func get_player_ground_info(point: Vector3) -> Dictionary:
	return {
		"walkable": absf(point.x) < 20.0 and absf(point.z) < 20.0,
		"position": Vector3(point.x, 0.0, point.z),
		"water": {"in_water": false, "state": "dry"},
	}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.position.y = 0.78
	add_child(player)
	player.call("set_camera_locked", false)
	player.set_physics_process(false)
	player.get_node("CameraPivot").rotation = Vector3.ZERO
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.call("bind_player", player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_press("player_forward")
	player.call("_physics_process", 0.2)
	Input.action_release("player_forward")
	if player.position.z > -0.4:
		_fail("W no mueve hacia delante respecto de la camara")
		return
	var stopped := player.position
	player.call("_physics_process", 0.2)
	if not player.position.is_equal_approx(stopped):
		_fail("Soltar WASD conserva un destino remoto")
		return
	player.get_node("CameraPivot").rotation.y = PI / 2.0
	Input.action_press("player_forward")
	player.call("_physics_process", 0.2)
	Input.action_release("player_forward")
	if player.position.x > -0.4:
		_fail("W no sigue el giro de camara")
		return
	player.position = Vector3(0, 0.78, 0)
	player.get_node("CameraPivot").rotation = Vector3.ZERO
	player.call("set_camera_locked", true)
	player.get_node("Visual").rotation.y = 0.0
	Input.action_press("player_right")
	for _tick in range(120):
		player.call("_physics_process", 1.0 / 60.0)
		player.call("_process", 1.0 / 60.0)
	Input.action_release("player_right")
	if absf(angle_difference(-PI / 2.0, player.get_node("Visual").rotation.y)) > 0.01:
		_fail("Mantener D no conserva el rumbo del giro inicial")
		return
	if absf(angle_difference(-PI / 2.0, player.get_node("CameraPivot").rotation.y)) > 0.02:
		_fail("La cámara no alcanza suavemente al personaje")
		return
	var expected_forward: Vector3 = player.get_node("CameraPivot").global_basis * Vector3.FORWARD
	Input.action_press("player_forward")
	var locked_direction: Vector3 = player.call("_movement_input_direction")
	Input.action_release("player_forward")
	if locked_direction.distance_to(expected_forward) > 0.01:
		_fail("Una nueva dirección no usa el frente visible de la cámara")
		return
	player.call("set_camera_locked", false)
	player.position = Vector3(0, 0.78, 0)
	Input.action_press("player_jump")
	await get_tree().physics_frame
	player.call("_physics_process", 1.0 / 60.0)
	Input.action_release("player_jump")
	await get_tree().physics_frame
	if player.velocity.y <= 0.0 or bool(player.call("try_jump")):
		_fail("Espacio no inicia el salto o permite doble salto")
		return
	var jump_duration: float = player.call("get_character_action_duration", &"jump")
	var full_duration: float = player.call("get_character_action_duration", &"basic_jump")
	if absf(jump_duration - 1.05) > 0.01 or full_duration < 5.0 \
	or absf(float(player.get("character_action_speed")) - 2.1) > 0.01:
		_fail("El gesto Basic_Jump no se recortó y sincronizó sin modificar el clip original")
		return
	var peak := player.position.y
	for _tick in range(70):
		player.call("_physics_process", 1.0 / 60.0)
		peak = maxf(peak, player.position.y)
	if peak < 1.8 or absf(player.position.y - 0.78) > 0.02:
		_fail("El salto no se eleva y aterriza sobre el terreno")
		return
	Input.action_press("player_sprint")
	Input.action_press("player_forward")
	for _tick in range(900):
		player.call("_physics_process", 1.0 / 60.0)
	if not bool(player.get("_sprint_exhausted")):
		_fail("Correr no agota la estamina")
		return
	if player.velocity.length() > float(player.get("walk_speed")) + 0.1:
		_fail("El personaje sigue corriendo agotado")
		return
	Input.action_release("player_sprint")
	Input.action_release("player_forward")
	for _tick in range(400):
		player.call("_physics_process", 1.0 / 60.0)
	var bar := hud.find_child("StaminaBar", true, false) as ProgressBar
	if float(player.get("stamina")) < 99.0 or bar == null or bar.value < 99.0:
		_fail("La estamina no se recupera o no aparece en el HUD")
		return
	player.position = Vector3(0, 0.78, 0)
	player.call("set_gameplay_input_enabled", false)
	Input.action_press("player_forward")
	player.call("_physics_process", 0.1)
	Input.action_release("player_forward")
	if player.position.distance_to(Vector3(0, 0.78, 0)) > 0.01 or bool(player.call("try_jump")):
		_fail("La UI no bloquea movimiento y salto")
		return
	player.call("set_gameplay_input_enabled", true)
	var options := hud.find_child("OptionsMenu", true, false)
	var slider := options.find_child("CameraSensitivitySlider", true, false) as HSlider
	player.get_node("CameraPivot").rotation = Vector3.ZERO
	slider.value = 0.5
	player.call("orbit_camera", Vector2(40, 0))
	var slow_yaw: float = player.get_node("CameraPivot").rotation_degrees.y
	player.get_node("CameraPivot").rotation = Vector3.ZERO
	slider.value = 2.0
	player.call("orbit_camera", Vector2(40, 0))
	if absf(player.get_node("CameraPivot").rotation_degrees.y / slow_yaw - 4.0) > 0.01:
		_fail("La sensibilidad de Opciones no cambia la orbita")
		return
	player.get_node("CameraPivot").rotation = Vector3.ZERO
	player.call("set_camera_distance", 0.0)
	if player.get_node("Visual").visible:
		_fail("Primera persona muestra la cabeza del personaje")
		return
	player.call("set_camera_distance", 5.0)
	if not player.get_node("Visual").visible:
		_fail("Alejar el zoom no restaura el personaje")
		return
	var wall := _wall(Vector3(0, 2.0, 2.5), Vector3(6, 4, 0.3))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var arm := player.get_node("CameraPivot/SpringArm3D") as SpringArm3D
	if arm.get_hit_length() >= arm.spring_length - 0.1:
		_fail("La camara atraviesa la pared")
		return
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if arm.get_hit_length() < arm.spring_length - 0.1:
		_fail("La camara no recupera el zoom despues de la pared")
		return
	_wall(Vector3(3, 2.0, 0), Vector3(0.3, 4, 6))
	await get_tree().physics_frame
	Input.action_press("player_right")
	for _tick in range(90):
		player.call("_physics_process", 1.0 / 60.0)
	Input.action_release("player_right")
	if player.position.x >= 2.6 or player.position.x < 2.0:
		_fail("El personaje no respeta la pared con collider")
		return
	var target := TestInteractable.new()
	add_child(target)
	target.position = player.position + Vector3(10, 0, 0)
	if bool(player.call("request_interaction_with", target)) or bool(player.get("has_target")):
		_fail("Un objetivo lejano mueve al personaje automaticamente")
		return
	target.position = player.position + Vector3(0, 0, -1)
	if not bool(player.call("request_interaction_with", target)):
		_fail("Un objetivo cercano no permite interactuar")
		return
	Input.action_press("player_forward")
	player.call("_physics_process", 1.0 / 60.0)
	Input.action_release("player_forward")
	if not target.canceled:
		_fail("Moverse no cancela la canalizacion")
		return
	print("PLAYER_CONTROLS_SMOKE_OK wasd=true jump=true stamina=true camera_collision=true options=true")
	get_tree().quit(0)


func _wall(center: Vector3, dimensions: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	return wall


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
