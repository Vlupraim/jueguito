extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")
const OUTPUT_DIR := "res://tmp/audit_20260913"


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

	await get_tree().create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	_save_viewport("gameplay_current.png")
	_audit_water(world)
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


func _audit_water(world: Node) -> void:
	var ocean: OceanWater = world.get("ocean_water")
	var terrain: Terrain3D = world.get("terrain")
	var sampled := 0
	var mismatch := 0
	var wet := 0
	var dry_on_map_wet_in_world := 0
	for y in range(64):
		for x in range(64):
			var uv := Vector2((x + 0.5) / 64.0, (y + 0.5) / 64.0)
			var p := ocean.sector_bounds.position + uv * ocean.sector_bounds.size
			var position := Vector3(p.x, 0.0, p.y)
			var h := terrain.data.get_height(position)
			if is_nan(h):
				continue
			var info := ocean.get_water_info(position, h)
			var world_water := bool(info.get("in_water", false))
			var map_water := int(ocean.call("_surface_kind_at_uv", uv)) != 0
			sampled += 1
			if world_water:
				wet += 1
			if world_water != map_water:
				mismatch += 1
				if world_water:
					dry_on_map_wet_in_world += 1
	var started := Time.get_ticks_usec()
	ocean.configure_for_sector(ocean.current_sector, terrain)
	var result := {
		"sample_grid": "64x64, cell centers, original map source before artistic smoothing",
		"valid_samples": sampled,
		"world_water_samples": wet,
		"source_map_disagreements": mismatch,
		"source_dry_world_wet": dry_on_map_wet_in_world,
		"sector_bounds": str(ocean.sector_bounds),
		"water_level": ocean.water_level,
		"water_cells": ocean.water_cell_count,
		"water_triangles": ocean.water_cell_count * 2,
		"water_collision_shapes": ocean.water_collision_shape_count,
		"warm_reconfigure_ms": (Time.get_ticks_usec() - started) / 1000.0,
	}
	var file := FileAccess.open(OUTPUT_DIR.path_join("water_audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("WATER_AUDIT ", JSON.stringify(result))
