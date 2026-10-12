extends Node

signal cursor_mode_changed(mode: StringName)

const DEFAULT := &"default"
const WAIT := &"wait"
const POINTING_HAND := &"pointing_hand"
const GRAB := &"grab"
const GRABBING := &"grabbing"
const ATTACK := &"attack"
const PVP_DISABLED := &"pvp_disabled"
const PVP_ENABLED := &"pvp_enabled"
const FORBIDDEN := &"forbidden"
const ZOOM_IN := &"zoom_in"
const ZOOM_OUT := &"zoom_out"
const MOVE := &"move"
const CHAT := &"chat"
const HELP := &"help"
const TEXT := &"text"

const SOURCE_CURSOR_SIZE := 64.0
const CURSOR_PIXEL_SIZE := 40

const CURSOR_PATHS := {
	DEFAULT: "res://assets/ui/cursors/cursor_arrow.png",
	WAIT: "res://assets/ui/cursors/cursor_wait.png",
	POINTING_HAND: "res://assets/ui/cursors/cursor_pointing_hand.png",
	GRAB: "res://assets/ui/cursors/cursor_grab.png",
	GRABBING: "res://assets/ui/cursors/cursor_grabbing.png",
	ATTACK: "res://assets/ui/cursors/cursor_attack.png",
	PVP_DISABLED: "res://assets/ui/cursors/cursor_attack.png",
	PVP_ENABLED: "res://assets/ui/cursors/cursor_pvp_enabled.png",
	FORBIDDEN: "res://assets/ui/cursors/cursor_forbidden.png",
	ZOOM_IN: "res://assets/ui/cursors/cursor_zoom_in.png",
	ZOOM_OUT: "res://assets/ui/cursors/cursor_zoom_out.png",
	MOVE: "res://assets/ui/cursors/cursor_move.png",
	CHAT: "res://assets/ui/cursors/cursor_chat.png",
	HELP: "res://assets/ui/cursors/cursor_help.png",
	TEXT: "res://assets/ui/cursors/cursor_text.png",
}

const HOTSPOTS := {
	DEFAULT: Vector2(7, 5),
	WAIT: Vector2(32, 32),
	POINTING_HAND: Vector2(28, 5),
	GRAB: Vector2(31, 28),
	GRABBING: Vector2(30, 29),
	ATTACK: Vector2(7, 7),
	PVP_DISABLED: Vector2(7, 7),
	PVP_ENABLED: Vector2(32, 28),
	FORBIDDEN: Vector2(32, 32),
	ZOOM_IN: Vector2(25, 25),
	ZOOM_OUT: Vector2(25, 25),
	MOVE: Vector2(32, 32),
	CHAT: Vector2(31, 30),
	HELP: Vector2(31, 13),
	TEXT: Vector2(32, 32),
}

const CURSOR_SHAPES := {
	DEFAULT: Input.CURSOR_ARROW,
	WAIT: Input.CURSOR_WAIT,
	POINTING_HAND: Input.CURSOR_POINTING_HAND,
	GRAB: Input.CURSOR_DRAG,
	GRABBING: Input.CURSOR_CAN_DROP,
	ATTACK: Input.CURSOR_CROSS,
	PVP_DISABLED: Input.CURSOR_CROSS,
	PVP_ENABLED: Input.CURSOR_CROSS,
	FORBIDDEN: Input.CURSOR_FORBIDDEN,
	ZOOM_IN: Input.CURSOR_CROSS,
	ZOOM_OUT: Input.CURSOR_CROSS,
	MOVE: Input.CURSOR_MOVE,
	CHAT: Input.CURSOR_IBEAM,
	HELP: Input.CURSOR_HELP,
	TEXT: Input.CURSOR_IBEAM,
}

var current_mode: StringName = DEFAULT
var _cursor_textures: Dictionary = {}


func _ready() -> void:
	_load_cursor_textures()
	_register_standard_shapes()
	set_cursor_mode(DEFAULT)


func _exit_tree() -> void:
	# Input retiene las texturas de los cursores personalizados. Soltarlas antes
	# de destruir RenderingServer evita fugas y errores de ImageTexture al salir.
	for shape in CURSOR_SHAPES.values():
		Input.set_custom_mouse_cursor(null, shape)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_BUSY)
	_cursor_textures.clear()


func set_cursor_mode(mode: StringName) -> void:
	if not CURSOR_PATHS.has(mode):
		push_warning("Modo de cursor desconocido: %s" % mode)
		mode = DEFAULT
	current_mode = mode
	var shape: Input.CursorShape = CURSOR_SHAPES.get(mode, Input.CURSOR_ARROW)
	_set_shape(mode, shape)
	Input.set_default_cursor_shape(shape)
	cursor_mode_changed.emit(current_mode)


func reset_cursor() -> void:
	set_cursor_mode(DEFAULT)


func get_available_modes() -> Array[StringName]:
	var modes: Array[StringName] = []
	for mode: StringName in CURSOR_PATHS:
		modes.append(mode)
	return modes


func get_cursor_texture(mode: StringName) -> Texture2D:
	return _cursor_textures.get(mode, _cursor_textures.get(DEFAULT)) as Texture2D


func _load_cursor_textures() -> void:
	for mode: StringName in CURSOR_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(CURSOR_PATHS[mode]))
		if image == null or image.is_empty():
			push_warning("No se pudo cargar el cursor: %s" % CURSOR_PATHS[mode])
			continue
		image.resize(CURSOR_PIXEL_SIZE, CURSOR_PIXEL_SIZE, Image.INTERPOLATE_LANCZOS)
		_cursor_textures[mode] = ImageTexture.create_from_image(image)


func _register_standard_shapes() -> void:
	_set_shape(DEFAULT, Input.CURSOR_ARROW)
	_set_shape(POINTING_HAND, Input.CURSOR_POINTING_HAND)
	_set_shape(WAIT, Input.CURSOR_WAIT)
	_set_shape(WAIT, Input.CURSOR_BUSY)
	_set_shape(GRAB, Input.CURSOR_DRAG)
	_set_shape(GRABBING, Input.CURSOR_CAN_DROP)
	_set_shape(ATTACK, Input.CURSOR_CROSS)
	_set_shape(FORBIDDEN, Input.CURSOR_FORBIDDEN)
	_set_shape(MOVE, Input.CURSOR_MOVE)
	_set_shape(HELP, Input.CURSOR_HELP)
	_set_shape(TEXT, Input.CURSOR_IBEAM)


func _set_shape(mode: StringName, shape: Input.CursorShape) -> void:
	var texture := get_cursor_texture(mode)
	if texture != null:
		var hotspot := Vector2(HOTSPOTS[mode]) * (float(CURSOR_PIXEL_SIZE) / SOURCE_CURSOR_SIZE)
		Input.set_custom_mouse_cursor(texture, shape, hotspot)
