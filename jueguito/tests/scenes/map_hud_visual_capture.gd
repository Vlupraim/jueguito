extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")
const OUTPUT_DIR := "res://docs/design/concepts/hud/asset_iterations"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	# El HUD se evalua en la resolucion objetivo del juego; a 1280 px los textos
	# del marco no representan el encuadre que vera el jugador con F5.
	get_window().size = Vector2i(1920, 1080)
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	for _frame in range(120):
		await get_tree().process_frame
		if world.get("local_minimap_texture") != null:
			break

	world.call("_toggle_local_map")
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("implemented_map_regional_v2.png")

	world.call("_toggle_world_map")
	world.call("_reset_world_map_view")
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("implemented_world_atlas_full_v2.png")
	world.call("_center_world_map_on_current_sector")
	await get_tree().process_frame
	var view_size: Vector2 = world.call("_world_map_view_size")
	var texture_rect: Rect2 = world.call("_world_map_texture_rect", view_size)
	var sector_center: Vector2 = world.call(
		"_world_map_sector_center", texture_rect, world.get("current_sector")
	)
	world.call("_select_world_map_sector_at", sector_center)
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("implemented_world_atlas_v2.png")
	get_tree().quit()


func _save_viewport(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("No se pudo guardar la captura %s" % file_name)
