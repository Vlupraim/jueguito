@tool
extends RefCounted

const MODE_SMOOTH := "smooth"
const MODE_REPAIR_CUTS := "repair_cuts"

const DEFAULT_ITERATIONS := 3
const DEFAULT_STRENGTH := 0.55
const DEFAULT_MAX_STEP_METERS := 1.5
const DEFAULT_SEAM_BAND := 4
const DEFAULT_REPAIR_MASK_RADIUS := 22
const DEFAULT_REPAIR_SMOOTH_RADIUS := 4
const DEFAULT_LIMIT_MASK_RADIUS := 4
const DEFAULT_STRICT_REPAIR_PASSES := 12
const DEFAULT_TARGET_STEP_FACTOR := 0.45
const DEFAULT_INTENTIONAL_CUT_MULTIPLIER := 4.0


func process_terrain_data(terrain_data: Object, options: Dictionary = {}) -> Dictionary:
	if terrain_data == null:
		return {"ok": false, "message": "No hay Terrain3DData para normalizar."}
	if not terrain_data.has_method("get_regions_active"):
		return {"ok": false, "message": "El Terrain3DData no expone regiones activas."}

	var regions: Array = terrain_data.call("get_regions_active")
	if regions.is_empty():
		return {"ok": false, "message": "No hay regiones Terrain3D activas."}

	var region_map: Dictionary = {}
	var changed_locations: Dictionary = {}
	var touched_pixels := 0
	for region_value in regions:
		var region := region_value as Terrain3DRegion
		if region == null:
			continue
		region_map[region.location] = region
		var height_map := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
		if not _is_valid_height_map(height_map):
			continue

		var image_result := process_height_map(height_map, options)
		var image_pixels := int(image_result.get("pixels", 0))
		if image_pixels > 0:
			touched_pixels += image_pixels
			changed_locations[region.location] = true

	if bool(options.get("repair_seams", true)):
		touched_pixels += _repair_region_seams(region_map, changed_locations, options)

	if changed_locations.is_empty():
		var mode := str(options.get("mode", MODE_REPAIR_CUTS))
		var message := "No encontre cortes sobre el umbral configurado." if mode == MODE_REPAIR_CUTS else "No encontre pixeles que suavizar."
		return {"ok": false, "message": message}

	for location in changed_locations.keys():
		var changed_region := region_map.get(location, null) as Terrain3DRegion
		if changed_region == null:
			continue
		changed_region.modified = true
		changed_region.edited = true
		changed_region.calc_height_range()
		if terrain_data.has_method("set_region_modified"):
			terrain_data.call("set_region_modified", changed_region.location, true)

	if terrain_data.has_method("calc_height_range"):
		terrain_data.call("calc_height_range", true)
	if terrain_data.has_method("update_maps"):
		terrain_data.call("update_maps", Terrain3DRegion.TYPE_HEIGHT, true, false)

	return {
		"ok": true,
		"regions": changed_locations.size(),
		"pixels": touched_pixels,
	}


func process_height_map(height_map: Image, options: Dictionary = {}) -> Dictionary:
	if not _is_valid_height_map(height_map):
		return {"ok": false, "message": "Heightmap invalido.", "pixels": 0}
	var mode := str(options.get("mode", MODE_REPAIR_CUTS))
	var pixels := 0
	match mode:
		MODE_SMOOTH:
			pixels = smooth_height_map(height_map, options)
		_:
			pixels = repair_height_map(height_map, options)
	return {"ok": pixels > 0, "pixels": pixels}


func smooth_height_map(height_map: Image, options: Dictionary = {}) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	if width < 3 or height < 3:
		return 0

	var iterations := _iterations(options)
	var strength := _strength(options)
	var preserve_outer_edges := bool(options.get("preserve_outer_edges", true))
	var min_x := 1 if preserve_outer_edges else 0
	var min_y := 1 if preserve_outer_edges else 0
	var max_x := width - 2 if preserve_outer_edges else width - 1
	var max_y := height - 2 if preserve_outer_edges else height - 1
	var changed_pixels := 0
	for _iteration in range(iterations):
		var source: Image = height_map.duplicate()
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var current: float = source.get_pixel(x, y).r
				var total := current * 2.0
				var weight := 2.0
				for sample_y in range(maxi(0, y - 1), mini(height - 1, y + 1) + 1):
					for sample_x in range(maxi(0, x - 1), mini(width - 1, x + 1) + 1):
						if sample_x == x and sample_y == y:
							continue
						total += source.get_pixel(sample_x, sample_y).r
						weight += 1.0
				var smoothed := lerpf(current, total / weight, strength)
				if _set_height_if_changed(height_map, x, y, current, smoothed):
					changed_pixels += 1
	return changed_pixels


