extends Control
class_name EditableHUDModule

@export var layout_key := "module"
@export var default_normalized_position := Vector2.ZERO
@export var default_position_offset := Vector2.ZERO
@export_range(0.45, 1.6, 0.05) var default_module_scale := 1.0

var edit_mode := false
var _dragging := false
var _resizing := false
var _drag_offset := Vector2.ZERO
var _resize_start_mouse := Vector2.ZERO
var _resize_start_scale := 1.0
var _edit_overlay: Node2D

const RESIZE_HANDLE_SIZE := 22.0
const MIN_MODULE_SCALE := 0.45
const MAX_MODULE_SCALE := 1.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_edit_overlay = Node2D.new()
	_edit_overlay.name = "HUDResizeOverlay"
	_edit_overlay.z_index = 100
	_edit_overlay.draw.connect(_draw_edit_overlay)
	add_child(_edit_overlay)
	call_deferred("_load_layout")


func set_edit_mode(enabled: bool) -> void:
	edit_mode = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_DRAG if enabled else Control.CURSOR_ARROW
	modulate = Color(1.08, 1.02, 0.84, 1.0) if enabled else Color.WHITE
	tooltip_text = "Arrastra para mover. Usa el tirador inferior derecho para escalar." if enabled else ""
	if _edit_overlay != null:
		_edit_overlay.visible = enabled
		_edit_overlay.queue_redraw()


func set_module_scale(value: float) -> void:
	var next_scale := clampf(value, MIN_MODULE_SCALE, MAX_MODULE_SCALE)
	scale = Vector2.ONE * next_scale
	SettingsManager.set_setting("hud", "%s_scale" % layout_key, next_scale, false)
	_clamp_to_viewport()
	if _edit_overlay != null:
		_edit_overlay.queue_redraw()


func reset_layout() -> void:
	scale = Vector2.ONE * default_module_scale
	_place_from_normalized(default_normalized_position, true)
	_save_layout()


func _gui_input(event: InputEvent) -> void:
	if not edit_mode:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if _resize_handle_rect().has_point(button.position):
					_resizing = true
					_dragging = false
					mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
					_resize_start_mouse = get_global_mouse_position()
					_resize_start_scale = scale.x
				else:
					_dragging = true
					_resizing = false
					mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
					_drag_offset = button.position
			else:
				_dragging = false
				_resizing = false
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if not button.pressed:
				_save_layout()
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_module_scale(scale.x + 0.05)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_module_scale(scale.x - 0.05)
			accept_event()
	elif event is InputEventMouseMotion and not _resizing and not _dragging:
		mouse_default_cursor_shape = (
			Control.CURSOR_FDIAGSIZE
			if _resize_handle_rect().has_point((event as InputEventMouseMotion).position)
			else Control.CURSOR_DRAG
		)
	elif event is InputEventMouseMotion and _resizing:
		var resize_delta := get_global_mouse_position() - _resize_start_mouse
		var reference_size := maxf(size.x, size.y)
		var proportional_delta := (resize_delta.x + resize_delta.y) * 0.5 / maxf(reference_size, 1.0)
		set_module_scale(_resize_start_scale + proportional_delta)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		global_position += motion.position - _drag_offset
		_clamp_to_viewport()
		accept_event()


func _load_layout() -> void:
	var stored_position: Variant = SettingsManager.get_setting(
		"hud", "%s_position" % layout_key, default_normalized_position
	)
	var stored_scale := float(SettingsManager.get_setting(
		"hud", "%s_scale" % layout_key, default_module_scale
	))
	scale = Vector2.ONE * clampf(stored_scale, MIN_MODULE_SCALE, MAX_MODULE_SCALE)
	var normalized: Vector2 = stored_position if stored_position is Vector2 else default_normalized_position
	_place_from_normalized(normalized, normalized == default_normalized_position)
	set_edit_mode(false)


func _place_from_normalized(normalized: Vector2, apply_default_offset := false) -> void:
	var viewport_size := get_viewport_rect().size
	var available := Vector2(
		maxf(viewport_size.x - size.x * scale.x, 0.0),
		maxf(viewport_size.y - size.y * scale.y, 0.0)
	)
	global_position = Vector2(
		clampf(normalized.x, 0.0, 1.0) * available.x,
		clampf(normalized.y, 0.0, 1.0) * available.y
	)
	if apply_default_offset:
		global_position += default_position_offset
	_clamp_to_viewport()


func _normalized_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var available := Vector2(
		maxf(viewport_size.x - size.x * scale.x, 1.0),
		maxf(viewport_size.y - size.y * scale.y, 1.0)
	)
	return Vector2(
		clampf(global_position.x / available.x, 0.0, 1.0),
		clampf(global_position.y / available.y, 0.0, 1.0)
	)


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	global_position.x = clampf(global_position.x, 0.0, maxf(viewport_size.x - size.x * scale.x, 0.0))
	global_position.y = clampf(global_position.y, 0.0, maxf(viewport_size.y - size.y * scale.y, 0.0))


func _save_layout() -> void:
	SettingsManager.set_setting("hud", "%s_position" % layout_key, _normalized_position(), false)
	SettingsManager.set_setting("hud", "%s_scale" % layout_key, scale.x, false)
	SettingsManager.save_settings()


func _resize_handle_rect() -> Rect2:
	return Rect2(
		Vector2(maxf(size.x - RESIZE_HANDLE_SIZE, 0.0), maxf(size.y - RESIZE_HANDLE_SIZE, 0.0)),
		Vector2.ONE * RESIZE_HANDLE_SIZE
	)


func _draw_edit_overlay() -> void:
	if not edit_mode:
		return
	var outline := Rect2(Vector2(1.0, 1.0), Vector2(maxf(size.x - 2.0, 1.0), maxf(size.y - 2.0, 1.0)))
	_edit_overlay.draw_rect(outline, Color("f2d47a"), false, 2.0)
	_edit_overlay.draw_rect(_resize_handle_rect(), Color("231f17e8"), true)
	_edit_overlay.draw_rect(_resize_handle_rect(), Color("fff0b0"), false, 2.0)
	var handle := _resize_handle_rect()
	for offset in [6.0, 11.0, 16.0]:
		_edit_overlay.draw_line(
			handle.position + Vector2(offset, handle.size.y - 3.0),
			handle.position + Vector2(handle.size.x - 3.0, offset),
			Color("d9bc67"),
			1.0
		)
	var scale_caption := "%d%%" % roundi(scale.x * 100.0)
	_edit_overlay.draw_rect(Rect2(Vector2(4.0, 4.0), Vector2(48.0, 20.0)), Color("17140ee8"), true)
	_edit_overlay.draw_string(
		ThemeDB.fallback_font,
		Vector2(9.0, 18.0),
		scale_caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		42.0,
		11,
		Color("fff0b0")
	)
