extends CharacterBody3D

enum CameraMode { PERSPECTIVE_TACTICAL, PERSPECTIVE_CLOSE, ORTHOGRAPHIC }

const CAMERA_MODE_COUNT := 3

@export var walk_speed := 3.85
@export var sprint_speed := 9.1
@export var acceleration := 18.0
@export var gravity := 42.0
@export_enum("Perspectiva tactica", "Perspectiva cercana", "Ortografica") var camera_mode: int = CameraMode.PERSPECTIVE_TACTICAL
@export var perspective_fov := 42.0
@export var close_perspective_fov := 58.0
@export var tactical_camera_pitch_degrees := -52.0
@export var close_camera_pitch_degrees := -35.0
@export var orthographic_camera_pitch_degrees := -55.0
@export var orthographic_zoom_step := 1.0
@export var min_orthographic_size := 5.0
@export var max_orthographic_size := 32.0
@export var initial_orthographic_size := 9.5
@export var camera_zoom_step := 6.0
@export var min_camera_distance := 5.0
@export var max_camera_distance := 260.0
@export var initial_camera_distance := 24.0
@export var close_camera_distance := 11.0
@export var use_generator_ground_snap := true
@export var ground_clearance := 0.98
@export var character_scene: PackedScene
@export var idle_animation_scene: PackedScene
@export var walk_animation_scene: PackedScene
@export var run_animation_scene: PackedScene
@export var character_visual_scale := 1.0
@export var character_visual_y_offset := 0.0
@export var character_visual_yaw_degrees := 0.0
@export var show_placeholder_visual := true

var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var character_instance: Node3D
var character_animation_player: AnimationPlayer
var last_safe_position := Vector3.ZERO
var locomotion_state := ""