func repair_height_map(height_map: Image, options: Dictionary = {}) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	if width < 3 or height < 3:
		return 0

	var cut_mask := _build_cut_mask(height_map, options)
	if not _mask_has_pixels(cut_mask):
		return 0

	var repair_mask := _expand_mask(cut_mask, width, height, _repair_mask_radius(options))
	var limit_mask := _expand_mask(cut_mask, width, height, _limit_mask_radius(options))
	var repair_indices := _mask_indices(repair_mask)
	var limit_indices := _mask_indices(limit_mask)
	var iterations := _strict_repair_passes(options)
	var changed_pixels := 0
	for _iteration in range(iterations):
		changed_pixels += _smooth_masked_area(height_map, repair_mask, options, repair_indices)
		changed_pixels += _limit_masked_adjacent_steps(height_map, limit_mask, options, limit_indices)
	for _final_pass in range(2):
		changed_pixels += _limit_masked_adjacent_steps(height_map, limit_mask, options, limit_indices)
	return changed_pixels


func _build_repair_mask(height_map: Image, options: Dictionary) -> PackedByteArray:
	var width := height_map.get_width()
	var height := height_map.get_height()
	return _expand_mask(_build_cut_mask(height_map, options), width, height, _repair_mask_radius(options))


func _build_cut_mask(height_map: Image, options: Dictionary) -> PackedByteArray:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	var threshold := _max_step(options)
	for y in range(height):
		for x in range(width - 1):
			var left: float = height_map.get_pixel(x, y).r
			var right: float = height_map.get_pixel(x + 1, y).r
			var delta := absf(left - right)
			if delta > threshold and not _is_intentional_cut(delta, threshold, options):
				mask[y * width + x] = 1
				mask[y * width + x + 1] = 1
	for y in range(height - 1):
		for x in range(width):
			var up: float = height_map.get_pixel(x, y).r
			var down: float = height_map.get_pixel(x, y + 1).r
			var delta := absf(up - down)
			if delta > threshold and not _is_intentional_cut(delta, threshold, options):
				mask[y * width + x] = 1
				mask[(y + 1) * width + x] = 1
	return mask


func _expand_mask(mask: PackedByteArray, width: int, height: int, radius: int) -> PackedByteArray:
	if radius <= 0:
		return mask
	var current := mask
	for _step in range(radius):
		var expanded := current.duplicate()
		for y in range(height):
			for x in range(width):
				if current[y * width + x] == 0:
					continue
				for offset_y in range(-1, 2):
					var sample_y := y + offset_y
					if sample_y < 0 or sample_y >= height:
						continue
					for offset_x in range(-1, 2):
						var sample_x := x + offset_x
						if sample_x < 0 or sample_x >= width:
							continue
						expanded[sample_y * width + sample_x] = 1
		current = expanded
	return current


func _smooth_masked_area(height_map: Image, mask: PackedByteArray, options: Dictionary, mask_indices: PackedInt32Array = PackedInt32Array()) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var source: Image = height_map.duplicate()
	var radius := _repair_smooth_radius(options)
	var strength := maxf(_strength(options), 0.95)
	var preserve_outer_edges := bool(options.get("preserve_outer_edges", true))
	var changed_pixels := 0
	var active_indices := mask_indices if not mask_indices.is_empty() else _mask_indices(mask)
	for index_value in active_indices:
		var index := int(index_value)
		var y := int(index / width)
		var x := index % width
		if not _can_modify_pixel(x, y, width, height, preserve_outer_edges):
			continue
		var current: float = source.get_pixel(x, y).r
		var total := current * 2.0
		var weight := 2.0
		for offset_y in range(-radius, radius + 1):
			var sample_y := clampi(y + offset_y, 0, height - 1)
			for offset_x in range(-radius, radius + 1):
				if offset_x == 0 and offset_y == 0:
					continue
				var sample_x := clampi(x + offset_x, 0, width - 1)
				var distance := Vector2(float(offset_x), float(offset_y)).length()
				if distance > float(radius):
					continue
				var sample_weight := 1.0 - distance / float(radius + 1)
				total += source.get_pixel(sample_x, sample_y).r * sample_weight
				weight += sample_weight
		var smoothed := lerpf(current, total / weight, strength)
		if _set_height_if_changed(height_map, x, y, current, smoothed):
			changed_pixels += 1
	return changed_pixels


