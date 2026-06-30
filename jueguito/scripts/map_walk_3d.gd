extends Node3D

const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const BASE_PROTOTYPE_WORLD_SCALE := 20.0
const CONTINENT_SCALE_MULTIPLIER := 10.0
const MAP_WORLD_SCALE := BASE_PROTOTYPE_WORLD_SCALE * CONTINENT_SCALE_MULTIPLIER
const MAP_WORLD_SIZE := MAP_IMAGE_SIZE * MAP_WORLD_SCALE
const GRID_CELL_SIDE_KM := 10.0
const GRID_STEP := GRID_CELL_SIDE_KM * 1000.0

const BASE_SPEED := 26000.0
const FAST_MULTIPLIER := 3.0
const SLOW_MULTIPLIER := 0.35
const LOOK_SENSITIVITY := 0.006
const MIN_CAMERA_HEIGHT := 120.0
const MAX_CAMERA_HEIGHT := 360000.0

var camera: Camera3D
var grid: MeshInstance3D
var looking := false
var yaw := 0.0
var pitch := -0.95
var show_grid := true


func _ready() -> void:
	_setup_environment()
	_setup_map_plane()
	_setup_grid()
	_setup_camera()
	_setup_ui()


func _process(delta: float) -> void:
	var movement := _get_camera_movement()
	if movement != Vector3.ZERO:
		var multiplier := 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			multiplier = FAST_MULTIPLIER
		elif Input.is_key_pressed(KEY_CTRL):
			multiplier = SLOW_MULTIPLIER
		camera.position += movement.normalized() * BASE_SPEED * multiplier * delta
		camera.position.y = clampf(camera.position.y, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			looking = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_camera_height(0.86)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_camera_height(1.16)
	elif event is InputEventMouseMotion and looking:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		yaw -= mouse_motion.relative.x * LOOK_SENSITIVITY
		pitch -= mouse_motion.relative.y * LOOK_SENSITIVITY
		pitch = clampf(pitch, -1.45, -0.18)
		_apply_camera_rotation()
	elif event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_R:
			_reset_camera()
		elif key_event.keycode == KEY_G:
			show_grid = not show_grid
			grid.visible = show_grid


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.11, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 1.0, 1.0)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)


func _setup_map_plane() -> void:
	var map_plane := MeshInstance3D.new()
	map_plane.name = "BocetoPlanoGigante"

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = MAP_WORLD_SIZE
	map_plane.mesh = plane_mesh

	var material := StandardMaterial3D.new()
	material.albedo_texture = load(MAP_TEXTURE_PATH) as Texture2D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	map_plane.material_override = material

	add_child(map_plane)


func _setup_grid() -> void:
	grid = MeshInstance3D.new()
	grid.name = "GrillaEscala"

	var immediate := ImmediateMesh.new()
	var half_width := MAP_WORLD_SIZE.x * 0.5
	var half_height := MAP_WORLD_SIZE.y * 0.5
	var segments_x := int(ceil(MAP_WORLD_SIZE.x / GRID_STEP * 0.5))
	var segments_z := int(ceil(MAP_WORLD_SIZE.y / GRID_STEP * 0.5))
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for x_index in range(-segments_x, segments_x + 1):
		var x := float(x_index) * GRID_STEP
		immediate.surface_add_vertex(Vector3(x, 6.0, -half_height))
		immediate.surface_add_vertex(Vector3(x, 6.0, half_height))
	for z_index in range(-segments_z, segments_z + 1):
		var z := float(z_index) * GRID_STEP
		immediate.surface_add_vertex(Vector3(-half_width, 6.0, z))
		immediate.surface_add_vertex(Vector3(half_width, 6.0, z))
	immediate.surface_end()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.32, 0.42, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid.mesh = immediate
	grid.material_override = material
	add_child(grid)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CamaraMaqueta"
	camera.far = 900000.0
	camera.fov = 58.0
	add_child(camera)
	camera.make_current()
	_reset_camera()


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var label := Label.new()
	label.name = "PrototypeNotes3D"
	label.position = Vector2(18, 16)
	label.text = "Maqueta 3D v0.1 - Boceto como piso gigante\n" \
		+ "WASD/Flechas: recorrer | Q/E: bajar/subir | Shift/Ctrl: velocidad\n" \
		+ "Derecho + mover mouse: mirar | Rueda: altura | R: reset | G: grilla\n" \
		+ "Escala provisional: cada recuadro = 10 km x 10 km (100 km2)\n" \
		+ "Boceto escalado x10 desde el primer prototipo: 334 km x 188 km aprox."
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)


func _reset_camera() -> void:
	yaw = 0.0
	pitch = -0.95
	camera.position = Vector3(0.0, MAP_WORLD_SIZE.y * 0.34, MAP_WORLD_SIZE.y * 0.38)
	_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	camera.rotation = Vector3(pitch, yaw, 0.0)


func _change_camera_height(factor: float) -> void:
	camera.position.y = clampf(camera.position.y * factor, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT)


func _get_camera_movement() -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement -= right
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		movement.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		movement.y -= 1.0
	return movement
