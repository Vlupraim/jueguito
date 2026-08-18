extends CharacterBody3D

signal water_state_changed(previous_state: String, next_state: String)
signal timed_action_started(label: String, duration: float)
signal timed_action_progress(elapsed: float, duration: float)
signal timed_action_finished(completed: bool)

enum CameraMode { PERSPECTIVE_TACTICAL, PERSPECTIVE_CLOSE, ORTHOGRAPHIC }

const CAMERA_MODE_COUNT := 3
const AnimationRetargeter = preload("res://scripts/characters/player/character_animation_retargeter.gd")
const ItemCatalog = preload("res://scripts/systems/items/item_catalog.gd")
const CHOP_ACTION := &"chop"
const CHOP_PLAYBACK_SPEED := 1.30
const CHOP_LOOP_CAPTURE_DURATION := 0.28

@export var walk_speed := 3.85
@export var sprint_speed := 9.1
@export var acceleration := 18.0
@export var gravity := 42.0
@export_range(0.1, 1.0, 0.05) var wade_speed_multiplier := 0.55
@export var swim_speed := 2.6
## Distancia entre el origen del personaje y la superficie al nadar. Con el
## modelo actual deja la linea del agua cerca de los hombros.
@export var swimming_body_offset := 0.68
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
@export var initial_camera_distance := 18.0
@export var close_camera_distance := 11.0
@export var use_generator_ground_snap := true
@export var ground_clearance := 0.98
@export var character_scene: PackedScene
@export_file("*.glb") var animation_source_path := AnimationRetargeter.DEFAULT_SOURCE_PATH
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
var character_action_animation := &""
var character_action_speed := 1.0
var last_safe_position := Vector3.ZERO
var locomotion_state := ""
var water_state := "dry"
var pending_interactable: Node3D
var active_interactable: Node3D
var timed_action_elapsed := 0.0
var timed_action_duration := 0.0
var timed_action_animation := &""

# Variables para movimiento tipo LoL (click-to-move)
var target_pos := Vector3.ZERO
var has_target := false
var gameplay_input_enabled := true


func _ready() -> void:
	add_to_group("player")
	camera_pivot = $CameraPivot
	spring_arm = $CameraPivot/SpringArm3D
	camera = $CameraPivot/SpringArm3D/Camera3D
	visual = $Visual
	_setup_character_visual()
	if not GameManager.equipment_changed.is_connected(_on_equipment_changed):
		GameManager.equipment_changed.connect(_on_equipment_changed)
	_refresh_equipped_items()
	camera_pivot.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	spring_arm.spring_length = initial_camera_distance
	_apply_camera_mode()
	last_safe_position = global_position
	make_camera_current()
	
	# Suscripción al movimiento aprobado por el servidor
	NetworkManager.movement_approved.connect(_on_movement_approved)


func _on_movement_approved(approved_position: Vector3) -> void:
	target_pos = approved_position
	has_target = true



func _physics_process(delta: float) -> void:
	var move_direction := Vector3.ZERO
	var target_speed := walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		target_speed = sprint_speed

	if gameplay_input_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_set_movement_target_from_mouse()
	if _update_timed_interaction(delta):
		return
	_update_pending_interaction()
	if active_interactable != null:
		return

	if has_target:
		var to_target = target_pos - global_position
		var to_target_2d = Vector2(to_target.x, to_target.z)
		if to_target_2d.length() > 0.2:
			move_direction = to_target.normalized()
			move_direction.y = 0.0
			move_direction = move_direction.normalized()
		else:
			has_target = false
			velocity.x = 0.0
			velocity.z = 0.0

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
	if not gameplay_input_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_camera_zoom(-_zoom_step_for_input())
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_camera_zoom(_zoom_step_for_input())
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_set_movement_target_from_mouse()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_try_interact_from_mouse()


func set_gameplay_input_enabled(enabled: bool) -> void:
	gameplay_input_enabled = enabled
	if not enabled:
		has_target = false
		velocity.x = 0.0
		velocity.z = 0.0
		_cancel_timed_interaction()


func hold_character_action_pose(action: StringName, pose_time := 0.0) -> bool:
	if not play_character_action(action, 0.0):
		return false
	character_animation_player.seek(maxf(pose_time, 0.0), true)
	character_animation_player.pause()
	return true


func get_character_action_duration(action: StringName) -> float:
	if character_animation_player == null:
		return 0.0
	var animation_name := AnimationRetargeter.shared_animation_name(action)
	if not character_animation_player.has_animation(animation_name):
		return 0.0
	return character_animation_player.get_animation(animation_name).length


