extends Control
class_name MasteryTreeView

signal mastery_selected(title: String, family: String, description: String)

const FAMILY_DATA := [
	{
		"name": "MARCIALES", "color": Color("d36a5d"),
		"groups": {
			"Armas": ["Espadas", "Arcos", "Armas de asta", "Hachas", "Dagas"],
			"Protección": ["Escudos", "Tela", "Cuero", "Metal"],
		},
	},
	{
		"name": "MUNDO", "color": Color("70c7a2"),
		"groups": {
			"Recolección": ["Silvicultura", "Minería", "Botánica", "Caza", "Pesca"],
			"Aventura": ["Exploración", "Supervivencia", "Navegación", "Rastreo"],
			"Domadura": ["Captura", "Crianza", "Entrenamiento"],
		},
	},
	{
		"name": "OFICIO", "color": Color("d3a85c"),
		"groups": {
			"Refinado": ["Carpintería", "Metalurgia", "Curtiduría", "Textilería"],
			"Fabricación": ["Herrería", "Arquería", "Sastrería", "Construcción naval", "Alquimia"],
			"Servicios": ["Reparación", "Encantamiento", "Calidad"],
		},
	},
	{
		"name": "INFLUENCIA", "color": Color("8d86d6"),
		"groups": {
			"Comercio": ["Transporte", "Contratos", "Tasación"],
			"Espionaje": ["Observación", "Infiltración", "Falsificación", "Sabotaje"],
			"Liderazgo": ["Mando", "Diplomacia", "Gobierno", "Moral"],
		},
	},
]

const TUTORIAL_MASTERIES := {
	"Espadas": true, "Arcos": true, "Tela": true, "Cuero": true,
	"Silvicultura": true, "Carpintería": true, "Reparación": true,
	"Exploración": true, "Navegación": true,
}