func _ready() -> void:
	add_to_group("player")
	camera_pivot = $CameraPivot
	spring_arm = $CameraPivot/SpringArm3D
	camera = $CameraPivot/SpringArm3D/Camera3D
	visual = $Visual
	_setup_character_visual()
	camera_pivot.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	spring_arm.spring_length = initial_camera_distance
	_apply_camera_mode()
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
		_update_locomotion(move_direction, target_speed)
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
	_update_locomotion(move_direction, target_speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_camera_zoom(-_zoom_step_for_input())
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_camera_zoom(_zoom_step_for_input())


func make_camera_current() -> void:
	if camera != null:
		camera.make_current()


func mark_safe_position() -> void:
	last_safe_position = global_position


func get_camera_distance() -> float:
	if spring_arm == null:
		return 0.0
	return spring_arm.spring_length


func set_camera_distance(next_distance: float) -> void:
	if spring_arm == null:
		return
	spring_arm.spring_length = clampf(next_distance, min_camera_distance, max_camera_distance)


func adjust_camera_distance(delta_distance: float) -> void:
	set_camera_distance(get_camera_distance() + delta_distance)


func get_camera_zoom_value() -> float:
	if _camera_uses_orthographic():
		return camera.size
	return get_camera_distance()


func get_camera_zoom_min() -> float:
	if _camera_uses_orthographic():
		return min_orthographic_size
	return min_camera_distance


func get_camera_zoom_max() -> float:
	if _camera_uses_orthographic():
		return max_orthographic_size
	return max_camera_distance


func get_camera_zoom_label() -> String:
	if _camera_uses_orthographic():
		return "Ortho"
	return "Persp"


func get_camera_mode_label() -> String:
	match int(camera_mode):
		CameraMode.PERSPECTIVE_CLOSE:
			return "Perspectiva cercana"
		CameraMode.ORTHOGRAPHIC:
			return "Ortografica"
		_:
			return "Perspectiva tactica"


func set_camera_mode(next_mode: int) -> void:
	camera_mode = posmod(next_mode, CAMERA_MODE_COUNT)
	_apply_camera_mode()


func cycle_camera_mode() -> void:
	set_camera_mode(int(camera_mode) + 1)


func set_camera_zoom_value(next_zoom: float) -> void:
	if _camera_uses_orthographic():
		camera.size = clampf(next_zoom, min_orthographic_size, max_orthographic_size)
	else:
		set_camera_distance(next_zoom)


func adjust_camera_zoom(delta_zoom: float) -> void:
	set_camera_zoom_value(get_camera_zoom_value() + delta_zoom)


func _zoom_step_for_input() -> float:
	var base_step := orthographic_zoom_step if _camera_uses_orthographic() else camera_zoom_step
	if Input.is_key_pressed(KEY_CTRL):
		return base_step * 0.25
	if Input.is_key_pressed(KEY_SHIFT):
		return base_step * 3.0
	return base_step


func _apply_camera_mode() -> void:
	if camera == null:
		return
	match int(camera_mode):
		CameraMode.PERSPECTIVE_CLOSE:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = close_perspective_fov
			set_camera_distance(close_camera_distance)
			_set_camera_pitch(close_camera_pitch_degrees)
		CameraMode.ORTHOGRAPHIC:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = clampf(initial_orthographic_size, min_orthographic_size, max_orthographic_size)
			set_camera_distance(initial_camera_distance)
			_set_camera_pitch(orthographic_camera_pitch_degrees)
		_:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = perspective_fov
			set_camera_distance(initial_camera_distance)
			_set_camera_pitch(tactical_camera_pitch_degrees)


func _set_camera_pitch(pitch_degrees: float) -> void:
	if spring_arm == null:
		return
	var next_rotation := spring_arm.rotation_degrees
	next_rotation.x = pitch_degrees
	spring_arm.rotation_degrees = next_rotation


func _camera_uses_orthographic() -> bool:
	return camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL


func _setup_character_visual() -> void:
	if character_scene == null or visual == null:
		_set_placeholder_visible(true)
		return

	character_instance = character_scene.instantiate() as Node3D
	if character_instance == null:
		_set_placeholder_visible(true)
		return

	character_instance.name = "ImportedCharacter"
	character_instance.scale = Vector3.ONE * character_visual_scale
	character_instance.position.y = character_visual_y_offset
	character_instance.rotation_degrees.y = character_visual_yaw_degrees
	visual.add_child(character_instance)
	_set_placeholder_visible(show_placeholder_visual)

	character_animation_player = _find_animation_player(character_instance)
	if character_animation_player == null:
		return
	_install_locomotion_animation("idle", idle_animation_scene)
	_install_locomotion_animation("walk", walk_animation_scene)
	_install_locomotion_animation("run", run_animation_scene)
	_play_locomotion("idle")


func _set_placeholder_visible(next_visible: bool) -> void:
	if visual == null:
		return
	for child_name in ["Body", "ForwardMarker"]:
		var child := visual.get_node_or_null(child_name)
		if child is Node3D:
			(child as Node3D).visible = next_visible


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer


func _install_locomotion_animation(animation_key: String, animation_scene: PackedScene) -> void:
	if character_animation_player == null or animation_scene == null:
		return
	var animation := _first_animation_from_scene(animation_scene)
	if animation == null:
		return
	var library: AnimationLibrary
	if character_animation_player.has_animation_library("locomotion"):
		library = character_animation_player.get_animation_library("locomotion")
	else:
		library = AnimationLibrary.new()
		character_animation_player.add_animation_library("locomotion", library)
	if library.has_animation(animation_key):
		library.remove_animation(animation_key)
	animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(animation_key, animation)


func _first_animation_from_scene(animation_scene: PackedScene) -> Animation:
	var animation_root := animation_scene.instantiate()
	if animation_root == null:
		return null
	var source_player := _find_animation_player(animation_root)
	if source_player == null:
		animation_root.free()
		return null
	for animation_name in source_player.get_animation_list():
		if String(animation_name) == "RESET":
			continue
		var animation := source_player.get_animation(animation_name)
		animation_root.free()
		return animation.duplicate()
	animation_root.free()
	return null


func _update_locomotion(move_direction: Vector3, target_speed: float) -> void:
	if character_animation_player == null:
		return
	if move_direction.length_squared() < 0.001:
		_play_locomotion("idle")
	elif target_speed > walk_speed * 1.5:
		_play_locomotion("run")
	else:
		_play_locomotion("walk")


func _play_locomotion(next_state: String) -> void:
	if character_animation_player == null or locomotion_state == next_state:
		return
	var animation_name := _animation_name_for_state(next_state)
	if animation_name == "":
		return
	locomotion_state = next_state
	character_animation_player.play(animation_name, 0.18)


func _animation_name_for_state(state: String) -> StringName:
	var locomotion_name := StringName("locomotion/" + state)
	if character_animation_player.has_animation(locomotion_name):
		return locomotion_name
	if character_animation_player.has_animation(state):
		return StringName(state)
	if character_animation_player.has_animation("mixamo_com"):
		return &"mixamo_com"
	var animation_list := character_animation_player.get_animation_list()
	if animation_list.is_empty():
		return &""
	return animation_list[0]


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
