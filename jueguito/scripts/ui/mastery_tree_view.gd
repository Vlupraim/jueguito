extends Control
class_name MasteryTreeView

signal mastery_selected(title: String, family: String, description: String)
signal zoom_changed(value: float)

const BOARD_SCENE := preload("res://scenes/ui/mastery/yggdrasil_board_v1.tscn")
const ROOT_POINT := Vector2(2500.0, 2750.0)
const MIN_ZOOM := 0.16
const MAX_ZOOM := 1.65

var zoom := 0.7
var _pan := Vector2.ZERO
var _board: Control
var _nodes: Array[Control] = []
var _dragging := false
var _drag_distance := 0.0
var _selected: Control
var _centered_on_root := true
var _last_view_size := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_board = BOARD_SCENE.instantiate()
	add_child(_board)
	for child in _board.get_children():
		if child is Control and child.has_meta("title"):
			_nodes.append(child)
	resized.connect(_on_resized)
	call_deferred("center_on_root")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			set_zoom(zoom * 1.15, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			set_zoom(zoom / 1.15, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed:
				_drag_distance = 0.0
			elif _drag_distance < 7.0:
				_select_at(button.position)
			mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if button.pressed else Control.CURSOR_DRAG
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_centered_on_root = false
			_pan += motion.relative
			_drag_distance += motion.relative.length()
			_clamp_pan()
			accept_event()
		else:
			var node := _node_at(motion.position)
			tooltip_text = String(node.get_meta("title")) if node != null else "Rueda: zoom · Arrastra: explorar el árbol"

func set_zoom(value: float, anchor := Vector2(-1.0, -1.0)) -> void:
	_centered_on_root = false
	if anchor.x < 0.0:
		anchor = size * 0.5
	var board_point := (anchor - _pan) / zoom
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_pan = anchor - board_point * zoom
	_clamp_pan()
	zoom_changed.emit(zoom)

func center_on_root() -> void:
	_centered_on_root = true
	_last_view_size = size
	zoom = minf(0.7, maxf(size.y / 1450.0, MIN_ZOOM))
	_pan = size * 0.5 - ROOT_POINT * zoom
	_clamp_pan()
	zoom_changed.emit(zoom)
	_select_node(_nodes[0])

func show_entire_tree() -> void:
	_centered_on_root = false
	zoom = clampf(minf(size.x, size.y) / 5100.0, MIN_ZOOM, MAX_ZOOM)
	_pan = (size - Vector2(5000.0, 5000.0) * zoom) * 0.5
	_clamp_pan()
	zoom_changed.emit(zoom)

func focus_family(family: String) -> void:
	_centered_on_root = false
	for node in _nodes:
		if String(node.get_meta("kind")) == "family" and String(node.get_meta("family")) == family:
			zoom = 0.75
			_pan = size * 0.5 - (node.position + node.size * 0.5) * zoom
			_clamp_pan()
			_select_node(node)
			zoom_changed.emit(zoom)
			return

func _on_resized() -> void:
	if _board == null:
		return
	if _centered_on_root:
		center_on_root()
	else:
		_pan += (size - _last_view_size) * 0.5
		_clamp_pan()
	_last_view_size = size

func _clamp_pan() -> void:
	if _board == null:
		return
	var scaled := _board.size * zoom
	for axis in range(2):
		if scaled[axis] <= size[axis]:
			_pan[axis] = (size[axis] - scaled[axis]) * 0.5
		else:
			_pan[axis] = clampf(_pan[axis], size[axis] - scaled[axis] - 80.0, 80.0)
	_board.position = _pan
	_board.scale = Vector2.ONE * zoom
	_update_labels()

func _update_labels() -> void:
	for node in _nodes:
		var label := node.get_node_or_null("Title") as Label
		if label == null:
			continue
		var kind := String(node.get_meta("kind"))
		label.visible = kind in ["root", "family"] or (kind == "group" and zoom >= 0.3) or zoom >= 0.48
		var minimum := 15.0 if kind in ["root", "family"] else 11.0
		var factor := maxf(1.0, minimum / (label.get_theme_font_size("font_size") * zoom))
		label.scale = Vector2.ONE * factor
		label.position = Vector2(node.size.x * 0.5 - label.size.x * factor * 0.5, node.size.y + 8.0)

func _node_at(point: Vector2) -> Control:
	var board_point := (point - _pan) / zoom
	for index in range(_nodes.size() - 1, -1, -1):
		var node := _nodes[index]
		if Rect2(node.position, node.size).grow(8.0).has_point(board_point):
			return node
	return null

func _select_at(point: Vector2) -> void:
	var node := _node_at(point)
	if node != null:
		_select_node(node)

func _select_node(node: Control) -> void:
	if _selected != null:
		_selected.get_node("Selection").hide()
	_selected = node
	node.get_node("Selection").show()
	mastery_selected.emit(String(node.get_meta("title")), String(node.get_meta("family")), String(node.get_meta("description")))