func _set_movement_target_from_mouse() -> void:
	if camera == null:
		return
	_cancel_timed_interaction()
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * 2000.0)
	query.exclude = [get_rid()]
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var click_pos: Vector3 = result.position
		# Enviar petición de movimiento autoritativo al Servidor Mock
		NetworkManager.request_move(click_pos)


func _try_interact_from_mouse() -> void:
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * 2000.0)
	# Permitir colisión con áreas (los interactuables suelen ser Area3D)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var collider = result.collider
		var interactable = collider
		
		# Buscamos si el objeto o sus padres tienen método interact
		while interactable != null and not interactable.has_method("interact"):
			interactable = interactable.get_parent()
			
		if interactable is Node3D:
			request_interaction_with(interactable as Node3D)


func request_interaction_with(interactable: Node3D) -> bool:
	if not is_instance_valid(interactable):
		return false
	if interactable.has_method("can_interact") and not bool(
		interactable.call("can_interact", self)
	):
		return false
	_cancel_timed_interaction()
	pending_interactable = interactable
	if _interaction_distance(interactable) <= _interaction_range(interactable):
		_begin_pending_interaction()
	else:
		var approach_position := interactable.global_position
		if interactable.has_method("get_interaction_position"):
			approach_position = interactable.call(
				"get_interaction_position",
				global_position
			)
		NetworkManager.request_move(approach_position)
	return true


func has_equipped_tool(tool_type: String) -> bool:
	return GameManager.has_equipped_tool_type(tool_type)


func play_primary_equipment_action() -> bool:
	var action := ItemCatalog.get_default_action(GameManager.equipped_primary_item)
	if action.is_empty():
		return false
	return play_character_action(action)


func _update_pending_interaction() -> void:
	if pending_interactable == null:
		return
	if not is_instance_valid(pending_interactable):
		pending_interactable = null
		return
	if pending_interactable.has_method("can_interact") and not bool(
		pending_interactable.call("can_interact", self)
	):
		pending_interactable = null
		return
	if _interaction_distance(pending_interactable) <= _interaction_range(pending_interactable):
		_begin_pending_interaction()


func _begin_pending_interaction() -> void:
	var interactable := pending_interactable
	pending_interactable = null
	if not is_instance_valid(interactable):
		return
	if interactable.has_method("begin_interaction") and not bool(
		interactable.call("begin_interaction", self)
	):
		return
	active_interactable = interactable
	has_target = false
	velocity = Vector3.ZERO
	timed_action_elapsed = 0.0
	timed_action_duration = 1.0
	if interactable.has_method("get_interaction_duration"):
		timed_action_duration = maxf(
			float(interactable.call("get_interaction_duration")),
			0.05
		)
	var label := "Interactuando"
	if interactable.has_method("get_interaction_label"):
		label = String(interactable.call("get_interaction_label"))
	timed_action_animation = &""
	if interactable.has_method("get_interaction_animation"):
		timed_action_animation = StringName(
			interactable.call("get_interaction_animation")
		)
	face_world_position(interactable.global_position)
	if not timed_action_animation.is_empty():
		play_character_action(timed_action_animation)
	timed_action_started.emit(label, timed_action_duration)
	timed_action_progress.emit(0.0, timed_action_duration)


func _update_timed_interaction(delta: float) -> bool:
	if active_interactable == null:
		return false
	if not is_instance_valid(active_interactable):
		_cancel_timed_interaction()
		return false
	if _interaction_distance(active_interactable) > _interaction_range(active_interactable) + 0.8:
		_cancel_timed_interaction()
		return false
	velocity = Vector3.ZERO
	face_world_position(active_interactable.global_position)
	timed_action_elapsed = minf(timed_action_elapsed + delta, timed_action_duration)
	timed_action_progress.emit(timed_action_elapsed, timed_action_duration)
	if character_action_animation.is_empty() and not timed_action_animation.is_empty():
		play_character_action(timed_action_animation)
	if timed_action_elapsed < timed_action_duration:
		return true

	var interactable := active_interactable
	active_interactable = null
	var completed := true
	if interactable.has_method("complete_interaction"):
		completed = bool(interactable.call("complete_interaction", self))
	stop_character_action()
	timed_action_elapsed = 0.0
	timed_action_duration = 0.0
	timed_action_animation = &""
	timed_action_finished.emit(completed)
	return true