func _limit_masked_adjacent_steps(height_map: Image, mask: PackedByteArray, options: Dictionary, mask_indices: PackedInt32Array = PackedInt32Array()) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var changed_pixels := 0
	var active_indices := mask_indices if not mask_indices.is_empty() else _mask_indices(mask)
	for index_value in active_indices:
		var index := int(index_value)
		var y := int(index / width)
		var x := index % width
		if x > 0:
			changed_pixels += _limit_masked_pair(height_map, mask, x, y, x - 1, y, options)
		if x < width - 1:
			changed_pixels += _limit_masked_pair(height_map, mask, x, y, x + 1, y, options)
		if y > 0:
			changed_pixels += _limit_masked_pair(height_map, mask, x, y, x, y - 1, options)
		if y < height - 1:
			changed_pixels += _limit_masked_pair(height_map, mask, x, y, x, y + 1, options)
	return changed_pixels


func _limit_masked_pair(height_map: Image, mask: PackedByteArray, ax: int, ay: int, bx: int, by: int, options: Dictionary) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var a_index := ay * width + ax
	var b_index := by * width + bx
	if mask[a_index] == 0 and mask[b_index] == 0:
		return 0

	var a: float = height_map.get_pixel(ax, ay).r
	var b: float = height_map.get_pixel(bx, by).r
	var detect_threshold := _max_step(options)
	var target_step := _target_step(options)
	var delta := absf(a - b)
	if delta <= target_step or _is_intentional_cut(delta, detect_threshold, options):
		return 0

	var preserve_outer_edges := bool(options.get("preserve_outer_edges", true))
	var can_a := mask[a_index] == 1 and _can_modify_pixel(ax, ay, width, height, preserve_outer_edges)
	var can_b := mask[b_index] == 1 and _can_modify_pixel(bx, by, width, height, preserve_outer_edges)
	if not can_a and not can_b:
		return 0

	var strength := maxf(_strength(options), 0.95)
	var changed_pixels := 0
	var sign := 1.0 if a >= b else -1.0
	var target_delta := target_step * sign
	var midpoint := (a + b) * 0.5
	var target_a := midpoint + target_delta * 0.5
	var target_b := midpoint - target_delta * 0.5
	if not can_a:
		target_b = a - target_delta
	if not can_b:
		target_a = b + target_delta
	if can_a:
		var repaired_a := lerpf(a, target_a, strength)
		if _set_height_if_changed(height_map, ax, ay, a, repaired_a):
			changed_pixels += 1
	if can_b:
		var repaired_b := lerpf(b, target_b, strength)
		if _set_height_if_changed(height_map, bx, by, b, repaired_b):
			changed_pixels += 1
	return changed_pixels


func _limit_adjacent_steps(height_map: Image, options: Dictionary) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var source: Image = height_map.duplicate()
	var corrections := PackedFloat32Array()
	var weights := PackedFloat32Array()
	corrections.resize(width * height)
	weights.resize(width * height)

	var threshold := _max_step(options)
	var strength := _strength(options)
	var preserve_outer_edges := bool(options.get("preserve_outer_edges", true))

	for y in range(height):
		for x in range(width - 1):
			_accumulate_pair_correction(source, corrections, weights, width, height, x, y, x + 1, y, threshold, strength, preserve_outer_edges, options)
	for y in range(height - 1):
		for x in range(width):
			_accumulate_pair_correction(source, corrections, weights, width, height, x, y, x, y + 1, threshold, strength, preserve_outer_edges, options)

	var changed_pixels := 0
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			var weight := weights[index]
			if weight <= 0.0:
				continue
			var current: float = source.get_pixel(x, y).r
			var repaired := current + corrections[index] / weight
			if _set_height_if_changed(height_map, x, y, current, repaired):
				changed_pixels += 1
	return changed_pixels


func _accumulate_pair_correction(
	source: Image,
	corrections: PackedFloat32Array,
	weights: PackedFloat32Array,
	width: int,
	height: int,
	ax: int,
	ay: int,
	bx: int,
	by: int,
	threshold: float,
	strength: float,
	preserve_outer_edges: bool,
	options: Dictionary
) -> void:
	var a: float = source.get_pixel(ax, ay).r
	var b: float = source.get_pixel(bx, by).r
	var delta := absf(a - b)
	if delta <= threshold or _is_intentional_cut(delta, threshold, options):
		return

	var can_a := _can_modify_pixel(ax, ay, width, height, preserve_outer_edges)
	var can_b := _can_modify_pixel(bx, by, width, height, preserve_outer_edges)
	if not can_a and not can_b:
		return

	var sign := 1.0 if a >= b else -1.0
	var target_delta := threshold * sign
	var midpoint := (a + b) * 0.5
	var target_a := midpoint + target_delta * 0.5
	var target_b := midpoint - target_delta * 0.5
	if not can_a:
		target_b = a - target_delta
	if not can_b:
		target_a = b + target_delta

	if can_a:
		var index_a := ay * width + ax
		corrections[index_a] += (target_a - a) * strength
		weights[index_a] += 1.0
	if can_b:
		var index_b := by * width + bx
		corrections[index_b] += (target_b - b) * strength
		weights[index_b] += 1.0


