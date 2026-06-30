extends Node3D

const SURFACE_MASK_PATH := "res://data/map_design_surface_mask.png"
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const BASE_PROTOTYPE_WORLD_SCALE := 20.0
const CONTINENT_SCALE_MULTIPLIER := 10.0
const MAP_WORLD_SCALE := BASE_PROTOTYPE_WORLD_SCALE * CONTINENT_SCALE_MULTIPLIER
const MAP_WORLD_SIZE := MAP_IMAGE_SIZE * MAP_WORLD_SCALE
const GRID_CELL_SIDE_KM := 10.0
const GRID_STEP := GRID_CELL_SIDE_KM * 1000.0

const BASE_SPEED := 24000.0
const FAST_MULTIPLIER := 3.0
const SLOW_MULTIPLIER := 0.35
const LOOK_SENSITIVITY := 0.006
const MIN_CAMERA_HEIGHT := 80.0
const MAX_CAMERA_HEIGHT := 360000.0

var camera: Camera3D
var grid: MeshInstance3D
var looking := false
var yaw := 0.0
var pitch := -0.82
var show_grid := true


func _ready() -> void:
	_setup_environment()
	_setup_flat_world()
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
		pitch = clampf(pitch, -1.45, -0.10)
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
	environment.background_color = Color(0.07, 0.10, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 1.0, 1.0)
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	add_child(world_environment)


func _setup_flat_world() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrenoPlanoDesdeMascara"

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = MAP_WORLD_SIZE
	terrain.mesh = plane_mesh

	var material := StandardMaterial3D.new()
	material.albedo_texture = _build_preview_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain.material_override = material

	add_child(terrain)


func _build_preview_texture() -> ImageTexture:
	var source := Image.new()
	var error := source.load(ProjectSettings.globalize_path(SURFACE_MASK_PATH))
	if error != OK:
		source = Image.create(int(MAP_IMAGE_SIZE.x), int(MAP_IMAGE_SIZE.y), false, Image.FORMAT_RGBA8)
		source.fill(Color(0.26, 0.40, 0.28, 1.0))
	source.convert(Image.FORMAT_RGBA8)

	var preview := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var color := source.get_pixel(x, y)
			preview.set_pixel(x, y, _surface_preview_color(color, x, y))
	return ImageTexture.create_from_image(preview)


func _surface_preview_color(color: Color, x: int, y: int) -> Color:
	var noise := 0.96 + float((x * 17 + y * 31) % 11) / 250.0
	if _is_coast_color(color):
		return Color(0.78, 0.62, 0.30, 1.0) * noise
	if _is_land_color(color):
		return Color(0.25, 0.48, 0.24, 1.0) * noise
	if _is_deep_water_color(color):
		return Color(0.02, 0.10, 0.28, 1.0)
	if _is_water_color(color):
		return Color(0.05, 0.28, 0.58, 1.0)
	return Color(0.78, 0.76, 0.66, 1.0) * noise


func _is_land_color(color: Color) -> bool:
	return color.a > 0.12 and color.g > color.r * 1.7 and color.g > color.b * 0.70 and color.r < 0.40


func _is_coast_color(color: Color) -> bool:
	return color.a > 0.15 and color.r > 0.70 and color.g > 0.50 and color.b < 0.50


func _is_deep_water_color(color: Color) -> bool:
	return color.a > 0.20 and color.b > 0.35 and color.r < 0.08 and color.g < 0.20


func _is_water_color(color: Color) -> bool:
	return color.a > 0.18 and color.b > 0.35 and color.r < 0.28 and color.g > 0.15


func _setup_grid() -> void:
	grid = MeshInstance3D.new()
	grid.name = "Grilla10km"

	var immediate := ImmediateMesh.new()
	var half_width := MAP_WORLD_SIZE.x * 0.5
	var half_height := MAP_WORLD_SIZE.y * 0.5
	var segments_x := int(ceil(MAP_WORLD_SIZE.x / GRID_STEP * 0.5))
	var segments_z := int(ceil(MAP_WORLD_SIZE.y / GRID_STEP * 0.5))
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for x_index in range(-segments_x, segments_x + 1):
		var x := float(x_index) * GRID_STEP
		immediate.surface_add_vertex(Vector3(x, 8.0, -half_height))
		immediate.surface_add_vertex(Vector3(x, 8.0, half_height))
	for z_index in range(-segments_z, segments_z + 1):
		var z := float(z_index) * GRID_STEP
		immediate.surface_add_vertex(Vector3(-half_width, 8.0, z))
		immediate.surface_add_vertex(Vector3(half_width, 8.0, z))
	immediate.surface_end()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.86, 0.26)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid.mesh = immediate
	grid.material_override = material
	add_child(grid)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CamaraExploracion"
	camera.far = 900000.0
	camera.fov = 62.0
	add_child(camera)
	camera.make_current()
	_reset_camera()


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var label := Label.new()
	label.name = "FlatWorldNotes"
	label.position = Vector2(18, 16)
	label.text = "Terreno plano 3D v0.1 - mascara tierra/agua\n" \
		+ "WASD/Flechas: recorrer | Q/E: bajar/subir | Shift/Ctrl: velocidad\n" \
		+ "Derecho + mouse: mirar | Rueda: altura | R: reset | G: grilla\n" \
		+ "Sin texturas finales: colores de diseno convertidos a plano 3D"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.92))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)


func _reset_camera() -> void:
	yaw = 0.0
	pitch = -0.82
	camera.position = Vector3(0.0, MAP_WORLD_SIZE.y * 0.18, MAP_WORLD_SIZE.y * 0.18)
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