func _cancel_timed_interaction() -> void:
	pending_interactable = null
	if active_interactable != null and is_instance_valid(active_interactable):
		if active_interactable.has_method("cancel_interaction"):
			active_interactable.call("cancel_interaction", self)
		active_interactable = null
		stop_character_action()
		timed_action_finished.emit(false)
	timed_action_elapsed = 0.0
	timed_action_duration = 0.0
	timed_action_animation = &""


func _interaction_range(interactable: Node3D) -> float:
	if interactable.has_method("get_interaction_range"):
		return maxf(float(interactable.call("get_interaction_range")), 0.1)
	return 3.5


func _interaction_distance(interactable: Node3D) -> float:
	var offset := interactable.global_position - global_position
	return Vector2(offset.x, offset.z).length()



func make_camera_current() -> void:
	if camera != null:
		camera.make_current()


func mark_safe_position() -> void:
	last_safe_position = global_position


func face_world_position(world_target: Vector3) -> void:
	if visual == null:
		return
	var direction := world_target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	visual.rotation.y = atan2(-direction.x, -direction.z)


func get_facing_direction_xz() -> Vector2:
	if visual == null:
		return Vector2(0.0, -1.0)
	return Vector2(-sin(visual.rotation.y), -cos(visual.rotation.y)).normalized()


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
	var final_character_scene = character_scene
	var custom_visual_scale := character_visual_scale
	var final_animation_source := animation_source_path

	# Carga dinámica si el GameManager tiene un personaje con modelo asignado
	if GameManager != null and not GameManager.current_character.is_empty():
		custom_visual_scale = GameManager.current_character.get("visual_scale", character_visual_scale)
		
		var custom_model_path: String = GameManager.current_character.get("model_path", "")
		if not custom_model_path.is_empty() and ResourceLoader.exists(custom_model_path):
			var loaded_model = load(custom_model_path)
			if loaded_model is PackedScene:
				final_character_scene = loaded_model
		final_animation_source = GameManager.current_character.get(
			"animation_source_path",
			animation_source_path
		)

	if final_character_scene == null or visual == null:
		_set_placeholder_visible(true)
		return

	character_instance = final_character_scene.instantiate() as Node3D
	if character_instance == null:
		_set_placeholder_visible(true)
		return

	character_instance.name = "ImportedCharacter"
	character_instance.scale = Vector3.ONE * custom_visual_scale
	character_instance.position.y = character_visual_y_offset
	character_instance.rotation_degrees.y = character_visual_yaw_degrees
	visual.add_child(character_instance)
	_set_placeholder_visible(show_placeholder_visual)

	# Aplicar cabello/peluca si está definido
	if GameManager != null and not GameManager.current_character.is_empty():
		var hair_path: String = GameManager.current_character.get("hair_path", "")
		if not hair_path.is_empty():
			_attach_hair(character_instance, hair_path)
			
			# Aplicar color de cabello guardado
			var hair_color_html: String = GameManager.current_character.get("hair_color", "")
			if not hair_color_html.is_empty():
				var hair_color = Color.from_string(hair_color_html, Color.WHITE)
				var attachment = character_instance.find_child("HairAttachment", true, false)
				if attachment != null:
					_apply_hair_color(attachment, hair_color)

	character_animation_player = _find_animation_player(character_instance)
	if character_animation_player == null:
		return
	if not character_animation_player.animation_finished.is_connected(
		_on_character_animation_finished
	):
		character_animation_player.animation_finished.connect(
			_on_character_animation_finished
		)
	var report := AnimationRetargeter.install_shared_library(
		character_instance,
		character_animation_player,
		final_animation_source
	)
	if not String(report.get("error", "")).is_empty():
		push_warning("Player: " + String(report["error"]))
	_play_locomotion("idle")


func _on_equipment_changed(_primary_item: String, _secondary_item: String) -> void:
	_refresh_equipped_items()


func _refresh_equipped_items() -> void:
	if character_instance == null:
		return
	var skeletons := character_instance.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	for attachment_name in ["PrimaryItemAttachment", "SecondaryItemAttachment"]:
		var old_attachment := skeleton.get_node_or_null(attachment_name)
		if old_attachment != null:
			old_attachment.free()
	var primary_visual_slot := ItemCatalog.get_visual_slot(
		GameManager.equipped_primary_item
	)
	var primary_candidates: Array[String] = ["RightHand", "right_hand", "hand_r"]
	if primary_visual_slot == "secondary":
		primary_candidates = ["LeftHand", "left_hand", "hand_l"]
	_attach_item_to_hand(
		skeleton,
		GameManager.equipped_primary_item,
		primary_visual_slot,
		primary_candidates
	)
	_attach_item_to_hand(
		skeleton,
		GameManager.equipped_secondary_item,
		"secondary",
		["LeftHand", "left_hand", "hand_l"]
	)


