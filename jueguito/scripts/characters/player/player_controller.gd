extends CharacterBody3D

enum CameraMode { PERSPECTIVE_TACTICAL, PERSPECTIVE_CLOSE, ORTHOGRAPHIC }

const CAMERA_MODE_COUNT := 3
const AnimationRetargeter = preload("res://scripts/characters/player/character_animation_retargeter.gd")

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
var last_safe_position := Vector3.ZERO
var locomotion_state := ""

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
	# Si mantiene presionado el Clic Derecho, actualizamos el destino continuamente (estilo LoL)
	if gameplay_input_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_set_movement_target_from_mouse()

	var move_direction := Vector3.ZERO
	var target_speed := walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		target_speed = sprint_speed

	if has_target:
		var to_target = target_pos - global_position
		var to_target_2d = Vector2(to_target.x, to_target.z)
		
		# Si estamos a más de 20cm del destino, seguimos moviéndonos
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


func _set_movement_target_from_mouse() -> void:
	if camera == null:
		return
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
			
		if interactable != null:
			var dist = global_position.distance_to(interactable.global_position)
			if dist <= 3.5:
				# Si estamos en rango (3.5m), recolectamos autoritativamente
				var item_name: String = interactable.get("item_name") if "item_name" in interactable else interactable.name
				var amount: int = interactable.get("amount") if "amount" in interactable else 1
				NetworkManager.request_interaction(item_name, amount)
				interactable.call("interact", self)
			else:
				# Si estamos lejos, caminamos hacia el interactuable
				NetworkManager.request_move(interactable.global_position)



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
	var report := AnimationRetargeter.install_shared_library(
		character_instance,
		character_animation_player,
		final_animation_source
	)
	if not String(report.get("error", "")).is_empty():
		push_warning("Player: " + String(report["error"]))
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
