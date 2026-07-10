@tool
extends SceneTree

const NORMALIZER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_heightmap_normalizer.gd")


func _initialize() -> void:
	var image := Image.create(9, 9, false, Image.FORMAT_RF)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var height := 0.0 if x < 4 else 20.0
			image.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	var before := _max_adjacent_delta(image)
	var normalizer: RefCounted = NORMALIZER_SCRIPT.new()
	var result: Dictionary = normalizer.call("process_height_map", image, {
		"mode": NORMALIZER_SCRIPT.MODE_REPAIR_CUTS,
		"iterations": 8,
		"strength": 1.0,
		"max_step": 1.5,
		"preserve_outer_edges": false,
		"allow_intentional_cuts": false,
		"repair_radius": 8,
		"limit_radius": 4,
		"smooth_radius": 3,
		"strict_passes": 12,
		"target_step_factor": 0.45,
	})
	var after := _max_adjacent_delta(image)
	if not bool(result.get("ok", false)) or int(result.get("pixels", 0)) <= 0:
		printerr("Heightmap normalizer validation failed: no pixels touched.")
		quit(1)
		return
	if after >= before:
		printerr("Heightmap normalizer validation failed: cut was not reduced.")
		quit(1)
		return
	if after > 0.75:
		printerr("Heightmap normalizer validation failed: strict repair left a visible step. max_delta=", after)
		quit(1)
		return
	print("Heightmap normalizer validation OK. max_delta ", before, " -> ", after)
	quit(0)


func _max_adjacent_delta(image: Image) -> float:
	var max_delta := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width() - 1):
			max_delta = maxf(max_delta, absf(image.get_pixel(x, y).r - image.get_pixel(x + 1, y).r))
	for y in range(image.get_height() - 1):
		for x in range(image.get_width()):
			max_delta = maxf(max_delta, absf(image.get_pixel(x, y).r - image.get_pixel(x, y + 1).r))
	return max_delta