func _attach_item_to_hand(
		skeleton: Skeleton3D,
		item_name: String,
		slot_name: String,
		bone_candidates: Array[String]
	) -> void:
	if item_name.is_empty():
		return
	var definition := ItemCatalog.get_definition(item_name)
	var item_scene := ItemCatalog.get_model_scene(item_name)
	if definition.is_empty() or item_scene == null:
		return
	var configured_bone := String(definition.get(
		"attachment_%s_bone" % slot_name,
		definition.get("attachment_bone", "")
	))
	var resolved_candidates := bone_candidates.duplicate()
	if not configured_bone.is_empty():
		resolved_candidates.push_front(configured_bone)
	var hand_bone := _find_bone_name(skeleton, resolved_candidates)
	if hand_bone.is_empty():
		push_warning("Player: no se encontro el hueso para " + slot_name)
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "PrimaryItemAttachment" if slot_name == "primary" \
		else "SecondaryItemAttachment"
	attachment.bone_name = hand_bone
	skeleton.add_child(attachment)

	# El armature del personaje usa una escala de importacion 0.01. Este pivote
	# la compensa para que los items puedan definirse normalmente en metros.
	var scale_compensator := Node3D.new()
	scale_compensator.name = "ScaleCompensator"
	var armature := skeleton.get_parent() as Node3D
	if armature != null:
		scale_compensator.scale = Vector3(
			1.0 / maxf(absf(armature.scale.x), 0.0001),
			1.0 / maxf(absf(armature.scale.y), 0.0001),
			1.0 / maxf(absf(armature.scale.z), 0.0001)
		)
	attachment.add_child(scale_compensator)

	var item := item_scene.instantiate() as Node3D
	item.name = "EquippedPrimaryItem" if slot_name == "primary" \
		else "EquippedSecondaryItem"
	item.position = definition.get(
		"held_%s_position" % slot_name,
		definition.get("held_position", Vector3.ZERO)
	)
	item.rotation_degrees = definition.get(
		"held_%s_rotation_degrees" % slot_name,
		definition.get("held_rotation_degrees", Vector3.ZERO)
	)
	item.scale = Vector3.ONE * float(definition.get(
		"held_%s_scale" % slot_name,
		definition.get("held_scale", 1.0)
	))
	scale_compensator.add_child(item)


func _find_bone_name(skeleton: Skeleton3D, candidates: Array[String]) -> String:
	for candidate in candidates:
		if skeleton.find_bone(candidate) >= 0:
			return candidate
	var side := "right" if "right" in candidates[0].to_lower() else "left"
	for bone_index in range(skeleton.get_bone_count()):
		var normalized := skeleton.get_bone_name(bone_index).to_lower().replace("_", "")
		if side in normalized and "hand" in normalized:
			return skeleton.get_bone_name(bone_index)
	return ""


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


func _update_locomotion(move_direction: Vector3, target_speed: float) -> void:
	if character_animation_player == null:
		return
	if not character_action_animation.is_empty():
		return
	if water_state == "swimming" or water_state == "open_water":
		_play_locomotion(
			"swim_forward" if move_direction.length_squared() >= 0.001 else "swim_idle"
		)
		return
	if water_state == "wading":
		_play_locomotion("walk" if move_direction.length_squared() >= 0.001 else "idle")
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


func play_character_action(
		action: StringName,
		blend_time: float = 0.12,
		custom_speed: float = 0.0
	) -> bool:
	if character_animation_player == null:
		return false
	var animation_name := AnimationRetargeter.shared_animation_name(action)
	if not character_animation_player.has_animation(animation_name):
		return false
	var resolved_speed := custom_speed
	if is_zero_approx(resolved_speed):
		resolved_speed = CHOP_PLAYBACK_SPEED if action == CHOP_ACTION else 1.0
	character_action_animation = animation_name
	character_action_speed = resolved_speed
	character_animation_player.play(animation_name, blend_time, resolved_speed)
	return true


