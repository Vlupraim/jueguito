extends Node2D

const MAP_TEXTURE_PATH := "res://assets/boceto.png"
const MAP_IMAGE_SIZE := Vector2(1672.0, 941.0)
const BASE_PROTOTYPE_WORLD_SCALE := 20.0
const CONTINENT_SCALE_MULTIPLIER := 10.0
const MAP_WORLD_SCALE := BASE_PROTOTYPE_WORLD_SCALE * CONTINENT_SCALE_MULTIPLIER
const MAP_WORLD_SIZE := MAP_IMAGE_SIZE * MAP_WORLD_SCALE
const GRID_CELL_SIDE_KM := 10.0
const GRID_STEP := GRID_CELL_SIDE_KM * 1000.0
const PAN_SPEED_SCREEN_PIXELS := 320.0
const FAST_PAN_MULTIPLIER := 3.0
const SLOW_PAN_MULTIPLIER := 0.35

const OCEAN_COLOR := Color(0.08, 0.12, 0.16)
const GRID_COLOR := Color(0.20, 0.30, 0.38, 0.22)
const ROUTE_COLOR := Color(0.08, 0.16, 0.22, 0.85)
const ROUTE_HIGHLIGHT := Color(1.0, 0.76, 0.20, 0.80)
const PORT_COLOR := Color(1.0, 0.65, 0.16)
const SAFE_COLOR := Color(0.1, 0.45, 1.0, 0.18)
const RED_ZONE_COLOR := Color(1.0, 0.12, 0.08, 0.16)
const BLACK_ZONE_COLOR := Color(0.05, 0.02, 0.03, 0.28)

var camera: Camera2D
var map_texture: Texture2D
var dragging := false
var last_mouse := Vector2.ZERO
var show_overlay := false
var show_grid := false

var ports: Array[Vector2] = []
var routes: Array[Array] = []
var zones: Array[Dictionary] = []


func _ready() -> void:
	map_texture = load(MAP_TEXTURE_PATH) as Texture2D
	_build_overlay_data()
	_setup_camera()
	_setup_ui()
	queue_redraw()


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		var multiplier := 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			multiplier = FAST_PAN_MULTIPLIER
		elif Input.is_key_pressed(KEY_CTRL):
			multiplier = SLOW_PAN_MULTIPLIER
		camera.position += pan.normalized() * PAN_SPEED_SCREEN_PIXELS * multiplier * delta / max(camera.zoom.x, 0.004)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = mouse_button.pressed
			last_mouse = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.12)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 / 1.12)
	elif event is InputEventMouseMotion and dragging:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		var drag_delta: Vector2 = mouse_motion.position - last_mouse
		camera.position -= drag_delta / max(camera.zoom.x, 0.05)
		last_mouse = mouse_motion.position
	elif event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_R:
			_reset_camera()
		elif key_event.keycode == KEY_O:
			show_overlay = not show_overlay
			queue_redraw()
		elif key_event.keycode == KEY_G:
			show_grid = not show_grid
			queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(-MAP_WORLD_SIZE * 0.5, MAP_WORLD_SIZE)
	draw_rect(map_rect.grow(900.0), OCEAN_COLOR, true)
	if map_texture != null:
		draw_texture_rect(map_texture, map_rect, false, Color.WHITE)
	else:
		draw_rect(map_rect, Color(0.92, 0.92, 0.88), true)
	if show_grid:
		_draw_grid(map_rect)
	if show_overlay:
		_draw_zones()
		_draw_routes()
		_draw_ports()
	_draw_map_border(map_rect)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "MapCamera"
	add_child(camera)
	camera.make_current()
	_reset_camera()


func _reset_camera() -> void:
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.0042, 0.0042)


func _zoom_at_mouse(factor: float) -> void:
	var before := camera.get_global_mouse_position()
	var next_zoom := clampf(camera.zoom.x * factor, 0.0025, 0.35)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after := camera.get_global_mouse_position()
	camera.position += before - after


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var label := Label.new()
	label.name = "PrototypeNotes"
	label.position = Vector2(18, 16)
	label.text = "Mapa prototipo 2D v0.3 - Boceto base limpio\n" \
		+ "WASD/Flechas: mover | Shift/Ctrl: velocidad | Rueda: zoom | R: reset\n" \
		+ "O: capas experimentales apagadas por defecto | G: grilla\n" \
		+ "Escala provisional: recuadro 10 km x 10 km | boceto x10"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.08, 0.10, 0.12))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)


func _build_overlay_data() -> void:
	ports = [
		_px(300, 514), _px(409, 651), _px(393, 305),
		_px(653, 326), _px(637, 703), _px(812, 707),
		_px(1130, 392), _px(1134, 545), _px(1265, 612),
		_px(1312, 543), _px(1335, 304), _px(557, 382),
	]

	routes = [
		[ports[0], ports[3], ports[6], ports[10]],
		[ports[0], ports[1], ports[4], ports[5], ports[8], ports[9]],
		[ports[2], ports[3], ports[7], ports[9]],
		[ports[1], _px(560, 706), _px(760, 760), ports[5]],
		[ports[6], ports[9], ports[10]],
		[ports[0], _px(505, 378), ports[11], ports[4]],
		[ports[7], ports[8], _px(1320, 760)],
	]

	zones = [
		{"center": _px(300, 514), "radius": 300.0, "color": SAFE_COLOR},
		{"center": _px(1312, 543), "radius": 300.0, "color": SAFE_COLOR},
		{"center": _px(420, 635), "radius": 430.0, "color": RED_ZONE_COLOR},
		{"center": _px(1230, 505), "radius": 430.0, "color": RED_ZONE_COLOR},
		{"center": _px(835, 455), "radius": 620.0, "color": BLACK_ZONE_COLOR},
	]


func _px(x: float, y: float) -> Vector2:
	return Vector2(x * MAP_WORLD_SCALE, y * MAP_WORLD_SCALE) - MAP_WORLD_SIZE * 0.5


func _draw_grid(map_rect: Rect2) -> void:
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), GRID_COLOR, 35.0, true)
		x += GRID_STEP
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), GRID_COLOR, 35.0, true)
		y += GRID_STEP


func _draw_zones() -> void:
	for zone in zones:
		draw_circle(zone["center"], zone["radius"] * 2.0, zone["color"])


func _draw_routes() -> void:
	for route in routes:
		for i in range(route.size() - 1):
			_draw_dashed_segment(route[i], route[i + 1], ROUTE_COLOR, 22.0, 170.0, 115.0)
			_draw_dashed_segment(route[i], route[i + 1], ROUTE_HIGHLIGHT, 7.0, 170.0, 115.0)


func _draw_ports() -> void:
	for port in ports:
		draw_circle(port, 65.0, Color(0.05, 0.04, 0.03))
		draw_circle(port, 42.0, PORT_COLOR)


func _draw_map_border(map_rect: Rect2) -> void:
	draw_rect(map_rect, Color(0.05, 0.06, 0.06, 0.95), false, 18.0)


func _draw_dashed_segment(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var direction: Vector2 = to - from
	var length: float = direction.length()
	if length <= 0.1:
		return
	var unit: Vector2 = direction / length
	var cursor: float = 0.0
	while cursor < length:
		var start: Vector2 = from + unit * cursor
		var stop: Vector2 = from + unit * minf(cursor + dash, length)
		draw_line(start, stop, color, width, true)
		cursor += dash + gap