func _relax_local_outliers(height_map: Image, options: Dictionary) -> int:
	var width := height_map.get_width()
	var height := height_map.get_height()
	var source: Image = height_map.duplicate()
	var threshold := _max_step(options)
	var strength := _strength(options) * 0.5
	var preserve_outer_edges := bool(options.get("preserve_outer_edges", true))
	var min_x := 1 if preserve_outer_edges else 0
	var min_y := 1 if preserve_outer_edges else 0
	var max_x := width - 2 if preserve_outer_edges else width - 1
	var max_y := height - 2 if preserve_outer_edges else height - 1
	var changed_pixels := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var current: float = source.get_pixel(x, y).r
			var left: float = source.get_pixel(maxi(0, x - 1), y).r
			var right: float = source.get_pixel(mini(width - 1, x + 1), y).r
			var up: float = source.get_pixel(x, maxi(0, y - 1)).r
			var down: float = source.get_pixel(x, mini(height - 1, y + 1)).r
			var target := (left + right + up + down) * 0.25
			var deviation := absf(current - target)
			if deviation <= threshold * 0.5 or _is_intentional_cut(deviation, threshold, options):
				continue
			var local_strength := strength * clampf(deviation / maxf(threshold * 3.0, 0.001), 0.25, 1.0)
			var repaired := lerpf(current, target, local_strength)
			if _set_height_if_changed(height_map, x, y, current, repaired):
				changed_pixels += 1
	return changed_pixels


func _repair_region_seams(region_map: Dictionary, changed_locations: Dictionary, options: Dictionary) -> int:
	var changed_pixels := 0
	for location_value in region_map.keys():
		var location: Vector2i = location_value
		var region := region_map[location] as Terrain3DRegion
		if region == null:
			continue
		var right_location := location + Vector2i(1, 0)
		var down_location := location + Vector2i(0, 1)
		if region_map.has(right_location):
			changed_pixels += _repair_vertical_seam(region, region_map[right_location] as Terrain3DRegion, changed_locations, options)
		if region_map.has(down_location):
			changed_pixels += _repair_horizontal_seam(region, region_map[down_location] as Terrain3DRegion, changed_locations, options)
	return changed_pixels


func _repair_vertical_seam(left_region: Terrain3DRegion, right_region: Terrain3DRegion, changed_locations: Dictionary, options: Dictionary) -> int:
	var left_map := left_region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	var right_map := right_region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	if not _is_valid_height_map(left_map) or not _is_valid_height_map(right_map):
		return 0
	var width_left := left_map.get_width()
	var height_count := mini(left_map.get_height(), right_map.get_height())
	var changed_pixels := 0
	for y in range(height_count):
		changed_pixels += _repair_seam_pair(left_map, right_map, width_left - 1, y, 0, y, true, changed_locations, left_region.location, right_region.location, options)
	return changed_pixels


func _repair_horizontal_seam(top_region: Terrain3DRegion, bottom_region: Terrain3DRegion, changed_locations: Dictionary, options: Dictionary) -> int:
	var top_map := top_region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	var bottom_map := bottom_region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	if not _is_valid_height_map(top_map) or not _is_valid_height_map(bottom_map):
		return 0
	var height_top := top_map.get_height()
	var width_count := mini(top_map.get_width(), bottom_map.get_width())
	var changed_pixels := 0
	for x in range(width_count):
		changed_pixels += _repair_seam_pair(top_map, bottom_map, x, height_top - 1, x, 0, false, changed_locations, top_region.location, bottom_region.location, options)
	return changed_pixels