var _hit_nodes: Array[Dictionary] = []
var _hovered := ""
var _selected := "Exploración"
var _dragging := false
var _drag_distance := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(1500.0, 820.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			var scroll := get_parent() as ScrollContainer
			if scroll != null:
				scroll.scroll_horizontal -= int(motion.relative.x)
				scroll.scroll_vertical -= int(motion.relative.y)
			_drag_distance += motion.relative.length()
			accept_event()
			return
		var next_hovered := _node_at(motion.position)
		if next_hovered != _hovered:
			_hovered = next_hovered
			queue_redraw()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_distance = 0.0
				accept_event()
				return
			_dragging = false
			if _drag_distance >= 7.0:
				accept_event()
				return
			var node_name := _node_at(button.position)
			if not node_name.is_empty():
				_selected = node_name
				var data := _node_data(node_name)
				mastery_selected.emit(
					node_name,
					String(data.get("family", "Maestría")),
					String(data.get("description", "Progreso aún no iniciado."))
				)
				queue_redraw()
				accept_event()


func _draw() -> void:
	_hit_nodes.clear()
	var root := Vector2(size.x * 0.5, size.y - 72.0)
	_draw_connection(root, root + Vector2(0, -72), Color("c8b277"), 5.0)
	_draw_node(root, "MAESTRÍAS", Color("d9bf76"), 29.0, "Sistema", true)
	var family_x: Array[float] = [170.0, 550.0, 950.0, 1330.0]
	for family_index in range(FAMILY_DATA.size()):
		var family: Dictionary = FAMILY_DATA[family_index]
		var color: Color = family["color"]
		var hub := Vector2(family_x[family_index], 570.0 if family_index in [0, 3] else 520.0)
		_draw_curve(root + Vector2(0, -25), hub, color.darkened(0.18), 4.0)
		_draw_node(hub, String(family["name"]), color, 25.0, String(family["name"]), true)
		var groups: Dictionary = family["groups"]
		var group_names := groups.keys()
		var region_left: float = family_x[family_index] - 150.0
		var region_width := 300.0
		for group_index in range(group_names.size()):
			var group_name := String(group_names[group_index])
			var group_x: float = region_left + region_width * (float(group_index) + 0.5) / float(group_names.size())
			var group_pos := Vector2(group_x, 370.0)
			_draw_curve(hub, group_pos, color.darkened(0.3), 2.5)
			_draw_node(group_pos, group_name, color.lightened(0.08), 19.0, String(family["name"]), false)
			var leaves: Array = groups[group_name]
			var leaf_span := region_width / float(group_names.size())
			var leaf_columns := mini(3, leaves.size())
			for leaf_index in range(leaves.size()):
				var leaf_name := String(leaves[leaf_index])
				var leaf_column := leaf_index % leaf_columns
				var leaf_row := leaf_index / leaf_columns
				var leaf_x: float = group_x - leaf_span * 0.38 + leaf_span * 0.76 * (
					(float(leaf_column) + 0.5) / float(leaf_columns)
				)
				var leaf_y := 125.0 + float(leaf_row) * 92.0
				var leaf_pos := Vector2(leaf_x, leaf_y)
				_draw_curve(group_pos, leaf_pos, color.darkened(0.42), 1.5)
				_draw_node(
					leaf_pos, leaf_name, color, 13.0, String(family["name"]),
					TUTORIAL_MASTERIES.has(leaf_name)
				)


func _draw_node(
		position: Vector2,
		title: String,
		color: Color,
		radius: float,
		family: String,
		highlighted: bool
	) -> void:
	var active := title == _selected or title == _hovered
	var fill := Color("12181dcc") if not highlighted else color.darkened(0.62)
	if active:
		fill = color.darkened(0.35)
	draw_circle(position, radius + (4.0 if active else 0.0), Color(color, 0.22))
	draw_circle(position, radius, fill)
	draw_arc(position, radius, 0.0, TAU, 40, color if highlighted or active else color.darkened(0.45), 2.5, true)
	var font := get_theme_default_font()
	var font_size := 12 if radius >= 19.0 else 10
	var display_title := title if title.length() <= 13 else title.left(12) + "…"
	if radius <= 13.0:
		var symbol := title.left(1).to_upper()
		var symbol_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		draw_string(
			font, position + Vector2(-symbol_size.x * 0.5, 3.5), symbol,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color("eadfcb") if highlighted else Color("777f82")
		)
		if active:
			var active_size := font.get_string_size(display_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			draw_string(
				font, position + Vector2(-active_size.x * 0.5, radius + 17.0),
				display_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f3e9d3")
			)
	else:
		var text_size := font.get_string_size(display_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			position + Vector2(-text_size.x * 0.5, radius + 17.0),
			display_title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color("ede4d1") if highlighted or active else Color("8b9295")
		)
	_hit_nodes.append({
		"name": title,
		"family": family,
		"rect": Rect2(position - Vector2.ONE * (radius + 10.0), Vector2.ONE * (radius + 10.0) * 2.0),
		"description": (
			"Maestría visible durante el tutorial. Sus rangos y Legados se desbloquearán con práctica significativa."
			if highlighted else
			"Rama planificada del Árbol de Maestrías. Progreso y efectos pendientes de implementación."
		),
	})


func _draw_connection(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)


func _draw_curve(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var control := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - 45.0)
	for index in range(17):
		var t := float(index) / 16.0
		points.append(
			(1.0 - t) * (1.0 - t) * from
			+ 2.0 * (1.0 - t) * t * control
			+ t * t * to
		)
	draw_polyline(points, color, width, true)


func _node_at(point: Vector2) -> String:
	for index in range(_hit_nodes.size() - 1, -1, -1):
		if (_hit_nodes[index]["rect"] as Rect2).has_point(point):
			return String(_hit_nodes[index]["name"])
	return ""


func _node_data(node_name: String) -> Dictionary:
	for data in _hit_nodes:
		if String(data["name"]) == node_name:
			return data
	return {}
