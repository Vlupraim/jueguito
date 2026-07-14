extends SceneTree

const DOCK_SCRIPT := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Build only the UI so this smoke test does not scan every exported sector.
	var dock: Control = DOCK_SCRIPT.new()
	dock.call("_build_ui")

	var map_view: Control = dock.get("map_view")
	var content_split: VSplitContainer = dock.get("content_split")
	assert(map_view != null)
	assert(content_split != null)
	assert(content_split.get_child_count() == 2)
	assert(content_split.get_child(0) == map_view)
	assert(map_view.custom_minimum_size == Vector2(260.0, 146.0))
	assert(map_view.size_flags_vertical == Control.SIZE_EXPAND_FILL)
	map_view.size = Vector2(400.0, 300.0)

	dock.set("map_zoom", 2.0)
	dock.set("map_pan", Vector2(100000.0, -100000.0))
	dock.call("_clamp_map_pan")
	var base_rect: Rect2 = dock.call("_base_map_content_rect")
	var zoomed_size := base_rect.size * 2.0
	var expected_limit := Vector2(
		maxf(0.0, (zoomed_size.x - map_view.size.x) * 0.5),
		maxf(0.0, (zoomed_size.y - map_view.size.y) * 0.5)
	)
	var bounded_pan: Vector2 = dock.get("map_pan")
	assert(is_equal_approx(bounded_pan.x, expected_limit.x))
	assert(is_equal_approx(bounded_pan.y, -expected_limit.y))

	dock.set("map_zoom", 1.0)
	dock.set("map_pan", Vector2(100000.0, -100000.0))
	dock.call("_clamp_map_pan")
	assert((dock.get("map_pan") as Vector2).is_zero_approx())

	print("TERRAIN_MAP_DOCK_LAYOUT_OK view=", map_view.size, " limit=", expected_limit)
	dock.free()
	quit()