func stop_character_action() -> void:
	if character_action_animation.is_empty():
		return
	character_action_animation = &""
	character_action_speed = 1.0
	locomotion_state = ""
	if character_animation_player != null:
		character_animation_player.stop()


func _on_character_animation_finished(animation_name: StringName) -> void:
	if animation_name != character_action_animation:
		return
	if (
		timed_action_animation == CHOP_ACTION
		and active_interactable != null
		and is_instance_valid(active_interactable)
		and character_animation_player != null
	):
		character_animation_player.play_with_capture(
			animation_name,
			CHOP_LOOP_CAPTURE_DURATION,
			-1.0,
			character_action_speed
		)
		return
	stop_character_action()


func _animation_name_for_state(state: String) -> StringName:
	var shared_name := AnimationRetargeter.shared_animation_name(StringName(state))
	if character_animation_player.has_animation(shared_name):
		return shared_name
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
	var current_info: Variant = parent.call("get_player_ground_info", global_position)
	var current_water := {"in_water": false, "state": "dry"}
	if current_info is Dictionary:
		current_water = (current_info as Dictionary).get("water", current_water)
	var current_state := String(current_water.get("state", "dry"))
	var effective_speed := target_speed
	if current_state == "wading":
		effective_speed *= wade_speed_multiplier
	elif current_state == "swimming" or current_state == "open_water":
		effective_speed = minf(target_speed, swim_speed)

	var requested_position := global_position
	if move_direction != Vector3.ZERO:
		requested_position += move_direction * effective_speed * delta
	var movement_blocked := _is_resource_collider_at(requested_position)
	if movement_blocked:
		requested_position = global_position

	var ground_info: Variant = parent.call("get_player_ground_info", requested_position)
	if not (ground_info is Dictionary):
		return

	var info := ground_info as Dictionary
	var water_info: Dictionary = info.get("water", {"in_water": false, "state": "dry"})
	var next_water_state := String(water_info.get("state", "dry"))
	var current_ground_info := current_info as Dictionary
	if not _is_platform_transition_allowed(current_ground_info, info):
		global_position = last_safe_position
		velocity = Vector3.ZERO
		return
	_set_water_state(next_water_state)

	if next_water_state == "open_water":
		global_position = last_safe_position
		velocity = Vector3.ZERO
		return
	if next_water_state == "swimming":
		# No existe buceo: al entrar a profundidad de nado, el personaje queda
		# anclado a la lamina del oceano. La profundidad del terreno solo clasifica
		# la zona y no se convierte en recorrido vertical.
		var target_swim_y := float(water_info.get(
			"float_height",
			water_info.get("water_level", global_position.y)
		)) - swimming_body_offset
		global_position = Vector3(
			requested_position.x,
			target_swim_y,
			requested_position.z
		)
		velocity = Vector3.ZERO if movement_blocked else move_direction * effective_speed
		last_safe_position = global_position
		return

	if bool(info.get("walkable", false)):
		var ground_position: Vector3 = info.get("position", global_position)
		global_position = ground_position + Vector3.UP * ground_clearance
		velocity = Vector3.ZERO if movement_blocked else move_direction * effective_speed
		last_safe_position = global_position
	else:
		global_position = last_safe_position
		velocity = Vector3.ZERO
		if String(info.get("reason", "")) == "limite_sector":
				has_target = false


func _is_resource_collider_at(requested_position: Vector3) -> bool:
	var player_collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_collision == null or player_collision.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player_collision.shape
	var next_transform := player_collision.global_transform
	next_transform.origin.x = requested_position.x
	next_transform.origin.z = requested_position.z
	query.transform = next_transform
	# Capa 3 (valor 4): troncos y otros recursos solidos. El terreno se
	# resuelve mediante get_player_ground_info y no participa en esta consulta.
	query.collision_mask = 4
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_platform_transition_allowed(current_info: Dictionary, next_info: Dictionary) -> bool:
	var current_platform := String(current_info.get("platform_id", ""))
	var next_platform := String(next_info.get("platform_id", ""))
	var current_role := String(current_info.get("surface_role", ""))
	var next_role := String(next_info.get("surface_role", ""))

	# Para subir por primera vez se debe pisar la rampa. Esto evita saltar desde
	# cualquier costado directamente a una cubierta elevada.
	if current_platform.is_empty() and not next_platform.is_empty():
		return next_role == "ramp"
	# Una vez a bordo solo se puede abandonar la plataforma desde la rampa. En
	# navegacion, esta regla evita caidas accidentales por los bordes del barco.
	if not current_platform.is_empty() and next_platform.is_empty():
		return current_role == "ramp"
	return current_platform == next_platform