func _repair_seam_pair(
	a_map: Image,
	b_map: Image,
	ax: int,
	ay: int,
	bx: int,
	by: int,
	vertical: bool,
	changed_locations: Dictionary,
	a_location: Vector2i,
	b_location: Vector2i,
	options: Dictionary
) -> int:
	var a: float = a_map.get_pixel(ax, ay).r
	var b: float = b_map.get_pixel(bx, by).r
	var threshold := _max_step(options)
	var delta := absf(a - b)
	if delta <= threshold or _is_intentional_cut(delta, threshold, options):
		return 0

	var strength := maxf(_strength(options), 0.95)
	var sign := 1.0 if a >= b else -1.0
	var target_delta := _target_step(options) * sign
	var midpoint := (a + b) * 0.5
	var target_a := midpoint + target_delta * 0.5
	var target_b := midpoint - target_delta * 0.5
	var correction_a := (target_a - a) * strength
	var correction_b := (target_b - b) * strength
	var band := clampi(int(options.get("seam_band", DEFAULT_SEAM_BAND)), 1, 16)
	var changed_pixels := 0
	for offset in range(band):
		var falloff := 1.0 - float(offset) / float(band)
		if vertical:
			changed_pixels += _apply_band_correction(a_map, ax - offset, ay, correction_a * falloff)
			changed_pixels += _apply_band_correction(b_map, bx + offset, by, correction_b * falloff)
		else:
			changed_pixels += _apply_band_correction(a_map, ax, ay - offset, correction_a * falloff)
			changed_pixels += _apply_band_correction(b_map, bx, by + offset, correction_b * falloff)
	if changed_pixels > 0:
		changed_locations[a_location] = true
		changed_locations[b_location] = true
	return changed_pixels


func _apply_band_correction(height_map: Image, x: int, y: int, correction: float) -> int:
	if x < 0 or y < 0 or x >= height_map.get_width() or y >= height_map.get_height():
		return 0
	var current: float = height_map.get_pixel(x, y).r
	var repaired := current + correction
	return 1 if _set_height_if_changed(height_map, x, y, current, repaired) else 0


func _is_valid_height_map(height_map: Image) -> bool:
	return height_map != null and height_map.get_width() > 0 and height_map.get_height() > 0


func _set_height_if_changed(height_map: Image, x: int, y: int, current: float, value: float) -> bool:
	if absf(value - current) <= 0.0001:
		return false
	height_map.set_pixel(x, y, Color(value, 0.0, 0.0, 1.0))
	return true


func _can_modify_pixel(x: int, y: int, width: int, height: int, preserve_outer_edges: bool) -> bool:
	if not preserve_outer_edges:
		return true
	return x > 0 and y > 0 and x < width - 1 and y < height - 1


func _is_intentional_cut(delta: float, threshold: float, options: Dictionary) -> bool:
	if not bool(options.get("allow_intentional_cuts", false)):
		return false
	var multiplier := maxf(1.0, float(options.get("intentional_cut_multiplier", DEFAULT_INTENTIONAL_CUT_MULTIPLIER)))
	return delta >= threshold * multiplier


func _mask_has_pixels(mask: PackedByteArray) -> bool:
	for index in range(mask.size()):
		if mask[index] != 0:
			return true
	return false


func _mask_indices(mask: PackedByteArray) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in range(mask.size()):
		if mask[index] != 0:
			indices.append(index)
	return indices


func _iterations(options: Dictionary) -> int:
	return clampi(int(options.get("iterations", DEFAULT_ITERATIONS)), 1, 24)


func _strength(options: Dictionary) -> float:
	return clampf(float(options.get("strength", DEFAULT_STRENGTH)), 0.01, 1.0)


func _max_step(options: Dictionary) -> float:
	return clampf(float(options.get("max_step", DEFAULT_MAX_STEP_METERS)), 0.05, 1000.0)


func _repair_mask_radius(options: Dictionary) -> int:
	return clampi(int(options.get("repair_radius", DEFAULT_REPAIR_MASK_RADIUS)), 0, 96)


func _repair_smooth_radius(options: Dictionary) -> int:
	return clampi(int(options.get("smooth_radius", DEFAULT_REPAIR_SMOOTH_RADIUS)), 1, 12)


func _strict_repair_passes(options: Dictionary) -> int:
	var requested := int(options.get("strict_passes", DEFAULT_STRICT_REPAIR_PASSES))
	return clampi(maxi(requested, _iterations(options)), 1, 48)


func _target_step(options: Dictionary) -> float:
	var factor := clampf(float(options.get("target_step_factor", DEFAULT_TARGET_STEP_FACTOR)), 0.05, 1.0)
	return _max_step(options) * factor


func _limit_mask_radius(options: Dictionary) -> int:
	return clampi(int(options.get("limit_radius", DEFAULT_LIMIT_MASK_RADIUS)), 0, 16)
