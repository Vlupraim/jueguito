@tool
extends Node3D

@export var origin_sector := Vector2i(33, 19):
	set(value):
		origin_sector = value
		_request_rebuild()

@export_range(1, 5, 1) var guide_radius := 2:
	set(value):
		guide_radius = value
		_request_rebuild()

@export var sector_size_meters := 5000.0:
	set(value):
		sector_size_meters = maxf(100.0, value)
		_request_rebuild()

@export var grid_height := 32.0:
	set(value):
		grid_height = value
		_request_rebuild()

@export var label_height := 240.0:
	set(value):
		label_height = value
		_request_rebuild()

@export var show_sector_labels := true:
	set(value):
		show_sector_labels = value
		_request_rebuild()

@export var show_direction_labels := true:
	set(value):
		show_direction_labels = value
		_request_rebuild()


func _ready() -> void:
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		call_deferred("_rebuild")


func _rebuild() -> void:
	_clear_generated()
	_build_grid()
	if show_sector_labels:
		_build_sector_labels()
	if show_direction_labels:
		_build_direction_labels()


func _clear_generated() -> void:
	for child in get_children():
		child.queue_free()


func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var half_size := sector_size_meters * 0.5
	for offset_z in range(-guide_radius, guide_radius + 1):
		for offset_x in range(-guide_radius, guide_radius + 1):
			var center := Vector2(float(offset_x) * sector_size_meters, float(offset_z) * sector_size_meters)
			var min_x := center.x - half_size
			var max_x := center.x + half_size
			var min_z := center.y - half_size
			var max_z := center.y + half_size
			var color := Color(0.92, 0.92, 0.86, 0.56)
			if offset_x == 0 and offset_z == 0:
				color = Color(1.0, 0.78, 0.20, 0.95)
			_add_line(mesh, Vector3(min_x, grid_height, min_z), Vector3(max_x, grid_height, min_z), color)
			_add_line(mesh, Vector3(max_x, grid_height, min_z), Vector3(max_x, grid_height, max_z), color)
			_add_line(mesh, Vector3(max_x, grid_height, max_z), Vector3(min_x, grid_height, max_z), color)
			_add_line(mesh, Vector3(min_x, grid_height, max_z), Vector3(min_x, grid_height, min_z), color)

			if offset_x == 0 and offset_z == 0:
				_add_line(mesh, Vector3(min_x, grid_height + 8.0, center.y), Vector3(max_x, grid_height + 8.0, center.y), color)
				_add_line(mesh, Vector3(center.x, grid_height + 8.0, min_z), Vector3(center.x, grid_height + 8.0, max_z), color)

	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.name = "SectorGuideGrid"
	grid.mesh = mesh
	grid.material_override = _make_line_material()
	add_child(grid)


func _add_line(mesh: ImmediateMesh, from: Vector3, to: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)


func _build_sector_labels() -> void:
	for offset_z in range(-guide_radius, guide_radius + 1):
		for offset_x in range(-guide_radius, guide_radius + 1):
			var sector := origin_sector + Vector2i(offset_x, offset_z)
			var local_position := Vector3(float(offset_x) * sector_size_meters, label_height, float(offset_z) * sector_size_meters)
			var import_position := Vector2i(int(offset_x * sector_size_meters), int(offset_z * sector_size_meters))
			var label_text := "[" + str(sector.x) + ", " + str(sector.y) + "]\nImport " + str(import_position.x) + ", " + str(import_position.y)
			if offset_x == 0 and offset_z == 0:
				label_text = "ACTUAL\n" + label_text
			_add_label(label_text, local_position, Color(1.0, 0.84, 0.28, 1.0) if offset_x == 0 and offset_z == 0 else Color(0.95, 0.96, 0.90, 0.88), 72)


func _build_direction_labels() -> void:
	var distance := (float(guide_radius) + 0.78) * sector_size_meters
	_add_label("NORTE\n-Z", Vector3(0.0, label_height * 1.35, -distance), Color(0.50, 0.74, 1.0, 1.0), 94)
	_add_label("SUR\n+Z", Vector3(0.0, label_height * 1.35, distance), Color(0.50, 0.74, 1.0, 1.0), 94)
	_add_label("OESTE\n-X", Vector3(-distance, label_height * 1.35, 0.0), Color(0.50, 1.0, 0.66, 1.0), 94)
	_add_label("ESTE\n+X", Vector3(distance, label_height * 1.35, 0.0), Color(0.50, 1.0, 0.66, 1.0), 94)


func _add_label(text: String, position: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = "SectorGuideLabel"
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 1.7
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.02, 0.02, 0.02, 0.92)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make_line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material