func _set_water_state(next_state: String) -> void:
	if water_state == next_state:
		return
	var previous_state := water_state
	water_state = next_state
	water_state_changed.emit(previous_state, water_state)


func _attach_hair(character_node: Node3D, hair_path: String) -> void:
	# 1. Intentar encontrar Skeleton3D
	var skeletons = character_node.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		# Fallback sin skeleton (estático): lo pegamos al nodo raíz
		var old_hair = character_node.get_node_or_null("HairAttachment")
		if old_hair != null:
			old_hair.free()
			
		if hair_path.is_empty() or not ResourceLoader.exists(hair_path):
			return
			
		var hair_scene = load(hair_path) as PackedScene
		if hair_scene != null:
			var hair_inst = hair_scene.instantiate() as Node3D
			hair_inst.name = "HairAttachment"
			hair_inst.scale = Vector3.ONE
			hair_inst.position = Vector3(0, 1.5, 0)
			character_node.add_child(hair_inst)
		return
		
	var skeleton = skeletons[0] as Skeleton3D
	
	# 2. Buscar si ya existe el BoneAttachment3D bajo el skeleton
	var attachment: BoneAttachment3D = null
	for child in skeleton.get_children():
		if child is BoneAttachment3D and "HairAttachment" in child.name:
			attachment = child
			break
			
	# Si existe, limpiamos sus hijos de inmediato para no acumular pelucas
	if attachment != null:
		for child in attachment.get_children():
			child.free()
			
	# Si elegimos "Sin Cabello", eliminamos el attachment y terminamos
	if hair_path.is_empty() or not ResourceLoader.exists(hair_path):
		if attachment != null:
			attachment.free()
		return
		
	# Si no existe el BoneAttachment3D, lo creamos y vinculamos al hueso de la cabeza
	if attachment == null:
		var head_bone_name := ""
		for i in range(skeleton.get_bone_count()):
			var b_name = skeleton.get_bone_name(i).to_lower()
			if "head" in b_name or "cabeza" in b_name:
				head_bone_name = skeleton.get_bone_name(i)
				break
				
		if head_bone_name == "":
			head_bone_name = skeleton.get_bone_name(skeleton.get_bone_count() - 1)
			
		attachment = BoneAttachment3D.new()
		attachment.name = "HairAttachment"
		attachment.bone_name = head_bone_name
		skeleton.add_child(attachment)
		
	# 3. Instanciar el nuevo cabello
	var hair_scene = load(hair_path) as PackedScene
	if hair_scene != null:
		var hair_inst = hair_scene.instantiate() as Node3D
		# Compensar la escala del armature (0.01) para que el .tscn mantenga su escala 1.0 en el mundo
		var comp_scale = Vector3.ONE
		var parent_node = skeleton.get_parent()
		if parent_node is Node3D and parent_node.scale.x > 0:
			comp_scale = Vector3.ONE / parent_node.scale
			
		hair_inst.scale = comp_scale
		hair_inst.position = Vector3.ZERO
		hair_inst.rotation = Vector3.ZERO
		attachment.add_child(hair_inst)


func _apply_hair_color(node: Node, color: Color) -> void:
	if node == null:
		return
	print("[Pelo Juego] Aplicando color: ", color, " al nodo: ", node.name)
	var mesh_instances = node.find_children("*", "MeshInstance3D", true, false)
	print("[Pelo Juego] Mallas encontradas: ", mesh_instances.size())
	for mesh_inst in mesh_instances:
		var active_mat = mesh_inst.get_active_material(0)
		if active_mat == null and mesh_inst.mesh != null and mesh_inst.mesh.get_surface_count() > 0:
			active_mat = mesh_inst.mesh.surface_get_material(0)
			
		print("[Pelo Juego] Malla: ", mesh_inst.name, " | Material activo: ", active_mat)
		if active_mat is BaseMaterial3D:
			var dup_mat = active_mat.duplicate() as BaseMaterial3D
			dup_mat.albedo_color = color
			mesh_inst.material_override = dup_mat
			print("[Pelo Juego] Material base duplicado y aplicado con albedo_color = ", color)
		else:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mesh_inst.material_override = mat
			print("[Pelo Juego] Nuevo StandardMaterial3D plano aplicado con albedo_color = ", color)
