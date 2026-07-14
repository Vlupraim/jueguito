extends SceneTree

const PREVIEW_SCRIPT := preload("res://scripts/terrain3d_walk_preview.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var preview: Node3D = PREVIEW_SCRIPT.new()
	preview.set("current_sector", Vector2i(14, 6))
	preview.set("available_sectors", {"14,6": Vector2i(14, 6)})
	preview.call("_setup_minimap")

	var minimap: Control = preview.get("minimap")
	assert(minimap != null)
	minimap.size = Vector2(300.0, 169.0)
	assert(preview.get("sector_x_spin") != null)
	assert(preview.get("sector_y_spin") != null)

	preview.set("minimap_zoom", 4.0)
	preview.set("minimap_center_px", Vector2(836.0, 470.5))
	preview.call("_clamp_minimap_center")
	var source_rect: Rect2 = preview.call("_minimap_source_rect")
	assert(source_rect.position.x >= 0.0 and source_rect.position.y >= 0.0)
	assert(source_rect.end.x <= 1672.0 and source_rect.end.y <= 941.0)

	var center_sector: Vector2i = preview.call("_minimap_sector_at_position", minimap.size * 0.5)
	assert(center_sector == Vector2i(33, 18))

	preview.set("minimap_center_px", Vector2(-100000.0, 100000.0))
	preview.call("_clamp_minimap_center")
	source_rect = preview.call("_minimap_source_rect")
	assert(source_rect.position.is_zero_approx() == false)
	assert(is_zero_approx(source_rect.position.x))
	assert(is_equal_approx(source_rect.end.y, 941.0))

	preview.call("_reset_minimap_view")
	source_rect = preview.call("_minimap_source_rect")
	assert(source_rect.position.is_zero_approx())
	assert(source_rect.size.is_equal_approx(Vector2(1672.0, 941.0)))

	print("TERRAIN3D_WALK_MINIMAP_OK center_sector=", center_sector, " source=", source_rect)
	preview.free()
	quit()
