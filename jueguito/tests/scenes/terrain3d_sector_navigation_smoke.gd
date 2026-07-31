extends SceneTree

const DOCK_SCRIPT := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")
const SECTOR_27 := "res://data/terrain3d_edits/sector_27_30"
const SECTOR_28 := "res://data/terrain3d_edits/sector_28_30"

var terrain: Terrain3D
var camera: Camera3D
var dock


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	dock = DOCK_SCRIPT.new()
	terrain = Terrain3D.new()
	root.add_child(terrain)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	terrain.set_camera(camera)

	var sector_27_first := await _load_and_fingerprint(SECTOR_27)
	var sector_28 := await _load_and_fingerprint(SECTOR_28)
	var sector_27_second := await _load_and_fingerprint(SECTOR_27)

	if sector_27_first.is_empty() or sector_28.is_empty():
		_fail("Uno de los sectores no produjo datos Terrain3D activos.")
		return
	if sector_27_first == sector_28:
		_fail("Los sectores 27,30 y 28,30 producen el mismo Terrain3D visible.")
		return
	if sector_27_first != sector_27_second:
		_fail("Volver a 27,30 no restauro exactamente sus datos anteriores.")
		return

	terrain.free()
	camera.free()
	dock.free()
	await process_frame
	print("PASS: Terrain3D navega 27,30 -> 28,30 -> 27,30 con datos visuales distintos y restaurables.")
	quit(0)


func _load_and_fingerprint(directory: String) -> Array:
	terrain.data_directory = ""
	for region in terrain.data.get_regions_active().duplicate():
		terrain.data.remove_region(region, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	await process_frame
	terrain.data_directory = directory
	await process_frame
	await process_frame
	var fingerprint: Array = [directory, terrain.data.get_regions_active().size()]
	for z in [16.0, 128.0, 256.0, 384.0, 496.0]:
		for x in [16.0, 128.0, 256.0, 384.0, 496.0]:
			fingerprint.append(snappedf(float(terrain.data.get_height(Vector3(x, 0.0, z))), 0.001))
	# La ruta no debe decidir la comparacion visual; se retira tras confirmar que
	# el setter nativo termino apuntando al directorio solicitado.
	if terrain.data_directory != directory:
		return []
	if not bool(dock.call("_terrain_data_matches_directory", terrain, directory)):
		return []
	fingerprint.remove_at(0)
	return fingerprint


func _fail(message: String) -> void:
	push_error(message)
	if terrain != null:
		terrain.free()
	if camera != null:
		camera.free()
	if dock != null:
		dock.free()
	quit(1)
