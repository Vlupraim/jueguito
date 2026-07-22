@tool
extends Node3D

const OCEAN_SCENE := preload("res://scenes/world/water/ocean_water.tscn")

@export var show_preview := true:
	set(value):
		show_preview = value
		_schedule_refresh(0)

@export var sector := Vector2i(27, 30):
	set(value):
		sector = value
		_schedule_refresh(0)

@export var water_level := 2.0:
	set(value):
		water_level = value
		_schedule_refresh(0)

## Marca esta casilla para forzar una reconstruccion inmediata desde el Inspector.
@export var refresh_preview := false:
	set(value):
		refresh_preview = false
		if value:
			_schedule_refresh(0)

@export_range(100, 1200, 50) var brush_refresh_delay_ms := 350

var _terrain: Terrain3D
var _ocean: OceanWater
var _connected_data: Object
var _refresh_at_ms := -1
var _observed_source_signature := ""


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	set_process(true)
	call_deferred("_ensure_preview")


func _exit_tree() -> void:
	_disconnect_terrain_data()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _terrain == null or not is_instance_valid(_terrain):
		_ensure_preview()
		return
	_connect_terrain_data()
	var source_signature := _terrain_source_signature()
	if source_signature != _observed_source_signature:
		_observed_source_signature = source_signature
		_schedule_refresh(brush_refresh_delay_ms)
	if _refresh_at_ms >= 0 and Time.get_ticks_msec() >= _refresh_at_ms:
		_refresh_at_ms = -1
		_rebuild_preview()


func _ensure_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_terrain = get_parent().get_node_or_null("Importer") as Terrain3D
	if _terrain == null:
		_schedule_refresh(500)
		return
	_connect_terrain_data()
	if _ocean == null or not is_instance_valid(_ocean):
		_ocean = OCEAN_SCENE.instantiate() as OceanWater
		_ocean.name = "OceanWaterEditorPreview"
		add_child(_ocean)
	_schedule_refresh(100)


func _connect_terrain_data() -> void:
	if _terrain == null or _terrain.data == null or _connected_data == _terrain.data:
		return
	_disconnect_terrain_data()
	_connected_data = _terrain.data
	if _connected_data.has_signal("maps_edited"):
		_connected_data.connect("maps_edited", _on_terrain_maps_edited)


func _disconnect_terrain_data() -> void:
	if _connected_data != null and is_instance_valid(_connected_data):
		if _connected_data.has_signal("maps_edited") and _connected_data.is_connected("maps_edited", _on_terrain_maps_edited):
			_connected_data.disconnect("maps_edited", _on_terrain_maps_edited)
	_connected_data = null


func _on_terrain_maps_edited(_edited_aabb: AABB) -> void:
	_schedule_refresh(brush_refresh_delay_ms)


## El dock llama este metodo despues de terminar de cargar un sector. Hacerlo
## explicitamente evita reconstruir con el data_directory del sector anterior.
func refresh_for_sector(next_sector: Vector2i) -> void:
	sector = next_sector
	_observed_source_signature = _terrain_source_signature()
	_schedule_refresh(100)


func _schedule_refresh(delay_ms: int) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_refresh_at_ms = Time.get_ticks_msec() + maxi(delay_ms, 0)


func _rebuild_preview() -> void:
	if _ocean == null or _terrain == null:
		return
	_ocean.visible = show_preview
	if not show_preview:
		return
	_ocean.water_level = water_level
	_ocean.configure_for_sector(_sector_from_data_directory(), _terrain)


func _terrain_source_signature() -> String:
	if _terrain == null or not is_instance_valid(_terrain):
		return ""
	var data_id := 0
	if _terrain.data != null:
		data_id = _terrain.data.get_instance_id()
	return "%s|%d" % [String(_terrain.data_directory), data_id]


func _sector_from_data_directory() -> Vector2i:
	if _terrain == null:
		return sector
	var folder := String(_terrain.data_directory).trim_suffix("/").get_file()
	var parts := folder.split("_")
	if parts.size() == 3 and parts[0] == "sector":
		return Vector2i(int(parts[1]), int(parts[2]))
	return sector
