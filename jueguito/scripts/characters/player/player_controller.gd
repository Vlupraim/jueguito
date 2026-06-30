extends CharacterBody3D

@export var walk_speed := 24.0
@export var sprint_speed := 72.0
@export var acceleration := 18.0
@export var gravity := 42.0
@export var camera_zoom_step := 2.0
@export var min_camera_distance := 12.0
@export var max_camera_distance := 72.0
@export var use_generator_ground_snap := true
@export var ground_clearance := 0.98

var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var last_safe_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	camera_pivot = $CameraPivot
	spring_arm = $CameraPivot/SpringArm3D
	camera = $CameraPivot/SpringArm3D/Camera3D
	visual = $Visual
	camera_pivot.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	spring_arm.rotation_degrees = Vector3(55.0, 0.0, 0.0)
	spring_arm.spring_length = 38.0
	last_safe_position = global_position
	make_camera_current()


func _physics_process(delta: float) -> void:
	var move_input := _get_move_input()
	var move_direction := _get_camera_relative_direction(move_input)
	var target_speed := walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		target_speed = sprint_speed

	if use_generator_ground_snap and _has_generator_ground_provider():
		_move_on_generator_ground(move_direction, target_speed, delta)
		_face_move_direction(move_direction, delta)
		return

	var target_velocity := move_direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * target_speed * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * target_speed * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	move_and_slide()
	_face_move_direction(move_direction, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(min_camera_distance, spring_arm.spring_length - camera_zoom_step)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(max_camera_distance, spring_arm.spring_length + camera_zoom_step)


func make_camera_current() -> void:
	if camera != null:
		camera.make_current()


func mark_safe_position() -> void:
	last_safe_position = global_position


func _get_move_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y -= 1.0
	return input.normalized()


func _get_camera_relative_direction(move_input: Vector2) -> Vector3:
	if move_input == Vector2.ZERO or camera == null:
		return Vector3.ZERO

	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	return (right * move_input.x + forward * move_input.y).normalized()


func _face_move_direction(move_direction: Vector3, delta: float) -> void:
	if move_direction.length_squared() < 0.001 or visual == null:
		return
	var target_yaw := atan2(-move_direction.x, -move_direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(1.0, delta * 12.0))


func _has_generator_ground_provider() -> bool:
	var parent := get_parent()
	return parent != null and parent.has_method("get_player_ground_info")


func _move_on_generator_ground(move_direction: Vector3, target_speed: float, delta: float) -> void:
	var parent := get_parent()
	var requested_position := global_position
	if move_direction != Vector3.ZERO:
		requested_position += move_direction * target_speed * delta

	var ground_info: Variant = parent.call("get_player_ground_info", requested_position)
	if not (ground_info is Dictionary):
		return

	var info := ground_info as Dictionary
	if bool(info.get("walkable", false)):
		var ground_position: Vector3 = info.get("position", global_position)
		global_position = ground_position + Vector3.UP * ground_clearance
		velocity = move_direction * target_speed
		last_safe_position = global_position
	else:
		global_position = last_safe_position
		velocity = Vector3.ZERO
